# Inception: Obelisk inside the browser

[trynix.dev](https://trynix.dev/) boots Nix store paths in an x86_64 VM running as QEMU compiled
to WebAssembly. These workflows add the [obeli-sk Cachix cache](https://obeli-sk.cachix.org),
select a store path, boot it and return the output of `obelisk -v`. The page draws its terminal on
a canvas, so the workflows drive it through the tools the page registers for
[WebMCP](https://github.com/webmachinelearning/webmcp), which also return the command output. See
the [top-level README](../README.md) for setup.

The store path defaults to `nix eval --raw github:obeli-sk/obelisk/latest-rc` and must be in the
obeli-sk cache. Pass another one as `just inception /nix/store/...`.

```sh
just serve inception docker   # or: just serve inception vm
```

## Single step

[workflow/run.js](workflow/run.js) loads trynix, boots and runs the command in one
`demo:playwright/browser.run` activity. It works on both deployments:

```sh
just inception
# Execution finished: OK: "obelisk 0.42.0-rc.7"
# Activity E_...o:1-run_1: locked at ..., finished at ..., took 15.432s
```

The VM activity asks for `memory.gib = 8` because trynix keeps the whole closure in the tab: the
Obelisk 0.42.0-rc.6 closure crashed the tab at 4 GiB and worked at 6 GiB. It may reach only
trynix.dev and the two binary caches, and its lock lasts 15 minutes. With `cpus = 4` the rc.7 run
above took 15 seconds on KVM; an earlier rc.6 run took about 7 minutes on TCG.

## Multi step (Docker)

[workflow/multistep.js](workflow/multistep.js) keeps one headed browser open and splits the run into
start, configure (cache and store path), boot, run the command, and cleanup:

```sh
just inception-multistep
# VNC: 127.0.0.1:32769
# Execution: E_01M3GZGNBXR1RQW3V1SE2QDJMT
just advance E_01M3GZGNBXR1RQW3V1SE2QDJMT   # repeat once per step
```

Watch trynix select the package and boot through VNC between steps, or `just unpause E_...` to run
the rest. A retried boot step waits for the boot already running in the page.
