# Generated Puzzles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let players generate brand-new, provably-solvable Clueweave puzzles, save them to a "Generated" library (divided by difficulty, with symmetric/patterned badges), play them, share them by link, and send the good ones to the developer.

**Architecture:** A pure generator lives in ClueweaveKit (shared engine). It produces random grids and keeps only those that are *line-solvable* — propagation alone solving to completion mathematically guarantees a unique solution that needs no guessing, so generated puzzles uphold the app's core promise for free. The grader assigns difficulty (line-solvable puzzles fall in easy/medium/hard); badges are auto-detected. Persistence reuses the `StoredPuzzle` shape in a new `generatedPuzzles` collection on `PlayerStore`. iOS UI reuses `PlayView`/`PuzzleCard`/`BoardView`/`Theme`/`ShareCodec`. Watch + website are out of scope (separate surfaces; noted at the end).

**Tech Stack:** Swift 6 / SwiftUI (iOS 16), SwiftPM (ClueweaveKit), XcodeGen.

**Grounding (measured):** random grids are line-solvable 58–77% of the time (n=5..10), so generation succeeds in ~1–2 attempts (~2 ms). Tiers that emerge: easy (mostly small), medium (all sizes), hard (mostly larger). Expert/MAX never emerge from line-solvable grids — that is expected and fine.

**Out of scope (documented follow-ups):** generating on Apple Watch (small screen / no sync — the watch keeps playing the curated set); the website generator (separate repo `website-and-game-maker/clueweave`). Both can adopt the same engine generator later.

---

## File Structure

- **Create** `ClueweaveKit/Sources/ClueweaveKit/Generator.swift` — `generatePuzzle`, a seeded RNG for tests, the "worth submitting" rule, title/id helpers.
- **Modify** `ClueweaveKit/Sources/ClueweaveKit/PlayerStore.swift` — add `generatedPuzzles` to `SaveData` (+ CodingKeys + tolerant decode), accessors, keep across reset, clear in-progress on delete.
- **Modify** `ClueweaveKit/Sources/clueweave-verify/main.swift` — verifier checks for the generator + store.
- **Modify** `ClueweaveKit/Tests/ClueweaveKitTests/EngineTests.swift` — Swift Testing mirrors.
- **Modify** `Apps/iOS/Theme.swift` — add `Route.playGenerated(String)` and `Route.generator`.
- **Modify** `Apps/iOS/ClueweaveApp.swift` — `destination(for:)` arms; `AppModel` generated accessors + `anyPuzzle` lookup.
- **Create** `Apps/iOS/GeneratorView.swift` — pick size → Generate → preview (board + difficulty + badges) → Save / Share / Send / Regenerate.
- **Modify** `Apps/iOS/HomeView.swift` — a "Generate a puzzle" entry; a "Generated" section grouped by difficulty with badges + manage (delete).
- **Modify** `Apps/iOS/PlayViewModel.swift` — persist in-progress for `g-` ids; share URL = token for generated.
- **Modify** `README.md`, `docs/AppStoreReadiness.md`.

---

## Task 1: Puzzle generator (engine, TDD)

**Files:**
- Create: `ClueweaveKit/Sources/ClueweaveKit/Generator.swift`
- Test: `ClueweaveKit/Tests/ClueweaveKitTests/EngineTests.swift` (append a `GeneratorTests` suite)
- Mirror: `ClueweaveKit/Sources/clueweave-verify/main.swift`

- [ ] **Step 1 — Write the implementation.** A line-solvable grid has exactly one solution and needs no guessing, so filter on `isLineSolvable`. Inject the RNG so tests are deterministic.

