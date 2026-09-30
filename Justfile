set positional-arguments := true

image := "demo-playwright:local"
vm_backend := env("OBELISK_UNSTABLE_ACTIVITY_VM", "qemu-tcg")

build:
  docker build -t {{image}} runner/docker/image

serve-page:
  node todoapp/page/server.mjs

# Runs `app` (todoapp or inception) with Chromium in Docker or in activity VMs.
serve app backend:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "$1"

  server_config=""
  if [ "$2" = vm ]; then
    export OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}}
  elif [ "$2" = docker ]; then
    server_config="--server-config server-docker.toml"
  else
    echo "Unsupported deployment type: $2" >&2
    exit 1
  fi
  exec obelisk server run \
    $server_config \
    --app-config "app-$2.toml" \
    --deployment "deployment-$2.toml"

verify-docker: (_verify "todoapp" "docker") (_verify "inception" "docker")

verify-vm: (_verify "todoapp" "vm") (_verify "inception" "vm")

_verify app backend:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "$1"

  server_config=""
  if [ "$2" = vm ]; then
    export OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}}
  elif [ "$2" = docker ]; then
    server_config="--server-config server-docker.toml"
  else
    echo "Unsupported deployment type: $2" >&2
    exit 1
  fi
  obelisk server verify \
    $server_config \
    --app-config "app-$2.toml" \
    --deployment "deployment-$2.toml"

todoapp task:
  ./scripts/submit-single-step.sh demo:playwright/todoapp.run "$(jq -cn --arg value "$1" '$value')"

# Docker only: submits paused, advances through browser startup and prints the VNC address.
todoapp-multistep task pause_seconds="0":
  ./scripts/start-multistep.sh demo:playwright/todoapp-multistep.run "$(jq -cn --arg value "$1" '$value')" "$2"

# Boots `store_path` (default: the latest obelisk RC) on trynix.dev and prints `obelisk -v`.
inception store_path=`nix eval --raw github:obeli-sk/obelisk/latest-rc`:
  ./scripts/submit-single-step.sh demo:playwright/inception.run "$(jq -cn --arg value "$1" '$value')"

# Docker only: like `todoapp-multistep`.
inception-multistep store_path=`nix eval --raw github:obeli-sk/obelisk/latest-rc`:
  ./scripts/start-multistep.sh demo:playwright/inception-multistep.run "$(jq -cn --arg value "$1" '$value')"

advance execution_id:
  obelisk execution advance "$1"

unpause execution_id:
  obelisk execution unpause "$1"

cancel execution_id:
  obelisk execution cancel "$1"

test-e2e backend:
  OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}} ./scripts/test-e2e.sh "$1"

# Screenshots the web UI trace of an inception run, including the HTTP requests an activity VM made.
webui-screenshot execution_id:
  node scripts/webui-screenshot.js "$1" inception/screenshots/webui-trace.png

# Retakes <app>/screenshots/vnc-demo.gif through VNC; needs `just serve <app> docker`, and `just serve-page` for todoapp.
screenshots app:
  ./scripts/screenshots.sh "$1"
