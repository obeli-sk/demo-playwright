import * as browser from "demo:playwright/browser-session";

const CACHE = {
  url: "https://obeli-sk.cachix.org",
  key: "obeli-sk.cachix.org-1:31iM9GWSEhAXvvuTWQ7CvAcwvgRzsuJ9yJghywSd3Jw=",
};
const COMMAND = "obelisk -v";

// Drives the browser that multistep.js started; cancelling it leaves the cleanup to that parent.
export default function runCancellable(socket, store_path) {
  // trynix exposes its tools through WebMCP; the terminal is a canvas, so they are the only way to read guest output.
  browser.eval(socket, `
    await page.addInitScript(() => {
      window.__trynixTools = {};
      document.modelContext = {
        registerTool(tool) { window.__trynixTools[tool.name] = tool; },
      };
    });
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => window.__trynixTools?.boot, null, { timeout: 120000 });
    await page.evaluate(async ([cache, storePath]) => {
      const tools = window.__trynixTools;
      await tools["set-caches"].execute({ caches: [cache] });
      await tools["select-packages"].execute({ storePaths: [storePath] });
    }, [${JSON.stringify(CACHE)}, ${JSON.stringify(store_path)}]);
    return null;
  `);

  // A retried boot awaits the one already in flight instead of starting another.
  const boot = JSON.parse(browser.eval(socket, `
    return await page.evaluate(async () => {
      window.__trynixBoot ??= window.__trynixTools.boot.execute({});
      const res = await window.__trynixBoot;
      // The console starts below the fold of the default 1280x720 viewport.
      document.getElementById("console")?.scrollIntoView({ block: "end" });
      return { isError: !!res.isError, text: res.content[0].text };
    });
  `));
  if (boot.isError) throw `trynix boot failed: ${boot.text}`;
  console.log(`trynix: ${boot.text}`);

  const run = JSON.parse(browser.eval(socket, `
    return JSON.parse(await page.evaluate(async (command) =>
      (await window.__trynixTools["run-command"].execute({ command })).content[0].text,
      ${JSON.stringify(COMMAND)}));
  `));
  if (run.status !== 0 || run.timedOut) {
    throw `\`${COMMAND}\` failed with status ${run.status}: ${run.output}`;
  }
  return run.output;
}
