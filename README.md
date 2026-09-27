# Playwright browser automation demo

This app runs a durable JavaScript workflow that controls a Chromium session through three
Obelisk exec activities: start the browser, interact with a page, and clean up. The browser runs
in this app's own Docker image. A bundled task-list page keeps the example independent of an
external site or credentials.

## Run

Install Nix and start a Docker daemon. Generate an API token with
`nix develop -c obelisk generate token`, then copy `.envrc-example` to `.envrc` and replace its
placeholder with that token. Run `direnv allow` to load the development shell and token in each
terminal. Without direnv, enter `nix develop`, run `export OBELISK_API_TOKEN=$(obelisk generate token)`
before starting the server, and export that same token in the CLI terminal.
If using direnv, skip `nix develop` below.

```sh
nix develop
just build
just verify
just serve
```

In another shell with the same token, submit a run with a unique session ID:

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

Set `HEADED=true` before `just serve` to watch Chromium through VNC. The start activity logs the
localhost VNC port.

## Check the browser without Docker

`just test-browser` installs the pinned Playwright package and runs the browser server against the
bundled page with the Nix Chromium build. It checks form interaction, retry behavior, and the
returned page state. `just verify` checks the Obelisk deployment and both exec approval policies.
With a Docker daemon running, `just test-e2e` also starts Obelisk, runs the full workflow, and
checks that its container was removed.

After updating `flake.lock`, refresh the recorded tool versions with
`nix develop -c ./scripts/dev-deps.sh`.

## How it fits together

- [deployment.toml](deployment.toml) declares three exec activities and one JS workflow.
- [workflow/run.js](workflow/run.js) holds the durable sequence and cleanup.
- [activity/](activity/) contains the host scripts that manage the Docker container and socket.
- [browser/](browser/) builds the image containing Playwright and the bundled page.

The browser runner is adapted from the MIT-licensed public `obeli-sk/components` Playwright
component. The app owns its image and activity scripts, so it does not depend on that repository
at runtime.
