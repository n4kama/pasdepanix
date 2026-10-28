# Stream a magnet link straight into a video player, leaving nothing behind.
#
#   tstream                      # prompts for the magnet (keeps it out of shell history)
#   tstream 'magnet:?xt=...'
#
# Quit the player and the trap kills rqbit and wipes the temp dir. No session
# state, no DHT table, no files.
#
# Not standalone: writeShellApplication supplies the shebang, `set -euo
# pipefail`, the PATH (rqbit, curl, jq, coreutils) and the `player` array.

magnet=${1:-}
[ -n "$magnet" ] || read -rp 'magnet: ' magnet
[ -n "$magnet" ] || {
  echo "no magnet given" >&2
  exit 1
}

d=$(mktemp -d)
port=$((3030 + RANDOM % 1000))
srv=
mon=

cleanup() {
  if [ -n "$mon" ]; then
    kill "$mon" 2>/dev/null || true
    wait "$mon" 2>/dev/null || true
  fi
  if [ -n "$srv" ]; then
    kill "$srv" 2>/dev/null || true
    wait "$srv" 2>/dev/null || true
  fi
  rm -rf "$d" || true
}
trap cleanup EXIT

rqbit --disable-dht-persistence --http-api-listen-addr "127.0.0.1:$port" \
  server start --disable-persistence "$d" >/dev/null 2>&1 &
srv=$!

for _ in $(seq 300); do
  curl -sf "http://127.0.0.1:$port/torrents" >/dev/null 2>&1 && break
  sleep 0.2
done
curl -sf "http://127.0.0.1:$port/torrents" >/dev/null 2>&1 ||
  {
    echo "rqbit did not come up on :$port" >&2
    exit 1
  }

# Biggest file wins; a season pack would otherwise open a .srt.
read -r id idx len < <(
  curl -sf -d "$magnet" "http://127.0.0.1:$port/torrents" |
    jq -r '[.id, ([.details.files | to_entries[]] | max_by(.value.length) | .key, .value.length)] | @tsv'
)
[ -n "${id:-}" ] && [ "$id" != "null" ] || {
  echo "could not add torrent" >&2
  exit 1
}

# One status line on stderr, rewritten in place every second, for the streamed
# file only. A player that draws its own terminal status line (bare mpv)
# fights with it; IINA with --no-stdin leaves the terminal free.
while sleep 1; do
  line=$(
    curl -sf "http://127.0.0.1:$port/torrents/$id/stats/v1" |
      jq -r --argjson i "$idx" --argjson n "$len" '
        .file_progress[$i] as $p
        | "\($p * 100 / $n | floor)% \($p / 1048576 | floor)/\($n / 1048576 | floor) MiB"
          + if $p >= $n then " · done"
            else " · \(.live.download_speed.human_readable // "-")"
              + " · \(.live.snapshot.peer_stats.live // 0) peers"
              + " · ETA \(.live.time_remaining.human_readable // "?")"
            end'
  ) || continue
  printf '\r%s\033[K' "$line" >&2
done &
mon=$!

# The player blocks until you quit it; then the trap wipes everything.
"${player[@]}" "http://127.0.0.1:$port/torrents/$id/stream/$idx"
echo >&2
