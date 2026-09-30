// Renders every SVG in this folder to a transparent PNG in Assets/MergeIsland/UI/Art/.
//
// Usage:  node render.mjs            (all SVGs)
//         node render.mjs mi_token   (only files whose name contains "mi_token")
//
// Output size is the SVG's own width/height attributes. Rendering goes through headless
// Chrome (already installed on dev machines), so there is no npm dependency. Verify the
// output with `python check.py` afterwards.

import { readdirSync, readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join, dirname, basename, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(HERE, "../../Assets/MergeIsland/UI/Art");
const TMP_DIR = join(HERE, ".render_tmp");

const CHROME_CANDIDATES = [
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
];
const CHROME = CHROME_CANDIDATES.find((p) => existsSync(p));
if (!CHROME) {
    console.error("No Chrome/Edge found; edit CHROME_CANDIDATES.");
    process.exit(1);
}

const filter = process.argv[2] || "";
const files = readdirSync(HERE).filter((f) => f.endsWith(".svg") && f.includes(filter));
mkdirSync(OUT_DIR, { recursive: true });
mkdirSync(TMP_DIR, { recursive: true });

for (const file of files) {
    const svg = readFileSync(join(HERE, file), "utf8");
    const w = Number((svg.match(/<svg[^>]*\swidth="(\d+)"/) || [])[1]);
    const h = Number((svg.match(/<svg[^>]*\sheight="(\d+)"/) || [])[1]);
    if (!w || !h) {
        console.error(`skip ${file}: needs numeric width/height on <svg>`);
        continue;
    }
    const name = basename(file, ".svg");
    const html = join(TMP_DIR, `${name}.html`);
    writeFileSync(html,
        `<!doctype html><html><head><style>html,body{margin:0;padding:0;background:transparent;` +
        `overflow:hidden}img{display:block}</style></head><body>` +
        `<img src="${pathToFileURL(join(HERE, file)).href}" width="${w}" height="${h}"></body></html>`);
    const out = join(OUT_DIR, `${name}.png`);
    execFileSync(CHROME, [
        "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--default-background-color=00000000",
        `--window-size=${w},${h}`, `--screenshot=${out}`,
        pathToFileURL(html).href,
    ], { stdio: "ignore" });
    console.log(`${name}.png  ${w}x${h}`);
}

rmSync(TMP_DIR, { recursive: true, force: true });
