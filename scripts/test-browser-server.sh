#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

test_dir=$(mktemp -d)
socket="$test_dir/browser.sock"
server_pid=""
cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -r "$test_dir"
}
trap cleanup EXIT

node browser/server.js "$socket" "file://$PWD/browser/fixture.html" >"$test_dir/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 1 100); do
  if [ -S "$socket" ]; then break; fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$test_dir/server.log" >&2
    exit 1
  fi
  sleep 0.1
done
if [ ! -S "$socket" ]; then
  cat "$test_dir/server.log" >&2
  exit 1
fi

evaluate() {
  local code=$1
  activity/eval.sh "$(jq -nc --arg socket "$socket" '$socket')" \
    "$(jq -nc --arg code "$code" '$code')" | jq -r .
}

code='const task = "Buy milk"; const items = page.locator("#items li"); if (!(await items.allTextContents()).includes(task)) { await page.getByLabel("Task").fill(task); await page.getByRole("button", { name: "Add task" }).click(); } return await items.allTextContents();'
for _ in 1 2; do
  response=$(evaluate "$code")
  jq -e '. == ["Buy milk"]' <<<"$response" >/dev/null
done

response=$(evaluate 'return { title: await page.title(), tasks: await page.locator("#items li").allTextContents() };')
jq -e '. == {title:"Playwright task list",tasks:["Buy milk"]}' <<<"$response" >/dev/null
printf 'Browser server and form flow passed\n'
