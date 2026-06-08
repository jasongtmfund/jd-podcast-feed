# jd-podcast-feed

Personal podcast feed: NotebookLM audio overviews → GitHub Pages RSS → Overcast.
Public repo under jasongtmfund (Pages requires public on the free plan).

## Architecture

- `audio/` — source audio files. Filename = episode title (underscores → spaces).
- `generate_feed.py` — builds `_site/` (converted audio + `feed.xml` + `index.html`).
  Episode date = git add date. WAVs converted to 96k m4a via ffmpeg.
- `.github/workflows/feed.yml` — on push: runs the generator, deploys to Pages.
  Feed title lives here (`FEED_TITLE`).
- Feed URL: https://jasongtmfund.github.io/jd-podcast-feed/feed.xml
  (subscribed in Jason's Overcast; `<itunes:block>` keeps it out of directories).

## Mac-side automation

- Watcher: `~/.local/bin/jd-feed-watcher.sh`, launchd agent
  `com.jd-podcast-feed.watcher` (WatchPaths `~/PodcastDrop` + 60s sweep).
  Moves audio from `~/PodcastDrop` into `audio/`, sanitizes the filename,
  commits, pushes. Log: `~/Library/Logs/jd-podcast-feed.log`.
- Source of truth for both files: `scripts/` in this repo. If you change them,
  reinstall the copies and `launchctl unload && load` the plist.
- Git auth is via gh CLI credential helper (see the git-projects skill);
  the watcher exports PATH=/opt/homebrew/bin for that reason.

## Conventions

- Files modified <15s ago are skipped (may still be downloading); the 60s
  StartInterval sweep retries them.
- No secrets in this repo. Nothing here needs a token.
