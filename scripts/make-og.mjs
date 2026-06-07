// Render a branded 1200x630 social-preview image into public/og-image.png.
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";

mkdirSync("public", { recursive: true });

const heart = [
  ".##....##.",
  "####..####",
  "##########",
  "##########",
  "##########",
  ".########.",
  "..######..",
  "...####...",
  "....##....",
  "..........",
];
const cells = heart
  .map((row) => [...row].map((ch) => `<i class="${ch === "#" ? "f" : ""}"></i>`).join(""))
  .join("");

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
  *{margin:0;box-sizing:border-box;font-family:"Nunito",ui-rounded,system-ui,sans-serif}
  body{width:1200px;height:630px;overflow:hidden;
    background:radial-gradient(1100px 700px at 12% -10%,#d6f3f0,transparent 55%),
               radial-gradient(900px 700px at 112% 10%,#d8eefc,transparent 50%),#e9f7f7;
    display:flex;align-items:center;gap:56px;padding:0 84px}
  .left{flex:1}
  .brandrow{display:flex;align-items:center;gap:22px;margin-bottom:18px}
  .logo{width:96px;height:96px;border-radius:26px;display:grid;place-items:center;
    background:linear-gradient(135deg,#1ab9a9,#0e9184);color:#fff;font-size:3.2rem;
    box-shadow:0 18px 40px rgba(18,120,116,.28)}
  h1{font-size:5.4rem;font-weight:900;letter-spacing:-.02em;line-height:1;
    background:linear-gradient(120deg,#0e9184,#6cc8ec);-webkit-background-clip:text;background-clip:text;color:transparent}
  .tag{font-size:1.9rem;font-weight:800;color:#173a40;margin:8px 0 26px}
  .chips{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:26px}
  .chip{font-weight:900;font-size:1.1rem;padding:8px 18px;border-radius:999px}
  .c1{background:#d7f5ea;color:#0c8f6c}.c2{background:#ece0fb;color:#7a4fc0}
  .c3{background:#ffe2dd;color:#c0492f}.c4{background:linear-gradient(135deg,#2b2140,#4a2d5e);color:#fff}
  .score{display:inline-flex;align-items:center;gap:14px;background:#fff;border:2px solid #d6eefb;
    border-radius:24px;padding:14px 28px;box-shadow:0 14px 34px rgba(18,120,116,.18)}
  .score .l{font-size:2.4rem}
  .score b{font-size:2.6rem;font-weight:900;background:linear-gradient(120deg,#e3b23c,#b5862a);
    -webkit-background-clip:text;background-clip:text;color:transparent}
  .score span{font-size:1.1rem;font-weight:900;color:#0e9184;text-transform:uppercase;letter-spacing:.05em}
  .board{display:grid;grid-template-columns:repeat(10,42px);grid-template-rows:repeat(10,42px);
    border-top:3px solid #a4d4d2;border-left:3px solid #a4d4d2;border-radius:10px;overflow:hidden;
    box-shadow:0 26px 60px rgba(18,120,116,.26);background:#fff}
  .board i{border-right:1px solid #d2e9e9;border-bottom:1px solid #d2e9e9;background:#fff}
  .board i.f{background:linear-gradient(150deg,#23c2b1,#109386)}
</style></head><body>
  <div class="left">
    <div class="brandrow"><div class="logo">▦</div><h1>Pixelogic</h1></div>
    <div class="tag">Deduce the hidden picture from number clues — pure logic, no guessing.</div>
    <div class="chips"><span class="chip c1">Easy</span><span class="chip c2">Hard</span><span class="chip c3">Extra Hard</span><span class="chip c4">MAX</span></div>
    <div class="score"><span class="l">🌿</span><b>1600</b><span>Pixelogic Score</span><span class="l">🌿</span></div>
  </div>
  <div class="board">${cells}</div>
</body></html>`;

const b = await chromium.launch();
const page = await b.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
await page.setContent(html, { waitUntil: "networkidle" });
await page.screenshot({ path: "public/og-image.png" });
await b.close();
console.log("wrote public/og-image.png");
