import * as browser from "demo:playwright/browser";
import * as obelisk from "obelisk:workflow@1.0.0";

const TRYNIX_URL = "https://trynix.dev/";
const CACHE = {
  url: "https://obeli-sk.cachix.org",
  key: "obeli-sk.cachix.org-1:31iM9GWSEhAXvvuTWQ7CvAcwvgRzsuJ9yJghywSd3Jw=",
};
const COMMAND = "obelisk -v";
const BOOT_POLLS = 120;

export default function inception(store_path) {
  if (!/^\/nix\/store\/[a-z0-9]{32}-[^/]+$/.test(store_path)) {
    throw "store-path must look like /nix/store/<hash>-<name>";
  }

  const session = obelisk.randomString(12, 13).toLowerCase();
  const container = `demo-playwright-inception-${session}`;
  const socket = `/tmp/demo-playwright/inception-${session}.sock`;
  try {
    browser.start(container, socket, TRYNIX_URL);

    // trynix exposes its tools through WebMCP; the terminal is a canvas, so they are the only way to read guest output.
    browser.eval(socket, `
      await page.addInitScript(() => {
        window.__trynixTools = {};
        document.modelContext = {
          registerTool(tool) { window.__trynixTools[tool.name] = tool; },
        };
      });
      await page.reload({ waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => window.__trynixTools?.boot);
      await page.evaluate(async ([cache, storePath]) => {
        const tools = window.__trynixTools;
        await tools["set-caches"].execute({ caches: [cache] });
        await tools["select-packages"].execute({ storePaths: [storePath] });
        window.__trynixBoot = null;
        tools.boot.execute({}).then(
          (res) => { window.__trynixBoot = { ok: res.content[0].text }; },
          (err) => { window.__trynixBoot = { err: String(err?.message ?? err) }; },
        );
      }, [${JSON.stringify(CACHE)}, ${JSON.stringify(store_path)}]);
      return null;
    `);

    let boot = null;
    for (let i = 0; i < BOOT_POLLS && boot === null; i++) {
      obelisk.sleep({ seconds: 5 });
      boot = JSON.parse(browser.eval(socket, "return await page.evaluate(() => window.__trynixBoot);"));
    }
    if (boot === null) throw "timed out waiting for the trynix VM to boot";
    if (boot.err !== undefined) throw `trynix boot failed: ${boot.err}`;
    console.log(`trynix: ${boot.ok}`);

    const run = JSON.parse(browser.eval(socket, `
      return JSON.parse(await page.evaluate(async (command) =>
        (await window.__trynixTools["run-command"].execute({ command })).content[0].text,
        ${JSON.stringify(COMMAND)}));
    `));
    if (run.status !== 0 || run.timedOut) {
      throw `\`${COMMAND}\` failed with status ${run.status}: ${run.output}`;
    }
    return run.output;
  } finally {
    browser.cleanup(container, socket);
  }
}
