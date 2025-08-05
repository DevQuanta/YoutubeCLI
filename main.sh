
#!/usr/bin/env bash
set -euo pipefail

PID_FILE="/tmp/yt-mpv.pid"

# 🛑 Kill previous player if it exists
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  read -rp "🛑 A video is currently playing. Stop it before playing a new one? [y/N]: " STOP_MPV
  if [[ "$STOP_MPV" =~ ^[yY]$ ]]; then
    kill "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
    echo "🔇 Stopped previous playback."
    sleep 0.5
  fi
fi

# Prompt for search query (non-empty)
while true; do
  read -rp "🔍 Enter search query: " QUERY
  [[ -n "$QUERY" ]] && break
  echo "❌ Query cannot be empty."
done

# Prompt for type
read -rp "🎞️  Search for (v)ideo or (p)laylist? [v/p]: " TYPE

case "$TYPE" in
  v|V)
    SEARCH_URL="https://www.youtube.com/results?search_query=$(jq -rn --arg q "$QUERY" '$q|@uri')"
    ;;
  p|P)
    SEARCH_URL="https://www.youtube.com/results?search_query=$(jq -rn --arg q "$QUERY" '$q|@uri')&sp=EgIQAw%3D%3D"
    ;;
  *)
    echo "❌ Invalid choice"
    exit 1
    ;;
esac

# Fetch results
JSON=$(yt-dlp --flat-playlist --dump-single-json --playlist-end 20 --skip-download "$SEARCH_URL")

# Filter results
if [[ "$TYPE" =~ ^[vV]$ ]]; then
  LIST=$(echo "$JSON" | jq -c '[
    .entries[]
    | select(.ie_key == "Youtube" or .ie_key == "YoutubeShorts")
    | {name: .title, url: .url}
  ] | .[]')
else
  LIST=$(echo "$JSON" | jq -c '.entries[] | {name: .title, url: .url}')
fi

# Select with fzf
SELECTED=$(echo "$LIST" | jq -r '.name + "\t" + .url' | fzf --height=80% --prompt="🎧 Select to play: ")

[[ -z "$SELECTED" ]] && { echo "🚪 No selection. Exiting."; exit 0; }

# Parse values
URL=$(awk -F'\t' '{print $2}' <<< "$SELECTED")
TITLE=$(awk -F'\t' '{print $1}' <<< "$SELECTED")

# Ask audio/video
read -rp "▶️ Play as (a)udio or (v)ideo? [a/v]: " MODE

case "$MODE" in
  a|A)
    echo "🎧 Playing audio: $TITLE"
    nohup mpv --no-video --ytdl-format=bestaudio "$URL" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    ;;
  v|V)
    echo "🎬 Playing video: $TITLE"
    nohup mpv "$URL" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    ;;
  *)
    echo "❌ Invalid option"
    exit 1
    ;;
esac

