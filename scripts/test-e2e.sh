#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mode=${1:-docker}
export OBELISK_API_TOKEN=demo-playwright-test-token
session="test-$(date +%s)-$$"
container="demo-playwright-$session"
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
  if [ "$mode" = docker ]; then docker rm -f "$container" >/dev/null 2>&1 || true; fi
  if [ "$status" -ne 0 ]; then cat "$server_log" >&2; fi
  rm -f "$server_log"
}
trap cleanup EXIT

case "$mode" in
  docker) deployment=deployment.toml ;;
  vm) deployment=deployment-vm.toml ;;
  *) printf 'Unknown mode %s, expected docker or vm\n' "$mode" >&2; exit 1 ;;
esac

node page/server.mjs >>"$server_log" 2>&1 &
page_pid=$!

obelisk server run --server-config server.toml --app-config app.toml --deployment "$deployment" >>"$server_log" 2>&1 &
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
if [ "$mode" = vm ]; then
  result=$(obelisk execution submit --follow --json demo:playwright/workflow-vm.run -- '"Buy milk"')
  jq -s -e ".[-1].ok == $expected" <<<"$result" >/dev/null
  printf 'Obelisk VM browser workflow passed\n'
  exit 0
fi

result=$(obelisk execution submit --follow --json demo:playwright/workflow.run -- \
  "$(jq -nc --arg value "$session" '$value')" '"Buy milk"' 0)
jq -s -e ".[-1].ok == $expected" <<<"$result" >/dev/null
if docker inspect "$container" >/dev/null 2>&1; then
  printf 'Browser container was not cleaned up\n' >&2
  exit 1
fi
printf 'Obelisk browser workflow passed\n'
