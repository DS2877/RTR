// Renders tools/view/page.html with a world dump into PNGs (see README.md).
import { chromium } from "playwright";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const [worldFile, outDir, ...only] = process.argv.slice(2);
const views = JSON.parse(fs.readFileSync(path.join(here, "views.json"), "utf8"));
const root = process.cwd(); // must contain node_modules/three
fs.mkdirSync(outDir, { recursive: true });

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  const file = url === "/" ? path.join(here, "page.html") : path.join(root, url);
  if (!fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "Content-Type": file.endsWith(".js") ? "text/javascript" : "text/html" });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(8765, r));
const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined, args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("console", (m) => console.log("page:", m.text()));
page.on("pageerror", (e) => console.log("page error:", e.message));
await page.goto("http://localhost:8765/");
await page.waitForFunction(() => window.ready === true);
let text = fs.readFileSync(worldFile, "utf8");
if (process.env.EXTRA) text += "\n" + fs.readFileSync(process.env.EXTRA, "utf8");
const stats = await page.evaluate((t) => window.load(t), text);
console.log("loaded", stats);
for (const [name, v] of Object.entries(views)) {
  if (only.length && !only.includes(name)) continue;
  const url = await page.evaluate((vv) => window.view(vv), v);
  fs.writeFileSync(path.join(outDir, name + ".png"), Buffer.from(url.split(",")[1], "base64"));
  console.log("wrote", name);
}
await browser.close();
server.close();
