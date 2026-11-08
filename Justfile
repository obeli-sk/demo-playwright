set positional-arguments := true

build:
  docker build -t demo-playwright:local runner/docker/image

serve-page:
  node todoapp/page/server.mjs

serve:
  cd todoapp && obelisk server run --dev --server-config server.toml --app-config app.toml --deployment deployment.toml

verify:
  cd todoapp && obelisk server verify --skip-db --server-config server.toml --app-config app.toml --deployment deployment.toml

todoapp task:
  obelisk execution submit --follow demo:playwright/todoapp.run -- "$(jq -cn --arg value "$1" '$value')"

# Starts the browser and leaves its steps paused for `just advance`.
todoapp-multistep task pause_seconds="0":
  ./scripts/start-multistep.sh "$(jq -cn --arg value "$1" '$value')" "$2"

advance execution_id:
  obelisk execution advance "$1"

unpause execution_id:
  obelisk execution unpause "$1"

cancel execution_id:
  obelisk execution cancel "$1"

test-e2e:
  ./scripts/test-e2e.sh
