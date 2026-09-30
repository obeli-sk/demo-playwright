#!/usr/bin/env bash
# Usage: start-multistep.sh <workflow-ffqn> [json-param...]
# Starts the browser, then leaves the steps workflow paused for `just advance` and lets the supervisor run.
set -euo pipefail

ffqn=${1:?workflow FFQN required}
shift
steps_ffqn=${ffqn/-multistep.run/-steps.run-cancellable}
api=${OBELISK_API_URL:-http://127.0.0.1:5005}

get() {
  curl -fsS -H "Authorization: Bearer $OBELISK_API_TOKEN" -H accept:application/json "$api/v1/$1"
}

app=${ffqn#*/}
app=${app%-multistep.run}
execution_id=$(obelisk generate execution-id)
# Must match the names multistep.js derives from its execution ID.
container="demo-playwright-$app-$execution_id"
socket="/tmp/demo-playwright/$execution_id.sock"

obelisk execution submit --paused --execution-id "$execution_id" "$ffqn" -- "$@" >/dev/null
# First step: start the browser.
obelisk execution advance "$execution_id" >/dev/null

address=
for _ in $(seq 1 120); do
  if [ -S "$socket" ]; then
    if [ "$(docker inspect "$container" --format '{{.HostConfig.NetworkMode}}' 2>/dev/null)" = host ]; then
      address=127.0.0.1:5900
    else
      address=$(docker port "$container" 5900/tcp 2>/dev/null | head -1 || true)
    fi
    if [ -n "$address" ]; then break; fi
    if docker container inspect "$container" >/dev/null 2>&1; then
      printf 'Browser is running without VNC. Start Obelisk without HEADED=false.\nExecution: %s\n' "$execution_id" >&2
      exit 1
    fi
  fi
  sleep 0.25
done
if [ -z "$address" ]; then
  printf 'Timed out waiting for browser. Check: obelisk execution logs --show-derived %s\n' "$execution_id" >&2
  exit 1
fi

# The supervisor can take its next step once the start activity's result is recorded.
for _ in $(seq 1 120); do
  started=$(get "executions/$execution_id/responses?length=100" \
    | jq '[.responses[].event.event.event | select(.child_execution_id)] | length')
  if [ "$started" -ge 1 ]; then break; fi
  sleep 0.25
done

# Second step: submit the steps workflow, created paused, and the session timeout.
obelisk execution advance --pause-submitted-executions "$execution_id" >/dev/null
steps_id=$(get "executions?show_derived=true&execution_id_prefix=$execution_id&function=$steps_ffqn" \
  | jq -r '.[0].execution_id // empty')
if [ -z "$steps_id" ]; then
  printf 'The steps workflow was not submitted. Check: obelisk execution logs --show-derived %s\n' "$execution_id" >&2
  exit 1
fi
obelisk execution unpause "$execution_id" >/dev/null

printf 'VNC: %s\nExecution: %s\nSupervisor: %s\n' "$address" "$steps_id" "$execution_id"
