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
  if [ "$2" = vm ]; then export OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}}; fi
  exec obelisk server run --server-config server.toml --app-config "app-$2.toml" --deployment "deployment-$2.toml"

verify: (_verify "todoapp" "docker") (_verify "inception" "docker")

verify-vm: (_verify "todoapp" "vm") (_verify "inception" "vm")

_verify app backend:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "$1"
  if [ "$2" = vm ]; then export OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}}; fi
  obelisk server verify --server-config server.toml --app-config "app-$2.toml" --deployment "deployment-$2.toml"

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

test-e2e backend:
  OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}} ./scripts/test-e2e.sh "$1"

# Retakes todoapp/screenshots through VNC; needs `just serve-page` and `just serve todoapp docker`.
screenshots:
  ./scripts/screenshots.sh
