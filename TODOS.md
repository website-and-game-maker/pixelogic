# Clueweave — TODOs

One repo, two halves. `web/` is the web app (TypeScript + Vite); `apple/` is
the native port (ClueweaveKit + iOS/iPad + Watch). GitHub Pages builds `web/`
only.

**Shared docs** — mirrored identically into each half's `docs/`:

| File | Purpose |
|---|---|
| `docs/AGENT-HANDOFF.md` | **Start here.** Short brief on how boredom and struggle are detected, with worked traces to test against and the exact call sites. |
| `docs/progression-model.md` | The normative contract. Signals, state machine, thresholds, persistence, test obligations. Wins over the brief if they ever disagree. |

The web app is the **reference implementation** — built, tested, green. Changing a
constant means changing it in both halves and both test suites in the same change.

---

## Source of the work

Six pieces of feedback, plus three follow-ups:

1. Hyphenate "Name hint" → "Name-hint".
2. `◈ Symmetric · H` is unclear — a help section must explain `H`, `V`, and the symbol
   for both.
3. Music Note should be **hard**, not medium.
4. Music Note should look like a **realistic eighth note**, still uniquely solvable.
5. Next-puzzle should actually progress (no Medium → Easy); promote on fast solves,
   hold then demote on give-ups; move the arrows to the bottom and differentiate them;
   last puzzle's arrow greys out; spamming degrades to plain sequential order.
6. "Surprise me" → "Recommended puzzle", with the recommender overhauled.
7. Settings to customise all of the above.
8. Shared md contract so the other agent tracks struggling/boredom identically.
9. Build and run the iOS app in the simulator to check onboarding.

---

## Status

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked

### Shared
- [x] `docs/progression-model.md` written and mirrored into both halves
- [x] `TODOS.md` (this file)

### Web — `web/` — **complete, verified in browser**
- [x] **(1)** `BADGE_INFO.named.name` → `"Name-hint"`
- [x] **(2)** About section explaining `H` / `V` / `H+V` / `180°`, generated from
      `SYMMETRY_LEGEND`; mirrored into `/badge/symmetric` and the "How to play" modal
- [x] **(3,4)** Music Note is now the verified 13×13 eighth note
      *(unique, logic-solvable, grades `hard` with no forced override)*
- [x] **(5,6)** `src/engine/progression.ts` — curriculum order, signal classification,
      promote/demote state machine, recommendation, spam guard
- [x] **(5,6)** Persistence: progression state + tolerant decode, no version bump
- [x] **(7)** Progression settings group in the settings modal
- [x] **(5)** Play view: bottom `←`/`→` strip, greyed ends, no wrap
- [x] **(5)** Play view: top-right sheen smart-next + first-3-uses opt-out prompt
- [x] **(6)** Menu: "🎲 Surprise me" → "🎯 Recommended puzzle" with pick + tier + reason
- [x] Tests: `tests/progression.test.ts`, 37 tests covering contract §8
- [x] Gates: `npm test` **274 passing**, `npm run build` clean

### Apple — `apple/` — **implemented; engine verified, UI type-checked only**
- [x] **(1)** `BadgeKey.name` → `"Name-hint"` (+ badge label)
- [x] **(2)** `symmetryLegend` in ClueweaveKit; iOS About section + Watch Legend rows
- [x] **(3,4)** Same 13×13 eighth-note bitmap, moved to the Hard block, tier `.hard`
      — the Swift grader **independently derives `hard`**, confirming web parity
- [x] **(5,6)** `ClueweaveKit/Sources/ClueweaveKit/Progression.swift`
- [x] **(5,6)** `SaveData.progression` + `GameSettings.progression` with tolerant
      decode; `PlayerStore` accessors routed through `AppModel`
- [x] **(7)** Progression settings section in `SettingsView`
- [x] **(5)** iOS PlayView: bottom nav strip + toolbar sheen smart-next + opt-out sheet
- [x] **(6)** iOS HomeView: `surpriseID()` replaced by `recommend()`, relabelled
- [x] **(6)** Watch: "Recommended" section driven by the same `recommend()`; no streak
      tracking on the wrist (contract §9)
