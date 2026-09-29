#!/usr/bin/env bash
# Usage: screenshots.sh <todoapp|inception>; retakes <app>/screenshots/vnc-demo.gif through VNC while `just serve <app> docker` runs.
set -euo pipefail
cd "$(dirname "$0")/.."

app=${1:?app required: todoapp or inception}
out=$app/screenshots
api=${OBELISK_API_URL:-http://127.0.0.1:5005}
mkdir -p "$out"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
frames=()

finished_children() {
  curl -fsS -H "Authorization: Bearer $OBELISK_API_TOKEN" -H accept:application/json \
    "$api/v1/executions/$execution_id/responses?length=100" \
    | jq '[.responses[].event.event.event | select(.child_execution_id)] | length'
}

# Crops the Xvfb screen to the browser window, which sits on a black root window.
capture() {
  # A fresh connection can get x11vnc's stale frame; capture after it has polled the screen.
  vncdo -s "${vnc/:/::}" capture "$tmp/warmup.png" pause 1 capture "$tmp/$1.png"
  magick "$tmp/$1.png" -bordercolor black -border 1 -trim +repage "$tmp/$1-cropped.png"
  frames+=("$tmp/$1-cropped.png")
  printf 'Captured %s\n' "$1"
}

start() {
  local started
  started=$(./scripts/start-multistep.sh "$@")
  printf '%s\n' "$started"
  vnc=$(sed -n 's/^VNC: //p' <<<"$started")
  execution_id=$(sed -n 's/^Execution: //p' <<<"$started")
  supervisor_id=$(sed -n 's/^Supervisor: //p' <<<"$started")
}

# Usage: step <child activities finished> <timeout seconds> <frame name>
step() {
  obelisk execution advance "$execution_id" >/dev/null
  local deadline=$((SECONDS + $2))
  until [ "$(finished_children)" -ge "$1" ]; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      printf 'Timed out waiting for activity %s. Check: obelisk execution logs --show-derived %s\n' \
        "$1" "$execution_id" >&2
      exit 1
    fi
    sleep 0.5
  done
  capture "$3"
}

case $app in
  todoapp)
    start demo:playwright/todoapp-multistep.run '"Buy milk"' 0
    capture vnc-before
    step 1 60 vnc-task-added
    ;;
  inception)
    store_path=$(nix eval --raw github:obeli-sk/obelisk/latest-rc)
    start demo:playwright/inception-multistep.run "$(jq -cn --arg value "$store_path" '$value')"
    capture vnc-loaded
    step 1 300 vnc-configured
    step 2 900 vnc-booted
    step 3 120 vnc-command
    ;;
  *)
    printf 'Unknown app: %s\n' "$app" >&2
    exit 1
    ;;
esac

obelisk execution unpause "$execution_id"
obelisk execution status --follow "$supervisor_id"

# Rendered at twice the 322 px width the top-level README displays it at.
magick -delay 200 "${frames[@]}" -loop 0 -resize 644x -layers Optimize "$out/vnc-demo.gif"
printf 'Wrote %s/vnc-demo.gif\n' "$out"
