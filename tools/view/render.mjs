// Renders tools/view/page.html with a world dump into PNGs (see README.md).
import { chromium } from "playwright";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const [worldFile, outDir, ...only] = process.argv.slice(2);
const views = JSON.parse(fs.readFileSync(process.env.VIEWS || path.join(here, "views.json"), "utf8"));
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
const W = Number(process.env.W || 1280), H = Number(process.env.H || 720);
const page = await browser.newPage({ viewport: { width: W, height: H } });
page.on("console", (m) => console.log("page:", m.text()));
page.on("pageerror", (e) => console.log("page error:", e.message));
await page.goto(`http://localhost:8765/?w=${W}&h=${H}`);
await page.waitForFunction(() => window.ready === true);
// EXTRA = comma-separated extra dumps (tunnel.txt, actors.txt): their T lines point at part numbers
// inside their own file, so they are shifted by the parts that come before
let text = fs.readFileSync(worldFile, "utf8");
const countParts = (t) => t.split("\n").filter((l) => l.startsWith("P|")).length;
for (const file of (process.env.EXTRA || "").split(",").filter(Boolean)) {
  const offset = countParts(text);
  const extra = fs
    .readFileSync(file, "utf8")
    .split("\n")
    .map((l) => {
      if (!l.startsWith("T|")) return l;
      const f = l.split("|");
      f[1] = String(Number(f[1]) + offset);
      return f.join("|");
    })
    .join("\n");
  text += "\n" + extra;
}
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
