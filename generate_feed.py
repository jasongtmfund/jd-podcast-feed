#!/usr/bin/env python3
"""Generate a podcast RSS feed from audio files in ./audio.

- Converts .wav files to .m4a (requires ffmpeg) to keep the feed small.
- Episode date = date the file was added to git (falls back to now).
- Output goes to ./_site (audio files + feed.xml + index.html).

Env vars:
  SITE_URL    Base URL of the published site (e.g. https://user.github.io/repo)
  FEED_TITLE  Podcast title (default: "JD Podcast Feed")
"""

import html
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path

AUDIO_DIR = Path("audio")
OUT_DIR = Path("_site")
SITE_URL = os.environ.get("SITE_URL", "").rstrip("/")
FEED_TITLE = os.environ.get("FEED_TITLE", "JD Podcast Feed")

AUDIO_EXTS = {".m4a", ".mp3", ".wav"}
MIME = {".m4a": "audio/mp4", ".mp3": "audio/mpeg"}


def git_date(path: Path) -> datetime:
    """Date the file was first added to git."""
    try:
        out = subprocess.run(
            ["git", "log", "--diff-filter=A", "--follow",
             "--format=%aI", "-1", "--", str(path)],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        if out:
            return datetime.fromisoformat(out)
    except Exception:
        pass
    return datetime.now(timezone.utc)


def duration_seconds(path: Path) -> int:
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        return int(float(out))
    except Exception:
        return 0


def nice_title(stem: str) -> str:
    return stem.replace("_", " ").replace("-", " ").strip()


def main() -> None:
    if not SITE_URL:
        sys.exit("SITE_URL env var is required")

    out_audio = OUT_DIR / "audio"
    out_audio.mkdir(parents=True, exist_ok=True)

    episodes = []
    for src in sorted(AUDIO_DIR.glob("*")):
        if src.suffix.lower() not in AUDIO_EXTS or src.name.startswith("."):
            continue

        date = git_date(src)

        if src.suffix.lower() == ".wav":
            dest = out_audio / (src.stem + ".m4a")
            subprocess.run(
                ["ffmpeg", "-y", "-i", str(src), "-c:a", "aac",
                 "-b:a", "96k", str(dest)],
                check=True, capture_output=True,
            )
        else:
            dest = out_audio / src.name
            shutil.copy2(src, dest)

        episodes.append({
            "title": nice_title(src.stem),
            "file": dest,
            "url": f"{SITE_URL}/audio/{dest.name}",
            "bytes": dest.stat().st_size,
            "mime": MIME[dest.suffix.lower()],
            "date": date,
            "duration": duration_seconds(dest),
        })

    episodes.sort(key=lambda e: e["date"], reverse=True)

    items = []
    for e in episodes:
        mins, secs = divmod(e["duration"], 60)
        items.append(f"""    <item>
      <title>{html.escape(e["title"])}</title>
      <guid isPermaLink="false">{html.escape(e["file"].name)}</guid>
      <pubDate>{format_datetime(e["date"])}</pubDate>
      <enclosure url="{html.escape(e["url"])}" length="{e["bytes"]}" type="{e["mime"]}"/>
      <itunes:duration>{mins}:{secs:02d}</itunes:duration>
    </item>""")

    feed = f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>{html.escape(FEED_TITLE)}</title>
    <link>{html.escape(SITE_URL)}</link>
    <description>Personal feed of NotebookLM audio overviews.</description>
    <language>en</language>
    <itunes:block>Yes</itunes:block>
{chr(10).join(items)}
  </channel>
</rss>
"""
    (OUT_DIR / "feed.xml").write_text(feed, encoding="utf-8")

    rows = "\n".join(
        f'<li><a href="audio/{html.escape(e["file"].name)}">'
        f'{html.escape(e["title"])}</a> '
        f'({e["date"].strftime("%Y-%m-%d")})</li>'
        for e in episodes
    )
    (OUT_DIR / "index.html").write_text(
        f"<!doctype html><meta charset='utf-8'><title>{html.escape(FEED_TITLE)}</title>"
        f"<h1>{html.escape(FEED_TITLE)}</h1>"
        f"<p>Feed URL: <code>{html.escape(SITE_URL)}/feed.xml</code></p>"
        f"<ul>{rows}</ul>",
        encoding="utf-8",
    )
    print(f"Wrote feed with {len(episodes)} episode(s).")


if __name__ == "__main__":
    main()
