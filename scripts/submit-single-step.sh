#!/usr/bin/env bash
# Usage: submit-single-step.sh <workflow-ffqn> [json-param...]; follows the workflow, then prints how long its activity ran.
set -euo pipefail

ffqn=${1:?workflow FFQN required}
shift
api=${OBELISK_API_URL:-http://127.0.0.1:5005}

get() {
  curl -fsS -H "Authorization: Bearer $OBELISK_API_TOKEN" -H accept:application/json "$api/v1/$1"
}

execution_id=$(obelisk generate execution-id)
status=0
obelisk execution submit --follow --execution-id "$execution_id" "$ffqn" -- "$@" || status=$?

children=$(get "executions/$execution_id/responses?length=100" \
  | jq -r '.responses[].event.event.event | .child_execution_id // empty')
for child in $children; do
  # Timing of the last attempt: its final `locked` event until `finished`.
  get "executions/$child/events?length=1000" | jq -r --arg child "$child" '
    def secs: (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)
      + ((capture("(?<f>\\.[0-9]+)Z$").f // "0") | tonumber);
    [.events[] | select(.event | has("locked")) | .created_at] as $locks
    | ([.events[] | select(.event | has("finished")) | .created_at] | last) as $finished
    | if ($locks | length) == 0 or $finished == null then "Activity \($child) did not finish"
      else "Activity \($child): locked at \($locks | last), finished at \($finished), took \(
        ($finished | secs) - ($locks | last | secs) | . * 1000 | round / 1000)s"
        + (if ($locks | length) > 1 then " (attempt \($locks | length))" else "" end)
      end'
done
exit "$status"
