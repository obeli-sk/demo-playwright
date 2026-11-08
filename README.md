# Playwright in Docker

Run Playwright in a Docker container from an [Obelisk](https://obeli.sk) JavaScript workflow.
The demo adds a task to a local page and returns its title and task list.

- **Single step:** start a browser, run a Playwright snippet, and close it in one activity.
- **Multi step:** keep a browser open across activities, watch it over VNC, and advance the workflow
  one step at a time. A supervisor workflow removes the container on success, failure, cancellation,
  or a one-hour timeout.

<img src="todoapp/screenshots/vnc-demo.gif" width="644" alt="Browser before and after the workflow adds Buy milk to the task list">

## Run

Install Nix and start a Docker daemon. The local page uses Docker host networking; run this demo
on Linux with a local Docker daemon.

```sh
nix develop
export OBELISK_API_TOKEN=$(obelisk generate token)
export OBELISK_API_URL=http://127.0.0.1:5005
just build
just serve-page
```

In another shell, enter `nix develop`, export the **same token**, and start Obelisk:

```sh
export OBELISK_API_TOKEN='paste-the-same-token-here'
just serve
```

In a third shell, enter `nix develop` and export that token and `OBELISK_API_URL` as above:

```sh
just todoapp 'Buy milk'
# {"title":"Playwright task list","tasks":["Buy milk"]}
```

Obelisk's Web UI is at <http://127.0.0.1:8080>.

## Watch and step through the browser

```sh
just todoapp-multistep 'Buy milk'
# VNC: 127.0.0.1:5900
# Execution: E_...
# Supervisor: E_...
```

Connect a VNC viewer to the printed address. Use the **Execution** ID to control the browser steps:

```sh
just advance E_...  # Add the task; repeat to read the list and finish.
just unpause E_...  # Run the remaining steps.
just cancel E_...   # Stop the steps; the supervisor still removes the container.
```

To try recovery after a restart, run `just todoapp-multistep 'Buy milk' 30`, then unpause its
Execution ID. Restart `just serve` during the wait. The workflow resumes and cleans up its browser.

## Code and checks

- `todoapp/workflow/run.js`: the single-step Playwright snippet.
- `todoapp/workflow/multistep.js` and `steps.js`: browser lifecycle and separate browser steps.
- `runner/docker/`: exec activity scripts and the Playwright image.
- `todoapp/page/`: the local task-list page.
- `todoapp/{app,server,deployment}.toml`: policy, exec approvals, and component declarations.

Run `just verify` to check the deployment and `just test-e2e` to exercise both workflows and check
container cleanup. After editing an exec activity script, review the new digest printed by
`just verify` and update its approval in both `todoapp/app.toml` and `todoapp/server.toml`.

The browser runner is adapted from the MIT-licensed `obeli-sk/components` Playwright component.
