# JD Podcast Feed

Personal podcast feed (NotebookLM audio overviews -> Overcast), hosted free on GitHub Pages.

**Feed URL:** `https://jasongtmfund.github.io/jd-podcast-feed/feed.xml`

## How it works

1. Audio files land in `audio/` (see below).
2. A GitHub Action converts `.wav` -> small `.m4a`, rebuilds `feed.xml`, and publishes to GitHub Pages.
3. Overcast (subscribed to the feed URL via **+ -> Add URL**) picks up new episodes automatically.

## Adding episodes

- **Automatic (the normal way):** save the file to `~/PodcastDrop` on the Mac. A launchd watcher (`com.jd-podcast-feed.watcher`) moves it into `audio/`, commits, and pushes. Log: `~/Library/Logs/jd-podcast-feed.log`.
- **Manual:** upload a `.wav`/`.m4a`/`.mp3` to `audio/` via the GitHub web UI (Add file -> Upload files).

The filename becomes the episode title: `Deep_Dive_on_Q2.wav` -> "Deep Dive on Q2".

## Notes

- Public repo: audio is technically public at an obscure URL. Nothing sensitive here.
- `<itunes:block>` is set so podcast directories won't index the feed.
- Show title: edit `FEED_TITLE` in `.github/workflows/feed.yml`.
- Watcher source lives in `scripts/`; installed copies are at `~/.local/bin/jd-feed-watcher.sh` and `~/Library/LaunchAgents/com.jd-podcast-feed.watcher.plist`.
