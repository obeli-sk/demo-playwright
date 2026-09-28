import * as browser from "demo:playwright/vm-browser";

export default function run(task) {
  if (!task || !task.trim()) throw "task must not be empty";

  return JSON.parse(browser.run("http://obelisk-host:8090/", `
    const task = ${JSON.stringify(task)};
    await page.getByLabel("Task").fill(task);
    await page.getByRole("button", { name: "Add task" }).click();
    return {
      title: await page.title(),
      tasks: await page.locator("#items li").allTextContents(),
    };
  `));
}
