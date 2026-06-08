#!/bin/bash
# Moves audio dropped in ~/PodcastDrop into the repo, commits, pushes.
# Installed at ~/.local/bin/jd-feed-watcher.sh, run by launchd
# (com.jd-podcast-feed.watcher: WatchPaths on ~/PodcastDrop + 60s sweep).

export PATH=/opt/homebrew/bin:$PATH  # git needs gh's credential helper

REPO="$HOME/jd-podcast-feed"
DROP="$HOME/PodcastDrop"
LOG="$HOME/Library/Logs/jd-podcast-feed.log"

mkdir -p "$DROP"
now=$(date +%s)
moved=0

shopt -s nullglob nocaseglob
for f in "$DROP"/*.wav "$DROP"/*.m4a "$DROP"/*.mp3; do
  [ -f "$f" ] || continue
  # Skip files modified in the last 15s (may still be downloading)
  mtime=$(stat -f %m "$f")
  [ $((now - mtime)) -lt 15 ] && continue

  name=$(basename "$f")
  safe=$(echo "$name" | tr ' ' '_' | tr -cd 'A-Za-z0-9._-')
  mv "$f" "$REPO/audio/$safe"
  echo "$(date '+%Y-%m-%d %H:%M:%S') queued: $name -> $safe" >> "$LOG"
  moved=1
done

if [ "$moved" = 1 ]; then
  cd "$REPO" || exit 1
  git add audio >> "$LOG" 2>&1
  git commit -m "Add episode(s)" >> "$LOG" 2>&1
  git push origin main >> "$LOG" 2>&1
  echo "$(date '+%Y-%m-%d %H:%M:%S') pushed" >> "$LOG"
fi