```swift
// Generator.swift
import Foundation

/// Deterministic RNG for reproducible generation in tests (SplitMix64).
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private let genAdjectives = ["Quiet","Curious","Bright","Hidden","Clever","Bold","Gentle","Wandering","Brisk","Stray","Lucid","Sly"]
private let genNouns = ["Spark","Maze","Cinder","Lattice","Echo","Drift","Glyph","Ember","Vertex","Riddle","Thicket","Cascade"]

/// Generate a brand-new puzzle of `size`x`size` that is provably unique and
/// solvable by pure line logic. Returns nil only if no valid grid is found in
/// `maxAttempts` (effectively never for sizes <= 12, given ~60% hit rate).
public func generatePuzzle(size: Int,
                           using rng: inout some RandomNumberGenerator,
                           maxAttempts: Int = 2000) -> Puzzle? {
    guard size >= 5, size <= 15 else { return nil }
    for _ in 0..<maxAttempts {
        let p = Double.random(in: 0.42...0.62, using: &rng)
        var grid = [[Bool]]()
        grid.reserveCapacity(size)
        var filled = 0
        for _ in 0..<size {
            var row = [Bool]()
            row.reserveCapacity(size)
            for _ in 0..<size {
                let on = Double.random(in: 0..<1, using: &rng) < p
                if on { filled += 1 }
                row.append(on)
            }
            grid.append(row)
        }
        guard filled >= size, filled <= size * size - size else { continue } // skip degenerate
        let clues = cluesForGrid(grid)
        guard isLineSolvable(clues.rowClues, clues.colClues) else { continue } // => unique + logic-solvable
        let adj = genAdjectives.randomElement(using: &rng) ?? "Quiet"
        let noun = genNouns.randomElement(using: &rng) ?? "Maze"
        let id = "g-" + String(UInt32.random(in: 0..<0xFFFFFFFF, using: &rng), radix: 36)
        return Puzzle(id: id, title: "\(adj) \(noun)", solution: grid,
                      difficulty: gradeGrid(grid), named: false)
    }
    return nil
}

/// Convenience using the system RNG (production).
public func generatePuzzle(size: Int) -> Puzzle? {
    var rng = SystemRandomNumberGenerator()
    return generatePuzzle(size: size, using: &rng)
}

/// "Good enough to send to the developer": not a trivial easy/blank board.
/// Every generated puzzle is already unique + logic-solvable; this gates only
/// on interestingness (medium+ difficulty or a structural badge).
public func isWorthSubmitting(_ puzzle: Puzzle) -> Bool {
    if puzzle.difficulty != .easy { return true }
    return !puzzleBadges(puzzle).isEmpty
}
```

- [ ] **Step 2 — Tests** (append to EngineTests.swift):

```swift
@Suite struct GeneratorTests {
    @Test func producesValidUniqueLogicSolvablePuzzles() {
        for size in [5, 7, 8, 10] {
            var rng = SeededGenerator(seed: UInt64(size) &* 1234567)
            let p = generatePuzzle(size: size, using: &rng)
            let puzzle = try! #require(p)
            #expect(puzzle.width == size && puzzle.height == size)
            #expect(puzzle.id.hasPrefix("g-"))
            #expect(!puzzle.named)                                   // generic title, no name-hint
            #expect(hasUniqueSolution(puzzle.rowClues, puzzle.colClues))
            #expect(isLogicSolvable(puzzle.rowClues, puzzle.colClues))
            #expect(gradeGrid(puzzle.solution) == puzzle.difficulty) // tier matches engine
            let filled = puzzle.solution.flatMap { $0 }.filter { $0 }.count
            #expect(filled >= size && filled <= size * size - size)  // not degenerate
        }
    }

    @Test func deterministicForASeed() {
        var a = SeededGenerator(seed: 42), b = SeededGenerator(seed: 42)
        #expect(generatePuzzle(size: 8, using: &a)?.solution == generatePuzzle(size: 8, using: &b)?.solution)
    }

    @Test func rejectsOutOfRangeSizes() {
        var rng = SeededGenerator(seed: 1)
        #expect(generatePuzzle(size: 4, using: &rng) == nil)
        #expect(generatePuzzle(size: 16, using: &rng) == nil)
    }

    @Test func submittableGate() {
        // an easy, badge-less board is not worth submitting; a medium one is.
        let easyPlain = Puzzle(id: "x", title: "x", solution: bitmapToGrid(["#....", ".....", ".....", ".....", "....#"]), difficulty: .easy)
        #expect(!isWorthSubmitting(easyPlain) || !puzzleBadges(easyPlain).isEmpty)
        var rng = SeededGenerator(seed: 7)
        // find a medium+ generated puzzle and confirm it is submittable
        for _ in 0..<20 { if let g = generatePuzzle(size: 8, using: &rng), g.difficulty != .easy { #expect(isWorthSubmitting(g)); break } }
    }
}
```

