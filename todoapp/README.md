# Todo app

The workflows add a task to a small task-list page, [page/](page/), and return the resulting list.
See the [top-level README](../README.md) for setup.

Start the page and the server:

```sh
just serve-page &
just serve todoapp docker   # or: just serve todoapp vm
```

## Single step

[workflow/run.js](workflow/run.js) opens the page, adds the task and reads the list in one
activity:

```sh
just todoapp 'Buy milk'
# Execution finished: OK: {"title":"Playwright task list","tasks":["Buy milk"]}
# Activity E_...: locked at ..., finished at ..., took 1.52s
```

## Multi step (Docker only)

[workflow/multistep.js](workflow/multistep.js) opens the page in a browser you can watch, adds the
task, reads the list and closes the browser, one activity per step:

```sh
just todoapp-multistep 'Buy milk'
# VNC: 127.0.0.1:5900
# Execution: E_01M3GZGNBXR1RQW3V1SE2QDJMT
```

Connect a VNC viewer to the printed address to see the empty list, then advance to add the task:

```sh
just advance E_01M3GZGNBXR1RQW3V1SE2QDJMT
```

<img src="screenshots/vnc-demo.gif" width="644" alt="VNC browser before and after the workflow adds Buy milk to the task list">

Advance three more times to read the list, close the browser and finish, or run
`just unpause E_01M3GZGNBXR1RQW3V1SE2QDJMT`.

### Surviving a restart

The optional second argument makes the workflow wait that many seconds after adding the task.
Stop the server during the wait and start it again: the workflow picks up where it stopped, reads
the same page and closes the browser.

```sh
just todoapp-multistep 'Write a note' 30
just unpause E_...
```
