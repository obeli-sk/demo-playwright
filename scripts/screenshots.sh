#!/usr/bin/env bash
# Retakes the todoapp VNC screenshots and README GIF; needs `just serve-page` and `just serve todoapp docker`.
set -euo pipefail
cd "$(dirname "$0")/.."

out=todoapp/screenshots
api=${OBELISK_API_URL:-http://127.0.0.1:5005}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

finished_children() {
  curl -fsS -H "Authorization: Bearer $OBELISK_API_TOKEN" -H accept:application/json \
    "$api/v1/executions/$execution_id/responses?length=100" \
    | jq '[.responses[].event.event.event | select(.child_execution_id)] | length'
}

# Crops the Xvfb screen to the browser window, which sits on a black root window.
capture() {
  # A fresh connection can get x11vnc's stale frame; capture after it has polled the screen.
  vncdo -s "${vnc/:/::}" capture "$tmp/warmup.png" pause 1 capture "$tmp/$1.png"
  magick "$tmp/$1.png" -bordercolor black -border 1 -trim +repage "$out/$1.png"
  printf 'Wrote %s/%s.png\n' "$out" "$1"
}

started=$(./scripts/start-multistep.sh demo:playwright/todoapp-multistep.run '"Buy milk"' 0)
printf '%s\n' "$started"
vnc=$(sed -n 's/^VNC: //p' <<<"$started")
execution_id=$(sed -n 's/^Execution: //p' <<<"$started")

capture vnc-before

obelisk execution advance "$execution_id" >/dev/null
for _ in $(seq 1 120); do
  if [ "$(finished_children)" -ge 2 ]; then break; fi
  sleep 0.5
done
if [ "$(finished_children)" -lt 2 ]; then
  printf 'Timed out waiting for the task to be added\n' >&2
  exit 1
fi
capture vnc-task-added

obelisk execution unpause "$execution_id"
obelisk execution status --follow "$execution_id"

# Rendered at twice the 322 px width the top-level README displays it at.
magick -delay 200 "$out/vnc-before.png" "$out/vnc-task-added.png" -loop 0 -resize 644x \
  -layers Optimize "$out/vnc-demo.gif"
printf 'Wrote %s/vnc-demo.gif\n' "$out"
