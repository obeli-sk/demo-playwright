import fs from "node:fs/promises";
import http from "node:http";

const host = "127.0.0.1";
const port = 8090;
const indexPath = new URL("./index.html", import.meta.url);

http
  .createServer(async (req, res) => {
    if (req.method !== "GET" || new URL(req.url, "http://x").pathname !== "/") {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    res.end(await fs.readFile(indexPath));
  })
  .listen(port, host, () => console.log(`Serving http://${host}:${port}/`));
