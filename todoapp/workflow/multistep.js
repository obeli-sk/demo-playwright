import * as browser from "demo:playwright/browser-session";
import { runCancellableSubmit } from "demo:playwright-obelisk-ext/todoapp-steps";
import * as obelisk from "obelisk:workflow@1.0.0";

const URL = "http://obelisk-host:8090/";
const SESSION_TIMEOUT = { minutes: 60 };
const APP_NAME = "demo-playwright-todoapp";

// Cleanup supervisor (saga): owns the browser container, races the cancellable steps workflow
// against a timeout and always removes the container. https://obeli.sk/docs/latest/patterns/cleanup-supervisor/
export default function multistep(task, pause_seconds) {
  if (!task || !task.trim()) throw "task must not be empty";

  // Docker names allow only [A-Za-z0-9_.-]; a derived execution ID also contains `:`.
  const execution_id = String(obelisk.executionIdCurrent()).replace(/[^A-Za-z0-9_.-]/g, "_");
  const container = `${APP_NAME}-${execution_id}`;
  const socket = `/tmp/demo-playwright/${execution_id}.sock`;
  let result = null;
  let error = null;
  try {
    browser.start(container, socket, URL);
    const race = obelisk.createJoinSet({ name: "session" });
    try {
      runCancellableSubmit(race, socket, task, pause_seconds);
      const timeout = race.submitDelay(SESSION_TIMEOUT);
      result = race.joinNext();
      if (race.lastId === timeout) error = "session timed out";
    } finally {
      // Cancels whichever of the steps and the timeout is still pending.
      race.close();
    }
  } catch (e) {
    error = e instanceof obelisk.ChildError && e.cancelled ? "session cancelled" : e;
  }

  try {
    browser.cleanup(container, socket);
  } catch (e) {
    console.log(`Cleanup failed for ${container}: ${String(e)}`);
    if (error === null) error = e;
  }
  if (error !== null) throw error;
  return result;
}
