set positional-arguments := true

image := "demo-playwright:local"
vm_backend := env("OBELISK_UNSTABLE_ACTIVITY_VM", "qemu-tcg")

build:
  docker build -t {{image}} browser

verify:
  obelisk server verify --server-config server.toml --app-config app.toml --deployment deployment.toml

serve-page:
  node page/server.mjs

serve:
  obelisk server run --server-config server.toml --app-config app.toml --deployment deployment.toml

# Boots the latest obelisk RC from Cachix in a trynix.dev browser VM and prints `obelisk -v`.
inception-docker store_path=`nix eval --raw github:obeli-sk/obelisk/latest-rc`:
  obelisk execution submit --follow demo:playwright/workflow.inception -- "$(jq -cn --arg value "$1" '$value')"

vnc-start session task:
  ./scripts/start-vnc.sh "$1" "$2"

vnc-advance execution_id:
  obelisk execution advance "$1"

test-e2e:
  ./scripts/test-e2e.sh

verify-vm:
  OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}} obelisk server verify --server-config server.toml --app-config app.toml --deployment deployment-vm.toml

serve-vm:
  OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}} obelisk server run --server-config server.toml --app-config app.toml --deployment deployment-vm.toml

test-e2e-vm:
  OBELISK_UNSTABLE_ACTIVITY_VM={{vm_backend}} ./scripts/test-e2e.sh vm
