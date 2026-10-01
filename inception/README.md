# Inception: Obelisk inside the browser

[trynix.dev](https://trynix.dev/) boots Nix packages in a Linux VM that runs inside the browser
tab. The workflows open it, pick an Obelisk build from the
[obeli-sk binary cache](https://obeli-sk.cachix.org), boot it and return the output of
`obelisk -v`. They drive the page through the tools it offers to AI agents via
[WebMCP](https://github.com/webmachinelearning/webmcp). See the [top-level README](../README.md)
for setup.

```sh
just serve inception docker   # or: just serve inception vm
```

By default the workflows boot the latest Obelisk release candidate. To boot another build from the
cache, pass its Nix store path, as in `just inception /nix/store/...`.

## Single step

[workflow/run.js](workflow/run.js) does everything in one activity:

```sh
just inception
# Execution finished: OK: "obelisk 0.42.0-rc.9"
# Activity E_...: locked at ..., finished at ..., took 15.432s
```

The in-browser VM is heavy: on the VM backend each run gets 8 GiB of memory and 4 CPUs, and
without KVM it takes several minutes.

On the VM backend, Obelisk records every HTTP request the activity makes. Open the execution in the
web UI at <http://127.0.0.1:8080> and expand the activity to see what Chromium fetched and how
long each request took. The Google Tag Manager request fails because the VM may only reach
trynix.dev and the two binary caches:

<img src="screenshots/webui-trace.png" width="800" alt="Obelisk web UI trace of an inception run: the workflow, its browser.run activity and the HTTP requests Chromium made from the activity VM">

## Multi step (Docker only)

[workflow/multistep.js](workflow/multistep.js) opens trynix in a browser you can watch and
removes the browser at the end. In between, [workflow/steps.js](workflow/steps.js) selects the
build, boots it and runs `obelisk -v`, one activity per step. See
[Cleaning up the browser](../README.md#cleaning-up-the-browser) for how the two fit together.

```sh
just inception-multistep
# VNC: 127.0.0.1:32769
# Execution: E_01M3GZGNBXR1RQW3V1SE2QDJMT.n:session_1
# Supervisor: E_01M3GZGNBXR1RQW3V1SE2QDJMT
```

Connect a VNC viewer to the printed address and run `just advance` with the printed execution ID to
take each step, `just unpause` to run the rest or `just cancel` to stop:

<img src="screenshots/vnc-demo.gif" width="644" alt="VNC browser loading trynix, selecting the Obelisk store path, booting the VM and printing obelisk -v">