- [ ] **Step 3 — Verifier mirror** (append before "Library invariants" in main.swift):

```swift
print("Generator:")
var genRNG = SeededGenerator(seed: 99)
for size in [5, 7, 8, 10] {
    guard let g = generatePuzzle(size: size, using: &genRNG) else { check(false, "generated \(size)x\(size)"); continue }
    check(g.width == size && g.height == size, "\(size): correct size")
    check(hasUniqueSolution(g.rowClues, g.colClues), "\(size): generated puzzle is unique")
    check(isLogicSolvable(g.rowClues, g.colClues), "\(size): generated puzzle is logic-solvable")
    check(gradeGrid(g.solution) == g.difficulty, "\(size): generated tier matches engine")
    check(!g.named && g.id.hasPrefix("g-"), "\(size): generic untitled id")
}
var detRNG1 = SeededGenerator(seed: 5), detRNG2 = SeededGenerator(seed: 5)
check(generatePuzzle(size: 8, using: &detRNG1)?.solution == generatePuzzle(size: 8, using: &detRNG2)?.solution, "seeded generation is deterministic")
```

- [ ] **Step 4 — Run gates.** `cd ClueweaveKit && swift run clueweave-verify` → VERIFY OK; `swift test` → all pass.
- [ ] **Step 5 — Commit.** `feat(kit): puzzle generator (line-solvable => unique + logic-solvable), seeded RNG, submit gate`

---

## Task 2: `generatedPuzzles` persistence (engine, TDD)

**Files:** Modify `PlayerStore.swift`; mirror in verifier + tests.

- [ ] **Step 1 — SaveData.** Add `public var generatedPuzzles: [StoredPuzzle] = []`; add `generatedPuzzles` to the `CodingKeys`; in `init(from:)` decode element-tolerantly exactly like `userPuzzles`:

```swift
if let wrapped = try? c.decodeIfPresent([Failable<StoredPuzzle>].self, forKey: .generatedPuzzles) {
    generatedPuzzles = (wrapped ?? []).compactMap(\.value)
} else {
    generatedPuzzles = []
}
```

- [ ] **Step 2 — PlayerStore accessors** (mirror the userPuzzles API):

```swift
public var generatedPuzzles: [StoredPuzzle] { data.generatedPuzzles }

@discardableResult
public func saveGeneratedPuzzle(title: String, solution: [[Bool]]) -> String {
    if let existing = data.generatedPuzzles.first(where: { $0.solution == solution }) { return existing.id }
    let id = "g-\(UUID().uuidString.prefix(8))"
    var d = data
    d.generatedPuzzles.append(StoredPuzzle(id: id, title: title, solution: solution))
    data = d
    return id
}

public func deleteGeneratedPuzzles(ids: Set<String>) {
    var d = data
    d.generatedPuzzles.removeAll { ids.contains($0.id) }
    for id in ids { d.inProgress.removeValue(forKey: id) }
    data = d
}
```

- [ ] **Step 3 — Keep across reset.** In `resetProgress()`, do NOT clear `generatedPuzzles` (it is a creation, like userPuzzles — already untouched since we only reset records/completed/inProgress). Verify the reset method does not touch it.

- [ ] **Step 4 — Tests** (append `GeneratedStoreTests`): save returns a `g-` id, dedups identical solutions, `generatedPuzzles` survives `resetProgress()`, delete removes it and clears its in-progress, a v-prior save (no `generatedPuzzles` key) decodes to `[]`.

