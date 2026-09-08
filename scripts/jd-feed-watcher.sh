#!/bin/bash
# Moves audio dropped in ~/PodcastDrop into the repo, commits, pushes.
# Installed at ~/.local/bin/jd-feed-watcher.sh, run by launchd
# (com.jd-podcast-feed.watcher: WatchPaths on ~/PodcastDrop + 60s sweep).
#
# The push exit status is checked and retried. A push that never lands leaves
# the commit local, so every run also pushes whatever backlog it finds — the
# pipeline self-heals on the next sweep instead of going quiet. A push that
# fails three times alerts Slack.
#
# Slack webhook is read from ~/.config/jd-podcast-feed.env — never in this
# repo, which is public.

export PATH=/opt/homebrew/bin:$PATH  # git needs gh's credential helper

REPO="$HOME/jd-podcast-feed"
DROP="$HOME/PodcastDrop"
LOG="$HOME/Library/Logs/jd-podcast-feed.log"
ENVFILE="$HOME/.config/jd-podcast-feed.env"
[ -f "$ENVFILE" ] && . "$ENVFILE"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

alert() {
  [ -n "${SLACK_WEBHOOK_URL:-}" ] || return 0
  local payload
  payload=$(python3 -c 'import json,sys; print(json.dumps({"text": sys.argv[1]}))' "$1")
  curl -s -m 10 -X POST -H 'Content-Type: application/json' \
    -d "$payload" "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
}

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
  log "queued: $name -> $safe"
  moved=1
done

cd "$REPO" || exit 1

if [ "$moved" = 1 ]; then
  git add audio >> "$LOG" 2>&1
  git commit -m "Add episode(s)" >> "$LOG" 2>&1
fi

# Push anything unpushed, whether queued just now or stranded by an earlier run.
git fetch origin main --quiet >> "$LOG" 2>&1
ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
[ "$ahead" = "0" ] && exit 0

for attempt in 1 2 3; do
  if git push origin main >> "$LOG" 2>&1; then
    log "pushed ($ahead commit(s), attempt $attempt)"
    exit 0
  fi
  log "push failed (attempt $attempt of 3)"
  sleep $((attempt * 20))
done

log "PUSH FAILED after 3 attempts — $ahead commit(s) still local"
alert "⚠️ Error — jd-podcast-feed watcher
What happened: git push failed 3 times; $ahead commit(s) are stuck on the Mac.
Impact: new episodes are missing from the Overcast feed.
Suggested fix: cd ~/jd-podcast-feed && git push origin main (log: ~/Library/Logs/jd-podcast-feed.log)"
exit 1
