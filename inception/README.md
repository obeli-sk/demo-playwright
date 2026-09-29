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
# Execution finished: OK: "obelisk 0.42.0-rc.7"
# Activity E_...: locked at ..., finished at ..., took 15.432s
```

The in-browser VM is heavy: on the VM backend each run gets 8 GiB of memory and 4 CPUs, and
without KVM it takes several minutes.

## Multi step (Docker only)

[workflow/multistep.js](workflow/multistep.js) keeps one browser open and runs one activity per
step: open the page, select the build, boot, run `obelisk -v`, and close the browser.

```sh
just inception-multistep
# VNC: 127.0.0.1:32769
# Execution: E_01M3GZGNBXR1RQW3V1SE2QDJMT
```

Connect a VNC viewer to the printed address and run `just advance E_...` to take each step, or
`just unpause E_...` to run the rest:

<img src="screenshots/vnc-demo.gif" width="644" alt="VNC browser loading trynix, selecting the Obelisk store path, booting the VM and printing obelisk -v">