```swift
@Suite struct GeneratedStoreTests {
    @Test func saveDedupAndReset() {
        let s = PlayerStore(defaults: UserDefaults(suiteName: "t.gen.\(UUID().uuidString)")!)
        let art = bitmapToGrid(["##","#."])
        let id1 = s.saveGeneratedPuzzle(title: "A", solution: art)
        let id2 = s.saveGeneratedPuzzle(title: "B", solution: art)
        #expect(id1.hasPrefix("g-") && id1 == id2 && s.generatedPuzzles.count == 1)
        s.resetProgress()
        #expect(s.generatedPuzzles.count == 1)         // creations survive reset
        s.deleteGeneratedPuzzles(ids: [id1])
        #expect(s.generatedPuzzles.isEmpty)
    }
    @Test func olderSaveDecodesToEmpty() {
        let blob = #"{"userPuzzles":[]}"#
        let d = UserDefaults(suiteName: "t.gen2.\(UUID().uuidString)")!
        d.set(Data(blob.utf8), forKey: PlayerStore.storageKey)
        #expect(PlayerStore(defaults: d).generatedPuzzles.isEmpty)
    }
}
```

- [ ] **Step 5 — Verifier mirror** for save/dedup/reset/delete.
- [ ] **Step 6 — Gates + commit.** `feat(kit): generatedPuzzles collection on PlayerStore`

---

## Task 3: iOS routing + AppModel wiring

**Files:** Modify `Apps/iOS/Theme.swift`, `Apps/iOS/ClueweaveApp.swift`.

- [ ] **Step 1 — Routes.** In `Theme.swift` `enum Route`, add:

```swift
case generator                 // the generate screen
case playGenerated(String)     // a saved generated puzzle id
```

- [ ] **Step 2 — AppModel.** In `ClueweaveApp.swift`, add observable wrappers + extend lookup:

```swift
@discardableResult
func saveGenerated(title: String, solution: [[Bool]]) -> String {
    let id = store.saveGeneratedPuzzle(title: title, solution: solution); objectWillChange.send(); return id
}
func deleteGenerated(ids: Set<String>) { store.deleteGeneratedPuzzles(ids: ids); objectWillChange.send() }
```

In `anyPuzzle(withID:)` also check generated:

```swift
func anyPuzzle(withID id: String) -> Puzzle? {
    ClueweaveKit.puzzle(withID: id)
        ?? store.userPuzzles.first(where: { $0.id == id })?.asPuzzle
        ?? store.generatedPuzzles.first(where: { $0.id == id })?.asPuzzle
}
```

- [ ] **Step 3 — destination arms.** In `destination(for:)`:

```swift
case .generator:
    GeneratorView()
case .playGenerated(let id):
    if let stored = app.store.generatedPuzzles.first(where: { $0.id == id }) {
        PlayView(puzzle: stored.asPuzzle, isLibrary: false, store: app.store)
    }
```

- [ ] **Step 4 — Gate (build) + commit.** `feat(ios): routes + AppModel wiring for generated puzzles`

---

## Task 4: GeneratorView (iOS)

**Files:** Create `Apps/iOS/GeneratorView.swift`.

