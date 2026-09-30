#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../todoapp"

backend=${1:-docker}
case "$backend" in
  docker | vm) ;;
  *) printf 'Unknown backend %s, expected docker or vm\n' "$backend" >&2; exit 1 ;;
esac
server_config=()
if [ "$backend" = vm ]; then
  export OBELISK_UNSTABLE_ACTIVITY_VM=${OBELISK_UNSTABLE_ACTIVITY_VM:-qemu-tcg}
else
  unset OBELISK_UNSTABLE_ACTIVITY_VM
  server_config=(--server-config server-docker.toml)
fi

export OBELISK_API_TOKEN=demo-playwright-test-token
execution_id=$(obelisk generate execution-id)
container="demo-playwright-todoapp-$execution_id"
server_log=$(mktemp)
server_pid=""
page_pid=""
cleanup() {
  local status=$?
  for pid in "$server_pid" "$page_pid"; do
    if [ -n "$pid" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  if [ "$backend" = docker ]; then docker rm -f "$container" >/dev/null 2>&1 || true; fi
  if [ "$status" -ne 0 ]; then cat "$server_log" >&2; fi
  rm -f "$server_log"
}
trap cleanup EXIT

node page/server.mjs >>"$server_log" 2>&1 &
page_pid=$!

HEADED=false obelisk server run "${server_config[@]}" --app-config "app-$backend.toml" \
  --deployment "deployment-$backend.toml" >>"$server_log" 2>&1 &
server_pid=$!
ready=false
# The first VM deployment downloads the runtime bundle and Nix closure.
for _ in $(seq 1 600); do
  if curl -fsS -H "Authorization: Bearer $OBELISK_API_TOKEN" \
    http://127.0.0.1:5005/v1/components >/dev/null 2>&1 \
    && curl -fsS http://127.0.0.1:8090/ >/dev/null 2>&1; then
    ready=true
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null || ! kill -0 "$page_pid" 2>/dev/null; then break; fi
  sleep 1
done
if [ "$ready" != true ]; then
  printf 'Obelisk or the page server did not start\n' >&2
  exit 1
fi

expected='{title:"Playwright task list",tasks:["Buy milk"]}'
result=$(obelisk execution submit --follow --json demo:playwright/todoapp.run -- '"Buy milk"')
jq -s -e ".[-1].ok == $expected" <<<"$result" >/dev/null
printf 'Single-step todoapp workflow passed on %s\n' "$backend"
if [ "$backend" = vm ]; then exit 0; fi

result=$(obelisk execution submit --follow --json --execution-id "$execution_id" \
  demo:playwright/todoapp-multistep.run -- '"Buy milk"' 0)
jq -s -e ".[-1].ok == $expected" <<<"$result" >/dev/null
if docker inspect "$container" >/dev/null 2>&1; then
  printf 'Browser container was not cleaned up\n' >&2
  exit 1
fi
printf 'Multi-step todoapp workflow passed\n'
