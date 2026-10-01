# Activity latency benchmarks

The results below record elapsed time from each activity's persisted `Locked` event to its
`Finished` event. This includes VM or container setup, the command, and
result persistence. It excludes deployment verification, runtime downloads, and server startup.
`scripts/bench.sh` submits executions sequentially, checks that each activity succeeded, and
prints CSV after warmup runs. For todoapp and inception it times the browser child activity, not
its parent workflow.

All samples ran on the same Intel Core i9-14900HX host on 2026-10-01. The VM samples used the
published Obelisk `0.42.0-rc.8` binary, with a separate server process for each backend. Echo prints `"hello"` with Bash's
`printf`. Curl fetches the local todoapp page at `http://obelisk-host:8090/` through Obelisk's
guest HTTP bridge. Todoapp adds `Buy milk`. Inception boots the RC8 store path
`/nix/store/dyiw7langq0wvrzanv1pys89a9lywxz3-obelisk-0.42.0-rc.8` on trynix.dev.
Echo, curl, and todoapp use 512 MiB and one guest vCPU. Inception uses 8 GiB and four guest
vCPUs, as configured in its deployment.

| Workload | Firecracker | QEMU KVM | QEMU TCG | Bochs WASM | Docker |
| --- | ---: | ---: | ---: | ---: | ---: |
| Echo | 158 ms (7) | 221 ms (7) | 471 ms (7) | 886 ms (7) | |
| Curl | 189 ms (7) | 347 ms (7) | 981 ms (7) | 2,353 ms (7) | |
| Todoapp | 808 ms (5) | 1,632 ms (5) | 13.357 s (5) | | 505 ms (5) |
| Inception | 11.122 s (3) | 16.879 s (3) | | | 5.744 s (5) |

Values are medians; parentheses give sample counts. Firecracker's echo image cache was warm.
QEMU KVM's first two echo runs were about 450 ms, while
its final five had a 217 ms median. The browser workloads were not measured on Bochs WASM or
inception on QEMU TCG.

## Repeat

Enter `nix develop` and set `OBELISK_API_TOKEN` as described in the
[top-level README](../README.md#setup). Use separate terminals for the page server, Obelisk
server, and benchmark commands. `just serve-page` is needed for curl and todoapp.

```sh
just serve-page
just vm_backend=firecracker serve bench vm
just bench echo firecracker 7 2 > echo.csv
just bench curl firecracker 7 2 > curl.csv
```

Restart Obelisk with `just vm_backend=qemu-kvm serve bench vm`, or another VM backend, before
running its samples. The `backend` argument to `just bench` labels the CSV; it does not change the
server. The last two numeric arguments are measured runs and warmup runs.

For the browser workloads, serve the matching app and pass the same backend label:

```sh
just vm_backend=firecracker serve todoapp vm
just bench todoapp firecracker 5 1 > todoapp.csv

just vm_backend=firecracker serve inception vm
just bench inception firecracker 3 1 /nix/store/dyiw7langq0wvrzanv1pys89a9lywxz3-obelisk-0.42.0-rc.8 > inception.csv
```

For Docker, run `just build`, serve either app with `just serve todoapp docker` or
`just serve inception docker`, and use the same `just bench` command with `docker` as its label.
The todoapp page stays up between runs, so its task list grows as each run adds a task.
