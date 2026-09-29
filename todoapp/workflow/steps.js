import * as browser from "demo:playwright/browser-session";
import * as obelisk from "obelisk:workflow@1.0.0";

// Drives the browser that multistep.js started; cancelling it leaves the cleanup to that parent.
export default function runCancellable(socket, task, pause_seconds) {
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
}
