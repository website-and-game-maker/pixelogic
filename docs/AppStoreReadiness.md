# App Store readiness audit — Pixelogic

Audited against Apple's **App Review Guidelines** (fetched 2026-06-11 from
developer.apple.com/app-store/review/guidelines) as a reviewer would, plus the
required-reason API rules. Each item cites the guideline.

## Compliance matrix

| Guideline | Requirement | Status |
|---|---|---|
| **2.1 Completeness** | Final build, tested on-device, no placeholders | ◐ Engine verified on this machine (300 checks, `swift run pixelogic-verify`). UI must be run once in Xcode + simulators before submission (no Xcode on the build machine — see "Remaining human steps"). No placeholder content anywhere. |
| **2.3 Accurate metadata** | Screenshots of real gameplay, honest description | ☐ Take screenshots in the simulator at submission time (home, play, win, editor, watch). Description draft in README. |
| **2.3.6 / 2.3.8 Age rating** | Honest rating, 4+-appropriate metadata | ✓ Pure logic puzzles, no objectionable content → 4+. |
| **2.4.2 Power** | No battery drain / heat | ✓ No background work, no timers beyond a 0.5 s UI tick during active play, no network. Canvas redraws only on state change. |
| **2.5.16 / watchOS** | Watch app self-contained | ✓ Standalone `WKApplication`; engine + puzzles ship in the binary; no phone dependency. |
| **4.1 Copycats** | Original work | ✓ Original puzzle art, original scoring system (Pixelogic Score), original engine. Nonograms as a genre are public domain. |
| **4.2 Minimum functionality** | Beyond a repackaged website | ✓ Fully native SwiftUI; offline; haptics on watch; share sheets; no web views at all. |
| **4.3 Spam/quality** | "Meaningfully different or improved" | ✓ Uniqueness-proving engine, explainable hints, score system, editor — differentiators documented in the About screen. |
| **5.1.1(i) Privacy policy** | Link in metadata AND in-app | ✓ In-app: Settings → Privacy + About → "Your privacy". For App Store Connect, use the same URL (the game's About page) or a dedicated page. |
| **5.1.1(ii–v)** | Consent, no forced login | ✓ Collects literally nothing; no accounts (5.1.1(v) satisfied by design); zero permission prompts. |
| **Privacy manifest** | `PrivacyInfo.xcprivacy` with required-reason APIs | ✓ Included; declares UserDefaults (CA92.1), no tracking, no collected data types. |
| **Export compliance** | Encryption declaration | ✓ `ITSAppUsesNonExemptEncryption = false` (no custom crypto). |
| **Ads** | — | ✓ None. The `AdReadiness.swift` protocol is dormant design documentation; no SDK, no placements render, verified by tests ("no placement has an ad"). Kids-Category compatible if ever desired. |
| **HIG** | Platform-appropriate design | ✓ iOS: NavigationStack, Form-based settings, ShareLink, context menus, SF Symbols, Dynamic-Type-friendly rounded text styles, accessibility labels on all interactive elements. watchOS: redesigned for the wrist (see Apps/Watch/DESIGN.md), ≥7 mm targets, haptics. |

## Issues found during this audit (all fixed)

1. `ToolbarItem(placement: .topBarTrailing)` is iOS 17+; replaced with
   `.navigationBarTrailing` (deployment target is iOS 16).
2. `TutorialView` had a self-referential property initializer
   (`let puzzle = puzzle(withID:)`) that cannot compile; now fully qualified.
3. `navigationBarTitleDisplayMode` does not exist on watchOS; removed.
4. Drag strokes painted with the current mode even when the stroke's first tap
   erased — strokes now carry their first cell's value (web parity).
5. No in-app privacy policy link (5.1.1(i)); added in Settings and About.
6. "Share score" used a malformed URL; now shares the game's home page.

## Issues found in the second audit (2026-06-12, all fixed)

7. Sharing a solved **custom** puzzle built a dead web link
   (`#/play/<local-id>`); it now shares the encoded-token URL, so the link
   actually opens the puzzle anywhere.
8. There was **no way to receive a shared puzzle** (`decodePuzzle` was dead
   code): added a `pixelogic://` URL scheme + `onOpenURL`, and a paste-import
   sheet on Home that accepts the web link, the app link, or a bare token —
   with junk-input handling and duplicate-import dedupe.
9. Deleting a custom puzzle from its context menu didn't refresh the Home
   grid (PlayerStore isn't observable); deletes now route through the
   observable app model.
10. Quitting (or being killed in the background) lost the whole board:
    in-progress attempts (marks + clock + assists) now persist per puzzle and
    restore on return; the timer pauses on scene background — this also makes
    the previously dormant assist-ledger concept real.
11. The play clock ran on wall time while the app was suspended, destroying
    scores; scenePhase now pauses/resumes the session.
12. "Watch solve" on a custom puzzle pushed a **blank screen** (route only
    resolved library ids); the route now resolves customs, and the button
    hides for unsaved editor drafts. Voiding also no longer depends on a
    `simultaneousGesture` race.
13. The editor promised "tap **or drag** to draw" but only toggled the cell
    where the finger lifted; drag now paints, with the stroke's first cell
    deciding paint-vs-erase.
14. Editor test-plays hardcoded difficulty Easy (wrong check budget/par);
    they now use the engine's real grade.
15. Editor analysis ran via `Task.detached` capturing the non-Sendable view —
    a Swift 6 strict-concurrency compile error; rewritten as a nonisolated
    async helper.
16. A corrupt save silently wiped progress; it's now stashed under a
    `.corrupt` key and the save format decodes field-by-field, so saves from
    any app version load losslessly (verified against a v1 blob).
17. Watch board sized the column-clue rail from **row**-clue counts (latent
    clipping); rails are now independent.
18. App icons weren't wired into any target (upload would fail validation):
    single-size 1024 asset catalogs added for iOS and watchOS.
19. The watch target wasn't embedded in the iOS app — two separate App Store
    records would have been needed; it's now an embedded dependency with
    `WKCompanionAppBundleIdentifier` + `WKRunsIndependentlyOfCompanionApp`.
20. iPad multi-scene was implicitly enabled while the save store is
    last-write-wins whole-blob; multiple scenes are now declared off.
21. Hard-coded light branding clashed with dark-mode system surfaces (Form,
    TextField); the app now declares a light appearance coherently.

## Issues found in the third pass (2026-06-13, all fixed)

22. **Imported puzzles bypassed the uniqueness guarantee.** A share token can
    encode *any* grid; the editor refuses to save a non-unique puzzle, but the
    new import paths didn't re-check. A multi-solution imported board is
    unwinnable here (`GameSession.isSolved` compares to the one stored picture)
    and mistake-check would paint a player's *valid* cells red. Both import
    paths (URL and paste) now run the same exactly-one-solution gate the editor
    uses (`validateSharedSolution`, off the main thread) and refuse non-unique
    tokens with a clear message. This also makes BoardView's mistake-check
    sound for every playable puzzle.
23. A single corrupt custom-puzzle entry in the save blob would have dropped
    the player's **entire** collection (the round-1 field-level decode caught
    most corruption but still decoded `userPuzzles` as one array). It now
    decodes element by element — a bad entry is skipped, the rest survive.
24. A deep link arriving during the first-launch tutorial cover would queue
    the puzzle behind it; the tutorial is now dismissed when a link opens.
25. A bad or non-unique `pixelogic://` link used to no-op silently; it now
    shows an explanatory alert.
26. De-risked an `if`-expression in the editor (`drawnPuzzle`) into plain
    statements — the app targets can't be compiled on this machine, so exotic
    expression syntax was replaced with the unambiguous statement form.

## Remaining human steps (cannot be done on this machine — no Xcode/simulators)

1. `brew install xcodegen && xcodegen generate` → open `Pixelogic.xcodeproj`.
2. Set your Apple Developer team; build & run on iPhone, iPad and Watch
   simulators; run the `PixelogicKitTests` suite (Swift Testing) in Xcode.
3. ~~Drop the app icon into asset catalogs~~ — done in-repo
   (`Apps/*/Assets.xcassets`, single-size 1024, Xcode auto-scales).
4. Take App Store screenshots (6.7", 13", and watch sizes) of real gameplay (2.3.3).
5. In App Store Connect: price **Free**, no IAP, age 4+, category Puzzle,
   privacy "Data not collected", privacy-policy URL, enable Family Sharing
   (automatic for free apps).
