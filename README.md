# Playwright browser automation demo

This app runs a durable JavaScript workflow that controls a Chromium session through three
Obelisk exec activities: start the browser, interact with a page, and clean up. The browser runs
in this app's own Docker image. A small task-list page, served from the host by
[page/server.mjs](page/server.mjs), keeps the example independent of an external site or
credentials.

## Run

Install Nix and start a Docker daemon. Copy `.envrc-example` to `.envrc` and run `direnv allow` to
load the development shell and generate an API token. Without direnv, enter `nix develop` and run
`export OBELISK_API_TOKEN=$(obelisk generate token)` before starting the server. Skip `nix develop`
below if direnv already loaded the shell.

Before starting the server, print its token with `printf '%s\n' "$OBELISK_API_TOKEN"` if you plan
to use the CLI in another terminal.

```sh
nix develop
just build
just verify
just serve-page &
just serve
```

`just serve-page` serves the task list at `http://127.0.0.1:8090/`. The browser container uses
the host network to reach it. In another shell, run `export OBELISK_API_TOKEN='paste-token-here'` before submitting a run with a
unique session ID. Each `.envrc` load generates a new token, so a new terminal can have a different
value. You can instead run `just serve &` and the CLI in one shell, or replace the command in
`.envrc` with a fixed token.

```sh
obelisk execution submit --follow demo:playwright/workflow.run -- \
  '"first-run"' '"Buy milk"' 0
```

The workflow returns the page title and a task list containing `Buy milk`. The browser container
and socket are removed in the workflow's `finally` block, including when a page action fails.
Session IDs use lowercase letters, digits, and hyphens and may be up to 32 characters long.

To see recovery across a server restart, use a nonzero pause (in seconds) and stop Obelisk while
the workflow is sleeping:

```sh
obelisk execution submit --follow demo:playwright/workflow.run -- \
  '"restart-demo"' '"Write a note"' 30
```

Restart with `just serve`. Obelisk resumes the workflow, reads the same browser page, and removes
the container. The add-task action checks whether the task is already present before clicking, so
an activity retry cannot add a duplicate.

## Watch through VNC

Start Obelisk with `HEADED=true just serve`. In a shell using the same API token, submit the
workflow paused and advance it through browser startup:

```sh
just vnc-start watch-demo 'Buy milk'
```

The output includes the first blocked child, the local VNC address, and the execution ID. The port
and ID will differ on your machine:

```text
success, current state: Paused(BlockedByJoinSet(o:1-start, ...))
VNC: 127.0.0.1:32769
Execution: E_01M3GZGNBXR1RQW3V1SE2QDJMT
```

Connect a local VNC viewer to the printed address. The browser is open, and the workflow remains
paused before adding the task:

![VNC browser showing an empty task list](screenshots/vnc-before.png)

Advance the printed execution ID once to schedule the page action:

```sh
just vnc-advance E_01M3GZGNBXR1RQW3V1SE2QDJMT
# success, current state: Paused(BlockedByJoinSet(o:2-eval, ...))
```

After the eval activity finishes, VNC shows the new task while the workflow is still paused:

![VNC browser showing Buy milk in the task list](screenshots/vnc-task-added.png)

Advance again to read the page (`o:3-eval`), then to schedule browser cleanup (`o:4-cleanup`),
and once more to get the final result:

```sh
just vnc-advance E_01M3GZGNBXR1RQW3V1SE2QDJMT
just vnc-advance E_01M3GZGNBXR1RQW3V1SE2QDJMT
just vnc-advance E_01M3GZGNBXR1RQW3V1SE2QDJMT
# success: {"ok":{"title":"Playwright task list","tasks":["Buy milk"]}}
```

Allow each activity to finish before advancing again. You can instead run
`obelisk execution unpause E_...` to complete the remaining steps automatically; the
browser closes during cleanup.

## Check the demo

`just verify` checks the Obelisk deployment and both exec approval policies. With a Docker daemon
running, `just test-e2e` starts the page server and Obelisk, runs the full workflow, and checks that
its container was removed.

After updating `flake.lock`, refresh the recorded tool versions with
`nix develop -c ./scripts/dev-deps.sh`.

## How it fits together

- [deployment.toml](deployment.toml) declares three exec activities and one JS workflow.
- [workflow/run.js](workflow/run.js) holds the durable sequence and cleanup.
- [activity/](activity/) contains the host scripts that manage the Docker container and socket.
- [browser/](browser/) builds the image containing Playwright.
- [page/](page/) holds the task-list page and its Node server.

The browser runner is adapted from the MIT-licensed public `obeli-sk/components` Playwright
component. The app owns its image and activity scripts, so it does not depend on that repository
at runtime.
