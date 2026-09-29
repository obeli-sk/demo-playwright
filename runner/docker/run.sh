#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="demo-playwright:local"

fail() {
  local message=$1
  printf '%s\n' "$message" >&2
  jq -Rn --arg message "$message" '$message'
  exit 1
}

fail_permanent() {
  local message=$1
  printf 'permanent: %s\n' "$message" >&2
  jq -Rn --arg message "$message" '$message'
  exit 1
}

url=$(jq -er 'if type == "string" then . else error("must be a string") end' <<<"${1-}") \
  || fail_permanent "invalid JSON argument for url"
jq -e 'type == "string"' >/dev/null <<<"${2-}" \
  || fail_permanent "invalid JSON argument for code"

docker_args=(run --rm --user "$(id -u):$(id -g)" --entrypoint node)
# `obelisk-host` names the host, as it does inside an activity VM.
if [[ "$url" =~ ^https?://(localhost|127\.0\.0\.1|obelisk-host)(:[0-9]+)?(/|$) ]]; then
  docker_args+=(--network host --add-host obelisk-host:127.0.0.1)
fi

status=0
output=$(docker "${docker_args[@]}" "$IMAGE_NAME" /app/run.js "$1" "$2") || status=$?
if [ -z "$output" ]; then
  fail "docker failed to run Playwright (exit status $status)"
fi
printf '%s\n' "$output"
exit "$status"
