// Usage: webui-screenshot.js <execution-id> <output.png> [--focus <text>]
// Screenshots the Obelisk web UI trace of an execution, with child executions expanded down to their HTTP requests.
// --focus scrolls the trace so the first row containing <text> is at the top.
const { chromium } = require("playwright-core");

const WEBUI = process.env.OBELISK_WEBUI_URL ?? "http://127.0.0.1:8080";
const HTTP_ROW = /^(GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS) /;

async function main() {
  const [executionId, output, flag, focus] = process.argv.slice(2);
  if (!executionId || !output || (flag !== undefined && (flag !== "--focus" || !focus))) {
    throw new Error("usage: webui-screenshot.js <execution-id> <output.png> [--focus <text>]");
  }

  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
    const token = process.env.OBELISK_API_TOKEN;
    if (token) {
      await page.addInitScript((value) => localStorage.setItem("obelisk-api-token", value), token);
    }
    await page.goto(`${WEBUI}/execution/${executionId}`);
    await page.locator(".step-row").first().waitFor();

    // Expanding a node can load more nodes, so expand one at a time until only HTTP requests are collapsed.
    for (let clicks = 0; clicks < 100; clicks++) {
      const carets = page.locator(".step-row").filter({ has: page.locator(".step-icon span", { hasText: "▶" }) });
      let clicked = false;
      for (const row of await carets.all()) {
        if (HTTP_ROW.test(await row.locator(".step-name").innerText())) continue;
        await row.locator(".step-icon span", { hasText: "▶" }).click();
        await page.waitForLoadState("networkidle");
        clicked = true;
        break;
      }
      if (!clicked) break;
    }

    if (focus) {
      const row = page.locator(".step-row").filter({ hasText: focus }).first();
      if ((await row.count()) === 0) throw new Error(`no trace row contains ${focus}`);
      await row.evaluate((element) => {
        const pane = document.getElementById("trace-tree-pane");
        pane.scrollTop += element.getBoundingClientRect().top - pane.getBoundingClientRect().top;
      });
    }
    await page.screenshot({ path: output });
    console.log(`Wrote ${output}`);
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
