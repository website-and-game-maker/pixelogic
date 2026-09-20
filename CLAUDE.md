# Clueweave — project guide

Native Swift port of the [Clueweave web game](https://website-and-game-maker.github.io/clueweave/)
for iPhone, iPad, and Apple Watch. Free, offline, no ads, no accounts.

## Surfaces (where code lives)

| Surface | Path | Notes |
|---|---|---|
| **Engine** | `ClueweaveKit/Sources/ClueweaveKit` | Pure, UI-free, `Sendable`, deterministic. **Shared by iOS and watch.** Solver, uniqueness prover, grader, badges, scoring, hints, generator, share codec, `PlayerStore`. |
| **Verifier** | `ClueweaveKit/Sources/clueweave-verify` | Framework-free mirror of the test suite — runs with bare Command Line Tools (`swift run clueweave-verify`). |
| **Engine tests** | `ClueweaveKit/Tests/ClueweaveKitTests` | Swift Testing; same checks as the verifier, runs under the Xcode toolchain. |
| **iOS app** | `Apps/iOS` | SwiftUI iPhone + iPad. Uses `PlayerStore` (UserDefaults) via `AppModel`. |
| **Watch app** | `Apps/Watch` | watchOS, its own UI + **watch-local `@AppStorage`** state (no `PlayerStore`, no sync). |
| **Website** | **separate repo** (`website-and-game-maker/clueweave`, not in this checkout) | JS port of the same engine. Share codec + scoring must stay byte/numerically identical. |

`project.yml` (XcodeGen) defines the iOS + watch targets; the watch app is embedded in
the iOS app (one App Store record). `xcodegen generate` writes `Clueweave.xcodeproj` and
`Support/Info-*.plist` (both git-ignored).

## Feature-addition protocol (multi-app)

Adding a feature usually touches several surfaces. Follow these steps **in order** —
each gate must pass before the next.

1. **Pick the layer.** Anything that is pure logic (rules, math, generation,
   detection, persistence shape) goes in **ClueweaveKit** so every surface shares one
   implementation. UI is per-app. Never duplicate engine logic into an app.

2. **Engine first, test-driven.** Add the logic to ClueweaveKit. For every new
   behavior add **both**:
   - a Swift Testing test in `Tests/ClueweaveKitTests/`, and
   - a mirrored check in `Sources/clueweave-verify/main.swift` (so it runs with bare CLT).

   Keep functions `public` only where an app needs them, and `Sendable`. Run the
   verifier (Build gates) — it must stay green.

3. **Persistence (if any).** Add fields to `SaveData` with a default value, register
   them in `CodingKeys`, and decode them tolerantly through the existing `field(...)`
   helper (and `Failable` for element-level tolerance). **Never** let one bad field
   wipe a save. Collections the player created (`userPuzzles`, `generatedPuzzles`)
   must survive `resetProgress()`. Add matching accessors on `PlayerStore`.

4. **iOS UI.** Add a `Route` case + a `destination(for:)` arm in `ClueweaveApp`.
   Reuse `PlayView`/`BoardView`/`PuzzleCard`/`Theme`. Show badges with
   `puzzleBadges(...)` + `BadgeKey`. Wrap any chip rows in `FlowLayout` so they don't
   clip on small screens. `PlayerStore` is **not** observable — route every store
   mutation through `AppModel` (which calls `objectWillChange.send()`).

5. **Watch UI (only if the feature belongs on the wrist).** Mirror in `Apps/Watch`
   with watch-local `@AppStorage`. **watchOS 9.0 APIs only** — no `Material`/
   `.ultraThinMaterial`, no `.scrollBounceBehavior`, no `.topBarTrailing`
   (use `.primaryAction`). If it is a play surface, drive `GameSession` and pause the
   timer on `scenePhase != .active`.

6. **Sharing / web parity.** Reuse `ShareCodec` (`encodePuzzle`/`decodePuzzle`/
   `shareToken`/`webShareURL`). Any change to the token format, scoring, par times,
   penalties, badge thresholds, or difficulty cutoffs **must** stay byte- and
   numerically identical to the web engine — verify against the live web bundle.

7. **Build gates (all green before merge).**
   ```bash
   # Engine — works with bare Command Line Tools:
   cd ClueweaveKit && swift run clueweave-verify          # -> VERIFY OK
   swift test                                             # Swift Testing (needs Xcode toolchain)
   # Apps — needs full Xcode + simulator runtimes:
   xcodegen generate
   xcodebuild build -project Clueweave.xcodeproj -scheme Clueweave \
     -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO   # iOS + embedded watch
   ```
   If the Xcode license is unaccepted, run engine commands with
   `DEVELOPER_DIR=/Library/Developer/CommandLineTools` and a private `--scratch-path`.
   App targets can be type-checked against the simulator SDK with `swiftc -typecheck`
   when a full build isn't available.

8. **Branch & integrate.** One worktree/branch per feature. Commit any **shared engine
   foundation first** so parallel UI work branches from it. If you parallelize agents,
   give each a **disjoint set of files** (no two touch the same file). Merge to `main`
   and push. Update `README.md`, `docs/AppStoreReadiness.md`, and the verifier's
   library/count checks when relevant.

## Guarantees the engine must keep (verified, not aspirational)

- Every shipped/generated puzzle has **exactly one solution** and is **solvable by
  pure logic** (`hasUniqueSolution` + `isLogicSolvable`). Generators and the editor
  must enforce this before a puzzle is playable or shareable.
- Difficulty, badges, par times, penalties, and the 0-1600 Clueweave Score are
  numerically identical to the web implementation.
- Share tokens are byte-compatible with the web app.
- No data leaves the device.

## Authorship

The entire project - concept, engine, art, tests, and docs - was created by Claude
(Anthropic's AI) in Claude Code. There is no human author. Keep the About screens
consistent with this.
