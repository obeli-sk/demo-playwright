#!/usr/bin/env bash
set -euo pipefail

workload=${1:?expected echo, curl, todoapp, or inception}
backend=${2:?backend label required}
runs=${3:-7}
warmups=${4:-2}
value=${5:-}
api=${OBELISK_API_URL:-http://127.0.0.1:5005}

[[ $runs =~ ^[1-9][0-9]*$ && $warmups =~ ^[0-9]+$ ]] || {
  printf 'runs must be positive and warmups nonnegative\n' >&2
  exit 2
}
[[ $backend =~ ^[a-z0-9-]+$ ]] || {
  printf 'backend must contain only lowercase letters, digits, and hyphens\n' >&2
  exit 2
}

case $workload in
  echo) ffqn=demo:bench/echo.run; param='[]' ;;
  curl) ffqn=demo:bench/curl.run; param='[]' ;;
  todoapp) ffqn=demo:playwright/todoapp.run; param=$(jq -cn --arg v "${value:-Buy milk}" '[$v]') ;;
  inception)
    ffqn=demo:playwright/inception.run
    param=$(jq -cn --arg v "${value:-$(nix eval --raw github:obeli-sk/obelisk/latest-rc)}" '[$v]')
    ;;
  *) printf 'Unknown workload: %s\n' "$workload" >&2; exit 2 ;;
esac

get() {
  curl -fsS -H "Authorization: Bearer ${OBELISK_API_TOKEN:?set OBELISK_API_TOKEN}" \
    -H accept:application/json "$api/v1/$1"
}

printf 'workload,backend,run,activity_id,locked_at,finished_at,latency_ms\n'
for ((n = 1 - warmups; n <= runs; n++)); do
  execution_id=$(obelisk generate execution-id)
  if output=$(obelisk execution submit --follow --execution-id "$execution_id" "$ffqn" "$param" 2>&1); then
    :
  else
    printf 'Execution %s failed:\n%s\n' "$execution_id" "$output" >&2
    exit 1
  fi
  activity_id=$execution_id
  if [[ $workload == todoapp || $workload == inception ]]; then
    activity_id=$(get "executions/$execution_id/responses?length=100" \
      | jq -r '[.responses[].event.event.event.child_execution_id // empty] | last // empty')
    [[ -n $activity_id ]] || { printf 'No activity child for %s\n' "$execution_id" >&2; exit 1; }
  fi
  events=$(get "executions/$activity_id/events?length=1000")
  locked=$(jq -r '[.events[] | select(.event | has("locked")) | .created_at] | last // empty' <<< "$events")
  finished=$(jq -r '[.events[] | select(.event | has("finished")) | .created_at] | last // empty' <<< "$events")
  [[ -n $locked && -n $finished ]] || {
    printf 'Missing Locked or Finished event for %s\n' "$activity_id" >&2
    exit 1
  }
  jq -e '[.events[] | select(.event | has("finished")) | .event.finished.retval.ok] | last != null' \
    <<< "$events" >/dev/null || { printf 'Activity %s failed\n' "$activity_id" >&2; exit 1; }
  latency_ms=$(jq -nr --arg locked "$locked" --arg finished "$finished" '
    def secs: (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)
      + ((capture("(?<f>\\.[0-9]+)Z$").f // "0") | tonumber);
    ((($finished | secs) - ($locked | secs)) * 1000000 | round) / 1000
  ')
  if ((n > 0)); then
    printf '%s,%s,%s,%s,%s,%s,%s\n' "$workload" "$backend" "$n" "$activity_id" \
      "$locked" "$finished" "$latency_ms"
  fi
done
