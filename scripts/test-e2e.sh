#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export OBELISK_API_TOKEN=demo-playwright-test-token
session="test-$(date +%s)-$$"
container="demo-playwright-$session"
server_log=$(mktemp)
server_pid=""
cleanup() {
  local status=$?
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  docker rm -f "$container" >/dev/null 2>&1 || true
  if [ "$status" -ne 0 ]; then cat "$server_log" >&2; fi
  rm -f "$server_log"
}
trap cleanup EXIT

obelisk server run --server-config server.toml --app-config app.toml --deployment deployment.toml >"$server_log" 2>&1 &
server_pid=$!
ready=false
for _ in $(seq 1 30); do
  if curl -fsS -H "Authorization: Bearer $OBELISK_API_TOKEN" \
    http://127.0.0.1:5005/v1/components >/dev/null 2>&1; then
    ready=true
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then break; fi
  sleep 1
done
if [ "$ready" != true ]; then
  printf 'Obelisk did not start\n' >&2
  exit 1
fi

result=$(obelisk execution submit --follow --json demo:playwright/workflow.run -- \
  "$(jq -nc --arg value "$session" '$value')" '"Buy milk"' 0)
jq -s -e '.[-1].ok == {title:"Playwright task list",tasks:["Buy milk"]}' <<<"$result" >/dev/null
if docker inspect "$container" >/dev/null 2>&1; then
  printf 'Browser container was not cleaned up\n' >&2
  exit 1
fi
printf 'Obelisk browser workflow passed\n'
