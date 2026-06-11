# App Store readiness audit — Pixelogic

Audited against Apple's **App Review Guidelines** (fetched 2026-06-11 from
developer.apple.com/app-store/review/guidelines) as a reviewer would, plus the
required-reason API rules. Each item cites the guideline.

## Compliance matrix

| Guideline | Requirement | Status |
|---|---|---|
| **2.1 Completeness** | Final build, tested on-device, no placeholders | ◐ Engine verified on this machine (247+26 checks, `swift run pixelogic-verify`). UI must be run once in Xcode + simulators before submission (no Xcode on the build machine — see "Remaining human steps"). No placeholder content anywhere. |
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

## Remaining human steps (cannot be done on this machine — no Xcode/simulators)

1. `brew install xcodegen && xcodegen generate` → open `Pixelogic.xcodeproj`.
2. Set your Apple Developer team; build & run on iPhone, iPad and Watch
   simulators; run the `PixelogicKitTests` suite (Swift Testing) in Xcode.
3. Drop `Support/AppIcon-1024.png` into the generated asset catalogs
   (Xcode auto-scales single-size icons for iOS and watchOS).
4. Take App Store screenshots (6.7", 13", and watch sizes) of real gameplay (2.3.3).
5. In App Store Connect: price **Free**, no IAP, age 4+, category Puzzle,
   privacy "Data not collected", privacy-policy URL, enable Family Sharing
   (automatic for free apps).
