#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
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
  if [ "$status" -ne 0 ]; then cat "$tmp/server.log" >&2; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

export OBELISK_API_TOKEN=$(obelisk generate token)
export OBELISK_API_URL=http://127.0.0.1:15055
export OBELISK__API__LISTENING_ADDR=127.0.0.1:15055
export OBELISK__WEBUI__LISTENING_ADDR=127.0.0.1:18080
export OBELISK__DATABASE__SQLITE__DIRECTORY="$tmp/sqlite"
node todoapp/page/server.mjs > "$tmp/page.log" 2>&1 &
page_pid=$!
obelisk server run --app-config bench/app-exec.toml --server-config bench/server-exec.toml \
  --deployment bench/deployment-exec.toml > "$tmp/server.log" 2>&1 &
server_pid=$!
ready=false
for _ in $(seq 1 60); do
  if curl -fsS -H "Authorization: Bearer $OBELISK_API_TOKEN" \
    "$OBELISK_API_URL/v1/components" >/dev/null 2>&1 \
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

for workload in echo curl; do
  result=$(obelisk execution submit --follow --json "demo:bench/$workload.run" '[]')
  expected=hello
  if [ "$workload" = curl ]; then expected=ok; fi
  jq -s -e --arg expected "$expected" '.[-1].ok == $expected' <<< "$result" >/dev/null
  ./scripts/bench.sh "$workload" exec 1 0 > "$tmp/$workload.csv"
  test "$(wc -l < "$tmp/$workload.csv")" -eq 2
  printf '%s exec benchmark passed\n' "$workload"
done
