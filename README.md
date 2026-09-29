# Playwright browser automation demo

Two [Obelisk](https://obeli.sk) apps drive a Chromium browser with
[Playwright](https://playwright.dev) from durable JavaScript workflows:

- [todoapp/](todoapp/) adds a task to a small task-list page:

  <img src="todoapp/screenshots/vnc-demo.gif" width="322" alt="VNC browser before and after the workflow adds Buy milk to the task list">

- [inception/](inception/) opens [trynix.dev](https://trynix.dev/), boots Obelisk in a VM running
  inside the browser tab and returns the output of `obelisk -v`:

  <img src="inception/screenshots/vnc-demo.gif" width="322" alt="VNC browser loading trynix, selecting the Obelisk store path, booting the VM and printing obelisk -v">

## How it works

In Obelisk, a **workflow** is deterministic code that calls **activities**, which do the actual
work, here driving the browser. Obelisk records every activity result, so a workflow interrupted
by a crash or restart continues where it left off instead of starting over.

Each app comes with two workflows:

- **Single step** (`just todoapp`, `just inception`): one activity opens a browser, runs a
  Playwright snippet and closes the browser.
- **Multi step** (`just todoapp-multistep`, `just inception-multistep`): one browser stays open
  while the workflow calls several activities on it, one per step. You can watch the browser
  through VNC and step through the workflow yourself.

The browser runs in one of two places, chosen when you start the server:

- **Docker** (`docker`): Chromium runs in a container built from this repo. Both workflows work.
- **Activity VM** (`vm`): Obelisk starts a fresh virtual machine for each activity and removes it
  afterwards, so only the single-step workflow works.

## Setup

1. Install [Nix](https://nixos.org/download/). For the Docker backend, also start a Docker daemon.
2. Enter the development shell and create an API token for the Obelisk CLI:

   ```sh
   nix develop
   export OBELISK_API_TOKEN=$(obelisk generate token)
   ```

   With [direnv](https://direnv.net), copy `.envrc-example` to `.envrc` and run `direnv allow`
   instead. Every shell that runs `just` needs the same token.
3. For the Docker backend, build the browser image with `just build`.

## Run

Start the server for one app and backend, then run the workflows from another shell as described
in [todoapp/README.md](todoapp/README.md) and [inception/README.md](inception/README.md):

```sh
just serve todoapp docker     # or: just serve todoapp vm
just serve inception docker   # or: just serve inception vm
```

Run one server at a time, since both use the same port.

| Command | Docker | VM |
| --- | --- | --- |
| `just todoapp 'Buy milk'` | yes | yes |
| `just todoapp-multistep 'Buy milk'` | yes | no |
| `just inception` | yes | yes |
| `just inception-multistep` | yes | no |

### Stepping through a workflow

The multi-step commands submit the workflow **paused** and print its execution ID (`E_...`). A
paused execution does nothing until you tell it to continue:

- `just advance E_...` calls Obelisk's advance API, which lets the workflow run until it calls its
  next activity and then pauses it again. The activity itself runs to the end, so wait for the
  browser to change before advancing again.
- `just unpause E_...` lets the workflow run to the end.

### Activity VMs

The VM backend needs a CPU emulator or virtualizer, set with `vm_backend`. The default, `qemu-tcg`,
emulates the CPU in software and works anywhere. On Linux with `/dev/kvm`, `qemu-kvm` is much
faster:

```sh
just vm_backend=qemu-kvm serve inception vm
# or once per shell:
export OBELISK_UNSTABLE_ACTIVITY_VM=qemu-kvm
```

The first start downloads the VM runtime and the browser, which takes a while.

## Layout

- `todoapp/` and `inception/` each hold one app: its workflows, `server.toml`, and an app policy
  (`app-*.toml`) and deployment (`deployment-*.toml`) per backend.
- [runner/](runner/) runs the browser for both apps: [runner/docker/](runner/docker/) holds the
  Docker image and the scripts Obelisk calls as activities, and [runner/vm/](runner/vm/) holds the
  script that runs inside an activity VM.
- [scripts/](scripts/) holds the helpers behind the `just` commands.

## Development

`just verify` and `just verify-vm` check the deployments. `just test-e2e docker` and
`just test-e2e vm` run the todoapp workflows end to end.

Obelisk only runs activity scripts whose digest is approved. After changing a script in
`runner/docker/`, run `just verify` and copy the digests it prints into both apps'
`app-docker.toml` and `server.toml`.

The browser runner is adapted from the MIT-licensed `obeli-sk/components` Playwright component.