- [ ] **Step 1 — Implement** a screen: a size picker (5 / 7 / 8 / 10), a "Generate" button that runs `generatePuzzle(size:)` off the main actor (nonisolated async wrapper, like the editor's `analyzeGrid`) and shows a ProgressView while working; on success, preview the result with `BoardView` (interactive: false), a `DifficultyChip`, the badge chips (non-clickable, FlowLayout), and a row of actions: **Save** (→ `app.saveGenerated`, then navigate to `.playGenerated(id)`), **Share** (`ShareLink` with `webShareURL(forToken: encodePuzzle(...))`), **Send** (a mailto Link to the developer with the share URL, shown only when `isWorthSubmitting`), **Regenerate**. Match Theme. Use the same nonisolated-async pattern:

```swift
private nonisolated static func make(size: Int) async -> Puzzle? { generatePuzzle(size: size) }
```

Key state: `@State private var size = 8`, `@State private var puzzle: Puzzle?`, `@State private var working = false`. The Send mailto reuses `SuggestionMail`-style construction with the share URL in the body, subject "Clueweave generated puzzle".

- [ ] **Step 2 — Build gate + commit.** `feat(ios): GeneratorView — generate, preview, save, share, send`

---

## Task 5: Home — Generate entry + Generated section

**Files:** Modify `Apps/iOS/HomeView.swift`.

- [ ] **Step 1 — Entry point.** Add a "Generate a puzzle" capsule button next to "Create your own" / "Surprise me" → `NavigationLink(value: Route.generator)`.

- [ ] **Step 2 — Generated section.** After "My Puzzles", add a `@ViewBuilder var generatedPuzzlesSection`: if `app.store.generatedPuzzles` is non-empty, render a "Generated" section **grouped by difficulty** (`Difficulty.ordered`, only non-empty tiers, tier header = `DifficultyChip`), each puzzle a `PuzzleCard` (badges show, non-clickable per the existing design) inside a `NavigationLink(value: Route.playGenerated(stored.id))`, with a Manage/Delete affordance mirroring `myPuzzles` (reuse the same `managing`/`selectedCustoms` pattern but a separate `selectedGenerated` set and `app.deleteGenerated`). Each card also gets a context menu Delete.

- [ ] **Step 3 — Build gate + commit.** `feat(ios): Home — generate entry + difficulty-divided Generated section`

---

## Task 6: Play + share plumbing for generated

**Files:** Modify `Apps/iOS/PlayViewModel.swift`.

- [ ] **Step 1 — Persist in-progress.** `persistKey` currently allows library + `u-` custom ids. Extend so `g-` generated puzzles also resume:

```swift
self.persistKey = (isLibrary || puzzle.id.hasPrefix("u-") || puzzle.id.hasPrefix("g-")) ? puzzle.id : nil
```

- [ ] **Step 2 — Share URL.** `shareURL` already returns a token URL for non-library puzzles (`encodePuzzle`), which is correct for generated too — confirm no change needed. The "Watch solve" gate (`isLibrary || hasPrefix("u-")`) should also include `g-`:

```swift
if vm.isLibrary || vm.puzzle.id.hasPrefix("u-") || vm.puzzle.id.hasPrefix("g-") { ... }  // in PlayView (owned here? no — PlayView change)
```
(Note: that gate lives in `PlayView.swift`; include this one-line change there.)

- [ ] **Step 3 — Build gate + commit.** `feat(ios): resume + share generated puzzles in play`

---

## Task 7: Docs + final gates

**Files:** Modify `README.md`, `docs/AppStoreReadiness.md`.

- [ ] **Step 1 — README:** document the generator (provably unique, logic-solvable, graded, badged; Generated library; share + send).
- [ ] **Step 2 — Readiness:** note the generator keeps the "every puzzle solvable by logic, exactly one solution" guarantee, and that generated puzzles never carry the name-hint badge.
- [ ] **Step 3 — Full gates:** `swift run clueweave-verify` (CLT) → OK; `swift test` → pass; `xcodegen generate && xcodebuild build -scheme Clueweave -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED.
- [ ] **Step 4 — Commit + merge to main + push.**

---

## Self-review checklist (done)

- **Spec coverage:** generate ✓ (Task 1), Generated library like My Puzzles ✓ (Tasks 2/5), divided by difficulty ✓ (Task 5), badges = difficulty + symmetric + patterned ✓ (auto-detected; name-hint correctly excluded since `named:false`), shareable ✓ (Task 4/6), send-if-good ✓ (`isWorthSubmitting` + mailto, Task 1/4). Watch/website explicitly deferred.
- **Type consistency:** `generatePuzzle(size:using:)`, `saveGeneratedPuzzle(title:solution:)`, `deleteGeneratedPuzzles(ids:)`, `Route.playGenerated`, `app.saveGenerated`/`deleteGenerated`, `isWorthSubmitting` — names consistent across tasks.
- **No placeholders:** engine + store + tests carry full code; UI tasks carry the key code + exact reuse points.