- [x] Verifier: 42 progression checks mirrored into `clueweave-verify` —
      **426 checks, 0 failures**
- [x] Gates run: `swift build`, `swift run clueweave-verify`, `xcodegen generate`,
      `swiftc -typecheck` for **both** iOS (arm64-ios16.0-simulator) and Watch
      (arm64-watchos9.0-simulator) — all clean
- [!] **(9)** Build + run onboarding in the simulator — **blocked, see below**

---

## Blockers

**Xcode 26.6 is installed but its first-launch system components are not.**

`/Library/Developer/PrivateFrameworks/CoreSimulator.framework` does not exist, so
`xcodebuild` aborts before compiling anything:

> `Library not loaded: …/CoreSimulator.framework/Versions/A/CoreSimulator`
> `A required plugin failed to load … try running 'xcodebuild -runFirstLaunch'`

`xcode-select -p` also still points at `/Library/Developer/CommandLineTools`.

**Fix (needs an admin password, so it can't be run from an agent session):**

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Until then: no `xcodebuild` app build, no `simctl`, no simulator, so the onboarding
flow has not been run. Everything else above was actually executed, and the app
sources were type-checked directly against the iOS and watchOS simulator SDKs
(which don't need CoreSimulator) — that proves they compile, not that they run.

---

## Difficulty grading — rebuilt from playtest feedback

Reported: *"Cat is quite hard and Letter A is quite easy"* — the grader had both wrong
(Cat shipped Medium, Letter A shipped Hard). Two independent causes:

1. **A flat `+15` per contradiction proof.** Letter A needs one what-if, which on a
   5×5 means eyeballing two placements in a five-cell line — but the flat weight
   priced it like a 15×15 proof and shoved the puzzle two tiers up. Now weighted by
   the **longest line**, so the cost scales with the board.
2. **An easy ceiling that sat below every 5×5.** Nothing 25 cells could ever be
   graded easy if the solver logged a few extra steps. Cutoffs re-placed in the
   middle of the real gaps in the measured spread: **25 / 55 / 80 / 120**, each with
   ~5 work units of clearance so a bitmap tweak can't flip a tier by accident.

Resulting web library: **9 easy · 5 medium · 6 hard · 6 expert · 6 max**.
Both anchors are now pinned by tests on **both** platforms.

**Tier semantics changed.** Tiers used to be named after the hardest *technique*
required; they now measure total solving *effort*. Those come apart in both
directions — Letter A needs a what-if and is Easy; Pine Tree is line-solvable and
symmetric and is Extra Hard. The old structural invariants ("easy ⇒ line-solvable",
"expert/max ⇒ needs contradictions and is asymmetric") were removed from the web
tests, `ClueweaveKitTests`, and `clueweave-verify`, because they asserted exactly the
behaviour being fixed. Tier correctness is still fully covered by
`gradeGrid(solution) == storedTier` on every puzzle.

The Swift grader was still on the **old** sweep-counting implementation and had
already drifted from the web engine before this change — it has been rewritten as a
true port, and 17 stored tiers in `Puzzles.swift` were re-aligned to what the grader
derives. Apple's easy tier is now heavy (17 of 40) because the whole 5×5 and 7×7 sets
land there; worth a look if the ladder feels bottom-loaded.

Gates after the change: web **287 tests pass**, `npm run build` clean;
`clueweave-verify` **392 checks, 0 failures**; `swift build --build-tests` clean.

---

## Notes for whoever picks this up

- The engine must never ship a puzzle that isn't provably uniquely solvable by logic.
  The new Music Note was chosen by searching 2214 verified candidates — if you regenerate
  it, re-verify `unique == true` **and** `gradeGrid == hard` rather than forcing a tier.
- A fully-connected note shape trips `detectPatterned`, which caps difficulty at medium.
  The gap between stem and flag is load-bearing for both the art and the grade.
- Share tokens, scoring, par times, penalties, badge thresholds, and difficulty cutoffs
  must stay byte- and numerically identical across web and Apple.
