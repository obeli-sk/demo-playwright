# Playwright browser automation demo

Two Obelisk apps drive Chromium from durable JavaScript workflows:

- [todoapp/](todoapp/) adds a task to a small task-list page served from the host.
- [inception/](inception/) opens [trynix.dev](https://trynix.dev/), boots Obelisk in an in-browser
  VM and returns the output of `obelisk -v`.

Each app has two deployments. Chromium runs either in this repo's Docker image
(`deployment-docker.toml`) or in an Obelisk activity VM (`deployment-vm.toml`).

- **Single step.** `demo:playwright/todoapp.run` and `demo:playwright/inception.run` call one
  activity, `demo:playwright/browser.run(url, code)`, which launches a browser, runs one Playwright
  snippet and closes it. Both deployments export the same FFQNs, so `just todoapp` and
  `just inception` work unchanged against either.
- **Multi step (Docker only).** `demo:playwright/todoapp-multistep.run` and
  `demo:playwright/inception-multistep.run` keep one headed browser alive across the
  `browser-session.start`, `.eval` and `.cleanup` activities. You can watch it through VNC and step
  through the workflow with `just advance`.

## Setup

Install Nix. For the Docker deployments, start a Docker daemon and build the image. Copy
`.envrc-example` to `.envrc` and run `direnv allow` to load the development shell and generate an
API token. Without direnv, enter `nix develop` and run
`export OBELISK_API_TOKEN=$(obelisk generate token)`. Use the same token in every shell that runs
the CLI.

```sh
nix develop
just build    # Docker image, only for deployment-docker.toml
```

## Run

Start one app at a time. Each has its own database, but both listen on the default API port:

```sh
just serve todoapp docker     # or: just serve todoapp vm
just serve inception docker   # or: just serve inception vm
```

Then follow [todoapp/README.md](todoapp/README.md) or [inception/README.md](inception/README.md).
In short:

| Target | Docker | VM |
| --- | --- | --- |
| `just todoapp 'Buy milk'` | yes | yes |
| `just todoapp-multistep 'Buy milk'` | yes | no |
| `just inception [store-path]` | yes | yes |
| `just inception-multistep [store-path]` | yes | no |
| `just advance E_...` / `just unpause E_...` | yes | no |

## Activity VMs

The VM deployments need Obelisk 0.42.0-rc.7 or later, which adds the native QEMU backend.
`just serve <app> vm` uses TCG by default; set `OBELISK_UNSTABLE_ACTIVITY_VM=qemu-kvm` on a host
with `/dev/kvm`. The first deployment downloads the QEMU runtime bundle and the Nix closure of
Node, Playwright and the Chromium headless shell. Each VM activity is a fresh guest, so
[vm/browser.js](vm/browser.js) launches the browser, runs one snippet and exits.

The guest reaches the host as `obelisk-host`. The Docker runner maps the same name to the host, so
the workflows use `http://obelisk-host:8090/` on both backends. Chromium in the guest runs with
`--ignore-certificate-errors`: guest HTTPS ends at Obelisk's guest proxy, which signs with a
per-run CA that Chromium does not trust, and the host verifies the real upstream certificate
before any request leaves.

## Layout

- [browser/](browser/) builds the Docker image. `server.js` serves a long-lived browser session
  over a socket; `run.js` runs one snippet and exits.
- [activity/](activity/) holds the exec activity scripts: `run.sh` for the single step, and
  `start.sh`, `eval.sh`, `cleanup.sh` for the session.
- [vm/](vm/) holds the Playwright script run inside the activity VM.
- `todoapp/` and `inception/` each hold `app.toml`, `server.toml`, both deployments and their
  workflows. Deployment files must be local to the deployment directory, so `activity/` and `vm/`
  are symlinked into each app.

## Check the demo

`just verify` checks both Docker deployments and their exec approval policies; `just verify-vm`
checks the VM deployments. With a Docker daemon running, `just test-e2e` starts the page server
and Obelisk, runs both todoapp workflows and checks that the session container was removed.
`just test-e2e vm` runs the single-step todoapp workflow in an activity VM.

After changing a script in `activity/`, run `just verify` and copy the digests it prints into both
apps' `app.toml` and `server.toml`. After updating `flake.lock`, refresh the recorded tool versions
with `nix develop -c ./scripts/dev-deps.sh`.

The browser runner is adapted from the MIT-licensed public `obeli-sk/components` Playwright
component. The app owns its image and activity scripts, so it does not depend on that repository
at runtime.
