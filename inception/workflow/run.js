import * as browser from "demo:playwright/browser";

const TRYNIX_URL = "https://trynix.dev/";
const CACHE = {
  url: "https://obeli-sk.cachix.org",
  key: "obeli-sk.cachix.org-1:31iM9GWSEhAXvvuTWQ7CvAcwvgRzsuJ9yJghywSd3Jw=",
};
const COMMAND = "obelisk -v";

export default function run(store_path) {
  if (!/^\/nix\/store\/[a-z0-9]{32}-[^/]+$/.test(store_path)) {
    throw "store-path must look like /nix/store/<hash>-<name>";
  }

  // One activity loads trynix, boots the closure, and runs the command, so the browser never outlives it.
  const run = JSON.parse(browser.run(TRYNIX_URL, `
    await page.addInitScript(() => {
      window.__trynixTools = {};
      document.modelContext = {
        registerTool(tool) { window.__trynixTools[tool.name] = tool; },
      };
    });
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => window.__trynixTools?.boot, null, { timeout: 120000 });
    return await page.evaluate(async ([cache, storePath, command]) => {
      const tools = window.__trynixTools;
      await tools["set-caches"].execute({ caches: [cache] });
      await tools["select-packages"].execute({ storePaths: [storePath] });
      const boot = await tools.boot.execute({});
      if (boot.isError) return { status: -1, output: \`boot failed: \${boot.content[0].text}\` };
      const run = (await tools["run-command"].execute({ command })).content[0].text;
      try {
        return JSON.parse(run);
      } catch {
        return { status: -1, output: \`boot: \${boot.content[0].text}; run-command: \${run}\` };
      }
    }, [${JSON.stringify(CACHE)}, ${JSON.stringify(store_path)}, ${JSON.stringify(COMMAND)}]);
  `));
  if (run.status !== 0 || run.timedOut) {
    throw `\`${COMMAND}\` failed with status ${run.status}: ${run.output}`;
  }
  return run.output;
}
