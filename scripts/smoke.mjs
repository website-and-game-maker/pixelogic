import { chromium } from "playwright";
import { mkdirSync } from "node:fs";

const BASE = process.env.SMOKE_URL ?? "http://localhost:4173/pixelogic/";
const SHOTS = process.env.SMOKE_SHOTS ?? "/tmp/pixelogic-shots";
mkdirSync(SHOTS, { recursive: true });

const failures = [];
const consoleErrors = [];
function check(name, cond) {
  if (cond) console.log(`  ✓ ${name}`);
  else {
    console.log(`  ✗ ${name}`);
    failures.push(name);
  }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const SEEN = JSON.stringify({
  version: 1,
  progress: {},
  completed: [],
  userPuzzles: [],
  settings: { mistakeCheck: false, showTimer: true, highlightClues: true },
  tutorialSeen: true,
});

const browser = await chromium.launch();

function wire(page) {
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", (err) => consoleErrors.push(`pageerror: ${err.message}`));
}

try {
  // ===================================================================
  // First-run TUTORIAL (fresh storage → tutorial before the menu)
  // ===================================================================
  console.log("Tutorial (first run):");
  {
    const ctx = await browser.newContext({ viewport: { width: 1120, height: 900 } });
    const page = await ctx.newPage();
    wire(page);
    await page.goto(BASE, { waitUntil: "domcontentloaded" });
    await page.waitForSelector(".view.tutorial");
    check("fresh load shows the tutorial", true);
    check("tutorial has a grey skip button top-right", (await page.locator(".tut-skip").count()) === 1);
    check("tutorial renders an interactive board", (await page.locator(".board-cells").count()) === 1);
    await page.screenshot({ path: `${SHOTS}/01-tutorial.png`, fullPage: true });

    // Walk the interactive tutorial like a real player: advance info steps via
    // Next, and on action steps tap exactly the highlighted targets.
    async function clearTargets() {
      // Tap every highlighted target; the step auto-advances when satisfied.
      for (let guard = 0; guard < 8; guard++) {
        const targets = await page.locator(".cell.tut-target").elementHandles();
        if (targets.length === 0) break;
        for (const t of targets) await t.click();
        await sleep(450);
      }
    }
    await page.click(".tut-bubble .btn:has-text('Next')"); // step 0 (info)
    await sleep(150);
    await clearTargets(); // step 1: fill row
    await clearTargets(); // step 2: cross corner
    await clearTargets(); // step 3: fill column
    const finalBtn = page.locator(".tut-bubble .btn");
    await finalBtn.waitFor({ state: "visible", timeout: 4000 });
    check("tutorial reaches the final step", (await finalBtn.textContent())?.includes("Start"));
    await finalBtn.click();
    await page.waitForSelector(".view.menu", { timeout: 4000 });
    check("finishing the tutorial lands on the menu", true);
    await ctx.close();
  }

  // Seeded context (tutorial already seen) for the rest of the flows.
  const ctx = await browser.newContext({ viewport: { width: 1200, height: 950 } });
  // Seed "tutorial already seen" ONCE; never clobber data saved during the run.
  await ctx.addInitScript((s) => {
    if (!localStorage.getItem("pixelogic.save.v1")) localStorage.setItem("pixelogic.save.v1", s);
  }, SEEN);
  const page = await ctx.newPage();
  wire(page);

  // ===================================================================
  // MENU
  // ===================================================================
  console.log("Menu:");
  await page.goto(BASE, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".view.menu");
  check("brand reads Pixelogic", (await page.textContent(".brand h1"))?.trim() === "Pixelogic");
  check("library cards render (>=20)", (await page.locator(".puzzle-card").count()) >= 20);
  const headings = await page.locator(".section-title").allTextContents();
  check("difficulty sections incl. Extra Hard", headings.some((h) => /Extra Hard/.test(h)));
  check("home shows settings + tutorial tools", (await page.locator(".menu-tools .icon-btn").count()) === 2);
  check("home has a Surprise me button", (await page.locator(".menu-actions .btn:has-text('Surprise')").count()) === 1);
  await page.screenshot({ path: `${SHOTS}/02-menu.png`, fullPage: true });

  // Surprise me jumps straight into a puzzle
  await page.click(".menu-actions .btn:has-text('Surprise')");
  await page.waitForSelector(".view.play .board-cells", { timeout: 4000 });
  check("Surprise me opens a playable puzzle", true);
  await page.goto(BASE, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".view.menu");

  // settings modal (home scope → danger zone present)
  await page.click(".menu-tools .icon-btn[aria-label='Settings']");
  await page.waitForSelector(".settings-modal");
  check("home settings has a danger zone reset", (await page.locator(".danger-zone .btn.danger").count()) >= 1);
  check("home settings has 3 toggles", (await page.locator(".settings-modal .switch").count()) === 3);
  await page.screenshot({ path: `${SHOTS}/03-settings.png` });
  await page.click(".settings-modal .modal-close");
  check("settings modal closes via ✕", (await page.locator(".settings-modal").count()) === 0);

  // ===================================================================
  // PLAY
  // ===================================================================
  console.log("Play:");
  await page.goto(`${BASE}#/play/plus`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".board-cells");
  check("play board has 25 cells", (await page.locator(".cell").count()) === 25);
  check("play header has a rules button", (await page.locator(".play-tools .icon-btn[aria-label='How to play']").count()) === 1);
  check("play header has a settings button", (await page.locator(".play-tools .icon-btn[aria-label='Game settings']").count()) === 1);

  // rules modal
  await page.click(".play-tools .icon-btn[aria-label='How to play']");
  await page.waitForSelector(".rules-modal");
  check("rules modal opens in-level", true);
  await page.screenshot({ path: `${SHOTS}/04-rules.png` });
  await page.click(".rules-modal .modal-close");

  // in-game settings (no danger zone, distinct title)
  await page.click(".play-tools .icon-btn[aria-label='Game settings']");
  await page.waitForSelector(".settings-modal");
  check("game settings titled 'Game settings'", (await page.textContent(".settings-modal .modal-title"))?.trim() === "Game settings");
  check("game settings has NO danger zone", (await page.locator(".danger-zone").count()) === 0);
  await page.click(".settings-modal .modal-close");

  // two-state grayness
  check("unsatisfied clue is NOT greyed", (await page.locator(".row-clue[data-r='2']").evaluate((e) => e.classList.contains("done"))) === false);
  await page.click('.cell[data-r="2"][data-c="0"]');
  check("click fills a cell", await page.locator('.cell[data-r="2"][data-c="0"]').evaluate((e) => e.classList.contains("filled")));

  // hint
  await page.click(".btn:has-text('Hint')");
  await sleep(150);
  check("hint shows a reason", (await page.textContent(".banner"))?.includes("must be"));
  await page.screenshot({ path: `${SHOTS}/05-play.png`, fullPage: true });

  // solve for real → win overlay with ✕ + Share
  const plus = [[0, 2], [1, 2], [2, 1], [2, 2], [2, 3], [2, 4], [3, 2], [4, 2]];
  for (const [r, c] of plus) await page.click(`.cell[data-r="${r}"][data-c="${c}"]`);
  await page.waitForSelector(".win-overlay:not(.hidden)", { timeout: 4000 });
  check("solving triggers Solved! overlay", (await page.textContent(".win-card h2"))?.trim() === "Solved!");
  check("win shows a personal best time", (await page.textContent(".win-time"))?.includes("best") || (await page.textContent(".win-time"))?.includes("Best"));
  check("win overlay has a ✕ close", (await page.locator(".win-card .modal-close").count()) === 1);
  check("win overlay has a Share button", (await page.locator(".win-actions .btn:has-text('Share')").count()) === 1);
  check("win overlay has Next + Menu", (await page.locator(".win-actions .btn:has-text('Next')").count()) === 1 && (await page.locator(".win-actions .btn:has-text('Menu')").count()) === 1);
  await page.screenshot({ path: `${SHOTS}/06-win.png` });

  // ✕ closes to admire → share affordance + back button remain
  await page.click(".win-card .modal-close");
  await sleep(150);
  check("✕ closes overlay to admire", (await page.locator(".win-overlay:not(.hidden)").count()) === 0);
  check("admire leaves a Share-result button", (await page.locator(".banner .btn:has-text('Share')").count()) === 1);
  check("back button persists after closing popup", (await page.locator(".back-btn").count()) === 1);
  await page.screenshot({ path: `${SHOTS}/07-admire.png`, fullPage: true });

  // Restart, re-solve, and confirm Esc also closes the win dialog (a11y)
  await page.click(".btn:has-text('Restart')");
  await sleep(150);
  const plusFull2 = [[0, 2], [1, 2], [2, 0], [2, 1], [2, 2], [2, 3], [2, 4], [3, 2], [4, 2]];
  for (const [r, c] of plusFull2) await page.click(`.cell[data-r="${r}"][data-c="${c}"]`);
  await page.waitForSelector(".win-overlay:not(.hidden)", { timeout: 4000 });
  check("re-solving after Restart still celebrates", true);
  await page.keyboard.press("Escape");
  await sleep(150);
  check("Esc closes the win overlay", (await page.locator(".win-overlay:not(.hidden)").count()) === 0);

  // reveal must say Revealed, not Solved
  await page.goto(`${BASE}#/play/smiley`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".board-cells");
  await page.click(".btn:has-text('Reveal')");
  await page.waitForSelector(".win-overlay:not(.hidden)", { timeout: 4000 });
  check("reveal shows Revealed (not a solve)", (await page.textContent(".win-card h2"))?.trim() === "Revealed");
  check("revealed overlay hides Share", (await page.locator(".win-actions .btn:has-text('Share')").count()) === 0);

  // zero-line grayness: 'heart' bottom row (index 9) clue is 0 → met (grey) when empty
  await page.goto(`${BASE}#/play/heart`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".board-cells");
  check("empty 0-clue row is greyed (met)", await page.locator(".row-clue[data-r='9']").evaluate((e) => e.classList.contains("done")));
  await page.click('.cell[data-r="9"][data-c="0"]'); // wrongly fill it → nonzero count
  await sleep(80);
  check("0-clue row with a filled cell is NOT greyed", (await page.locator(".row-clue[data-r='9']").evaluate((e) => e.classList.contains("done"))) === false);

  // ===================================================================
  // EXTRA HARD
  // ===================================================================
  console.log("Extra Hard:");
  await page.goto(`${BASE}#/play/enigma`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".board-cells");
  check("enigma is a 13x13 board", (await page.locator(".cell").count()) === 169);
  check("enigma chip reads Extra Hard", (await page.locator(".play-sub .chip:has-text('Extra Hard')").count()) === 1);

  // ===================================================================
  // EDITOR — uniqueness guidance + test/save round-trip
  // ===================================================================
  console.log("Editor:");
  await page.goto(`${BASE}#/editor`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".board-cells.drawable");
  await page.selectOption(".size-select", "5");
  await sleep(120);
  // Ambiguous: two diagonal cells → not unique → guidance + highlight
  await page.click('.cell[data-r="0"][data-c="0"]');
  await page.click('.cell[data-r="1"][data-c="1"]');
  await sleep(400);
  check("ambiguous draw reports not-unique", (await page.textContent(".verdict"))?.includes("Not unique"));
  check("guidance tells how to fix it", await page.locator(".verdict-guidance:not(.hidden)").count() >= 1);
  check("ambiguous cell is highlighted", (await page.locator(".cell.ambiguous").count()) >= 1);
  check("Save is disabled while ambiguous", await page.locator(".btn:has-text('Save')").isDisabled());
  await page.screenshot({ path: `${SHOTS}/08-editor-ambiguous.png`, fullPage: true });

  // Make it unique (draw the Plus)
  await page.click(".btn:has-text('Clear')");
  await sleep(120);
  const plusFull = [[0, 2], [1, 2], [2, 0], [2, 1], [2, 2], [2, 3], [2, 4], [3, 2], [4, 2]];
  for (const [r, c] of plusFull) await page.click(`.cell[data-r="${r}"][data-c="${c}"]`);
  await page.fill(".title-input", "Saver");
  await page.waitForFunction(() => {
    const b = [...document.querySelectorAll(".btn")].find((x) => x.textContent.includes("Save"));
    return b && !b.disabled;
  }, null, { timeout: 4000 });
  check("unique puzzle enables Save", true);
  await page.screenshot({ path: `${SHOTS}/09-editor-unique.png`, fullPage: true });

  // Test it
  await page.click(".btn:has-text('Test')");
  await page.waitForSelector(".chip:has-text('Test play')", { timeout: 4000 });
  check("Test launches play in test mode", true);
  check("test back button targets the editor", (await page.textContent(".back-btn"))?.includes("Editor"));
  for (const [r, c] of plusFull) await page.click(`.cell[data-r="${r}"][data-c="${c}"]`);
  await page.waitForSelector(".win-actions .btn:has-text('Back to editor')", { timeout: 4000 });
  check("test-solve popup offers Back to editor (not Menu)", (await page.locator(".win-actions .btn:has-text('Menu')").count()) === 0);
  await page.click(".win-actions .btn:has-text('Back to editor')");
  await page.waitForSelector(".board-cells.drawable", { timeout: 4000 });
  check("returns to editor with the draft intact", (await page.inputValue(".title-input")) === "Saver");

  // Save → home, exactly one custom puzzle (no accidental spam)
  await page.waitForFunction(() => {
    const b = [...document.querySelectorAll(".btn")].find((x) => x.textContent.includes("Save"));
    return b && !b.disabled;
  }, null, { timeout: 4000 });
  await page.click(".btn:has-text('Save')");
  await page.waitForSelector(".view.menu", { timeout: 4000 });
  check("Save returns to the home menu", true);
  check("custom saved exactly once", (await page.locator(".my-puzzles .puzzle-card:has-text('Saver')").count()) === 1);
  check("My Puzzles grouped into difficulty categories", (await page.locator(".my-puzzles .menu-subsection").count()) >= 1);
  check("custom card is editable + deletable", (await page.locator(".my-puzzles .card-action[aria-label^='Edit']").count()) >= 1 && (await page.locator(".my-puzzles .card-action[aria-label^='Delete']").count()) >= 1);
  await page.screenshot({ path: `${SHOTS}/10-my-puzzles.png`, fullPage: true });

  // Edit round-trips
  await page.click(".my-puzzles .card-action[aria-label^='Edit']");
  await page.waitForSelector(".board-cells.drawable", { timeout: 4000 });
  check("Edit opens the editor on the saved puzzle", (await page.inputValue(".title-input")) === "Saver");
  check("editor header reads Edit puzzle", (await page.textContent(".play-title h1"))?.includes("Edit"));

  // Delete (two-tap confirm)
  await page.goto(BASE, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".view.menu");
  await page.click(".my-puzzles .card-action.danger");
  await sleep(120);
  check("first delete tap asks to confirm", (await page.locator(".puzzle-card.confirm-delete").count()) >= 1);
  check("armed delete announces via aria-label", (await page.locator(".my-puzzles .card-action.danger[aria-label^='Confirm delete']").count()) >= 1);
  await page.click(".my-puzzles .card-action.danger");
  await sleep(200);
  check("second delete tap removes the puzzle", (await page.locator(".my-puzzles").count()) === 0);

  // ===================================================================
  // EXPLAINER
  // ===================================================================
  console.log("Explainer:");
  await page.goto(`${BASE}#/explain/plus`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".explainer .board-cells");
  await page.click(".btn:has-text('Step')");
  await page.click(".btn:has-text('Step')");
  check("explainer advances steps", !(await page.textContent(".explain-progress"))?.startsWith("0 "));

  // ===================================================================
  // MOBILE
  // ===================================================================
  console.log("Mobile:");
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(BASE, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".view.menu");
  check("mobile menu tools visible", (await page.locator(".menu-tools .icon-btn").count()) === 2);
  await page.screenshot({ path: `${SHOTS}/11-mobile-menu.png`, fullPage: true });
  await page.goto(`${BASE}#/play/heart`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".board-cells");
  const box = await page.locator(".board").boundingBox();
  check("mobile board fits viewport width", !!box && box.width <= 390);
  await page.screenshot({ path: `${SHOTS}/12-mobile-play.png`, fullPage: true });

  await ctx.close();
} catch (err) {
  failures.push(`EXCEPTION: ${err.message}`);
  console.log("EXCEPTION:", err.message);
} finally {
  await browser.close();
}

console.log("\nConsole errors:", consoleErrors.length);
for (const e of consoleErrors) console.log("  !", e);

const realConsoleErrors = consoleErrors.filter((e) => !/fonts\.g(oogleapis|static)/.test(e));
if (failures.length === 0 && realConsoleErrors.length === 0) {
  console.log("\nSMOKE OK");
  process.exit(0);
} else {
  console.log(`\nSMOKE FAIL — ${failures.length} checks, ${realConsoleErrors.length} console errors`);
  for (const f of failures) console.log("  -", f);
  process.exit(1);
}
