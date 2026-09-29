#!/usr/bin/env bash
# Usage: start-multistep.sh <workflow-ffqn> [json-param...]; the session ID is prepended as the first parameter.
set -euo pipefail

ffqn=${1:?workflow FFQN required}
shift

execution_id=$(obelisk generate execution-id)
session=$(tr '[:upper:]' '[:lower:]' <<<"${execution_id#E_}")
container="demo-playwright-$session"
socket="/tmp/demo-playwright/$session.sock"

obelisk execution submit --paused --execution-id "$execution_id" "$ffqn" -- \
  "$(jq -cn --arg value "$session" '$value')" "$@"
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
      printf 'Browser is running without VNC. Start Obelisk without HEADED=false.\nExecution: %s\n' "$execution_id" >&2
      exit 1
    fi
  fi
  sleep 0.25
done

printf 'Timed out waiting for browser. Check: obelisk execution logs --show-derived %s\n' "$execution_id" >&2
exit 1
