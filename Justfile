set positional-arguments := true

image := "demo-playwright:local"

build:
  docker build -t {{image}} browser

verify:
  obelisk server verify --server-config server.toml --app-config app.toml --deployment deployment.toml

serve:
  obelisk server run --server-config server.toml --app-config app.toml --deployment deployment.toml

vnc-start session task:
  ./scripts/start-vnc.sh "$1" "$2"

vnc-advance execution_id:
  obelisk execution advance "$1"

test-browser:
  npm ci --prefix browser --ignore-scripts
  ./scripts/test-browser-server.sh

test-e2e:
  ./scripts/test-e2e.sh
