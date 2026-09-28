#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

session=${1:?session ID required}
task=${2:?task required}
if [[ ! "$session" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]]; then
  printf 'Session ID must be 1 to 32 lowercase letters, digits, or hyphens\n' >&2
  exit 1
fi

container="demo-playwright-$session"
socket="/tmp/demo-playwright/$session.sock"
if docker container inspect "$container" >/dev/null 2>&1; then
  printf 'Container %s already exists; choose another session ID\n' "$container" >&2
  exit 1
fi
execution_id=$(obelisk generate execution-id)
obelisk execution submit --paused --execution-id "$execution_id" demo:playwright/workflow.run -- \
  "$(jq -cn --arg value "$session" '$value')" \
  "$(jq -cn --arg value "$task" '$value')" 0
obelisk execution advance "$execution_id"

for _ in $(seq 1 120); do
  if [ -S "$socket" ]; then
    if [ "$(docker inspect "$container" --format '{{.HostConfig.NetworkMode}}' 2>/dev/null)" = host ]; then
      address=127.0.0.1:5900
    else
      address=$(docker port "$container" 5900/tcp 2>/dev/null | head -1 || true)
    fi
    if [ -n "$address" ]; then
      printf 'VNC: %s\nExecution: %s\n' "$address" "$execution_id"
      exit 0
    fi
    if docker container inspect "$container" >/dev/null 2>&1; then
      printf 'Browser is running without VNC. Start Obelisk with HEADED=true just serve.\n' >&2
      exit 1
    fi
  fi
  sleep 0.25
done

printf 'Timed out waiting for browser. Check: obelisk execution logs --show-derived %s\n' "$execution_id" >&2
exit 1
