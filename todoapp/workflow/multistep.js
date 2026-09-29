import * as browser from "demo:playwright/browser-session";
import * as obelisk from "obelisk:workflow@1.0.0";

export default function multistep(session_id, task, pause_seconds) {
  if (!/^[a-z0-9][a-z0-9-]{0,31}$/.test(session_id)) {
    throw "session-id must be 1 to 32 lowercase letters, digits, or hyphens";
  }
  if (!task || !task.trim()) throw "task must not be empty";

  const container = `demo-playwright-${session_id}`;
  const socket = `/tmp/demo-playwright/${session_id}.sock`;
  try {
    browser.start(container, socket, "http://obelisk-host:8090/");

    const addTask = `
      const task = ${JSON.stringify(task)};
      const items = page.locator("#items li");
      if (!(await items.allTextContents()).includes(task)) {
        await page.getByLabel("Task").fill(task);
        await page.getByRole("button", { name: "Add task" }).click();
      }
      return await items.allTextContents();
    `;
    const tasks = JSON.parse(browser.eval(socket, addTask));
    if (!tasks.includes(task)) throw "the task did not appear in the page";

    if (pause_seconds > 0) obelisk.sleep({ seconds: pause_seconds });

    return JSON.parse(browser.eval(socket, `
      return {
        title: await page.title(),
        tasks: await page.locator("#items li").allTextContents(),
      };
    `));
  } finally {
    browser.cleanup(container, socket);
  }
}
