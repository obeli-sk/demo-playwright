#!/usr/bin/env node
const fs = require("node:fs");
const { chromium } = require("/nix/store/0k9k01y3zfnkbh71jq6vx08g572qjrpr-playwright-core-1.63.0");

const HEADLESS_SHELL =
  "/nix/store/i08h6m15rm5n2w13lc2s5kq5v607q626-playwright-chromium-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell";
const FONTS = "/nix/store/71mxn2pyq807r32qsd2mdszkajhlb39q-dejavu-fonts-2.37/share/fonts";

let done = false;

function respond(value, status) {
  done = true;
  console.log(JSON.stringify(value));
  process.exit(status);
}

async function main() {
  const [url, code] = process.argv.slice(2).map((arg) => JSON.parse(arg));
  // The headless shell aborts without a fontconfig configuration.
  fs.writeFileSync(
    "/tmp/fonts.conf",
    `<?xml version="1.0"?><fontconfig><dir>${FONTS}</dir><cachedir>/tmp/fontconfig</cachedir></fontconfig>`,
  );
  process.env.FONTCONFIG_FILE = "/tmp/fonts.conf";

  // Guest TLS ends at Obelisk's proxy, whose per-run CA Chromium does not know; the host verifies
  // upstream. The switch, unlike Playwright's ignoreHTTPSErrors, also covers service workers.
  const browser = await chromium.launch({
    executablePath: HEADLESS_SHELL,
    args: ["--ignore-certificate-errors"],
  });
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
