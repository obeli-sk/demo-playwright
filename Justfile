set positional-arguments := true

image := "demo-playwright:local"

build:
  docker build -t {{image}} runner/docker/image

serve-page:
  node todoapp/page/server.mjs

# Browser apps use Docker; the lightweight benchmarks use host exec activities.
serve app backend:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "$1"
  exec obelisk server run --dev \
    --server-config "server-$2.toml" \
    --app-config "app-$2.toml" \
    --deployment "deployment-$2.toml"

verify-docker: (_verify "todoapp" "docker") (_verify "inception" "docker")

verify-exec: (_verify "bench" "exec")

_verify app backend:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "$1"
  obelisk server verify --skip-db \
    --server-config "server-$2.toml" \
    --app-config "app-$2.toml" \
    --deployment "deployment-$2.toml"

todoapp task:
  ./scripts/submit-single-step.sh demo:playwright/todoapp.run "$(jq -cn --arg value "$1" '$value')"

# Submits paused, advances through browser startup and prints the VNC address.
todoapp-multistep task pause_seconds="0":
  ./scripts/start-multistep.sh demo:playwright/todoapp-multistep.run "$(jq -cn --arg value "$1" '$value')" "$2"

# Boots `store_path` (default: the latest obelisk RC) on trynix.dev and prints `obelisk -v`.
inception store_path=`nix eval --raw github:obeli-sk/obelisk/latest-rc`:
  ./scripts/submit-single-step.sh demo:playwright/inception.run "$(jq -cn --arg value "$1" '$value')"

inception-multistep store_path=`nix eval --raw github:obeli-sk/obelisk/latest-rc`:
  ./scripts/start-multistep.sh demo:playwright/inception-multistep.run "$(jq -cn --arg value "$1" '$value')"

advance execution_id:
  obelisk execution advance "$1"

# Prints warm Locked-to-Finished samples as CSV; start the matching server first.
bench workload backend runs="7" warmups="2" value="":
  @./scripts/bench.sh "$1" "$2" "$3" "$4" "$5"

unpause execution_id:
  obelisk execution unpause "$1"

cancel execution_id:
  obelisk execution cancel "$1"

test-e2e backend="docker":
  ./scripts/test-e2e.sh "$1"

test-bench:
  ./scripts/test-bench.sh

# Screenshots the web UI trace of an inception run.
webui-screenshot execution_id:
  node scripts/webui-screenshot.js "$1" inception/screenshots/webui-trace.png

# Retakes <app>/screenshots/vnc-demo.gif through VNC; needs `just serve <app> docker`, and `just serve-page` for todoapp.
screenshots app:
  ./scripts/screenshots.sh "$1"
