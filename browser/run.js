#!/usr/bin/env node

import process from "node:process";
import { chromium } from "playwright";

let done = false;

function respond(value, status) {
  done = true;
  console.log(JSON.stringify(value));
  process.exit(status);
}

async function main() {
  const [url, code] = process.argv.slice(2).map((arg) => JSON.parse(arg));
  const browser = await chromium.launch();
  let result;
  try {
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: "domcontentloaded" });
    const run = new Function("page", `return (async () => { ${code} })()`);
    result = await run(page);
  } finally {
    await browser.close();
  }
  // The ok arm of result<string, string> holds the JSON-encoded page result.
  respond(JSON.stringify(result ?? null), 0);
}

// A crashed browser can leave Playwright's promises pending until the event loop drains.
process.on("beforeExit", () => done || respond("browser exited without a result", 1));
main().catch((error) => respond(error.message, 1));
