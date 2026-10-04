# Activity latency benchmarks

Measured on 2026-10-04 on an Intel Core i9-14900HX host. Values are median seconds;
parentheses give measured sample counts.

| Workload | Firecracker | QEMU KVM | QEMU TCG | Bochs WASM | Docker |
| --- | ---: | ---: | ---: | ---: | ---: |
| Bash printf | 0.155 s (7) | 0.144 s (7) | 0.431 s (7) | 0.966 s (7) | not measured |
| Curl local page | 0.180 s (7) | 0.187 s (7) | 0.694 s (7) | 2.342 s (7) | not measured |
| Chromium / trynix.dev | 13.713 s (3) | 13.124 s (3) | not measured | not measured | 5.737 s (3) |

Latency runs from each activity's persisted `Locked` event to its `Finished` event,
including VM or container setup, the command, and result persistence. It excludes deployment
verification, runtime downloads, and server startup. The browser case launches Chromium,
opens trynix.dev, boots Obelisk 0.42.0 in its in-browser Linux VM, and runs `obelisk -v`.

VM measurements used the published Obelisk 0.42.0 binary. Docker was measured separately
through an already-running inception server, without explicit container CPU or memory limits.
Bash and curl have two discarded warmups; Chromium has one. All measured executions succeeded.

The [measurement notes](results/2026-10-04/README.md) contain reproduction commands,
resource sizes, source and runtime pins, and all raw CSV samples.
