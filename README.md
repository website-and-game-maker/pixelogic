# Clueweave for Apple platforms

Native Swift port of the [Clueweave web game](https://website-and-game-maker.github.io/clueweave/)
for **iPhone, iPad and Apple Watch**. Free, no ads, no accounts, fully offline.

## Layout

```
ClueweaveKit/        SwiftPM package — the whole game engine (pure, UI-free)
  Sources/ClueweaveKit/     solver, uniqueness prover, grader, badges, scoring,
                            hints, session model, persistence, web-compatible
                            share codec, 32-puzzle verified library, ad-readiness
  Sources/clueweave-verify/ 300-check verifier that runs with bare CLT
  Tests/                    the same checks as Swift Testing suites (Xcode)
Apps/iOS/            SwiftUI app for iPhone + iPad (web look, translated)
Apps/Watch/          watchOS app — redesigned for the wrist (see DESIGN.md)
Support/             Privacy manifest, app icon, Info.plist sources
docs/                App Store readiness audit
project.yml          XcodeGen definition (iOS + watchOS targets)
```

## Build & verify

```bash
# Engine: builds and verifies with Command Line Tools alone
cd ClueweaveKit && swift run clueweave-verify    # → VERIFY OK (300 checks)

# Apps: require full Xcode
brew install xcodegen
xcodegen generate
open Clueweave.xcodeproj   # select the Clueweave / ClueweaveWatch schemes
```

## Guarantees (verified, not aspirational)

- Every puzzle has **exactly one solution** and is **solvable by pure logic**
  — proven by the engine at test time, same as the web app.
- Difficulty, badges, par times, penalties and the 0–1600 Clueweave Score are
  **numerically identical** to the web implementation.
- Custom-puzzle share links are **byte-compatible** with the web app.
  A token minted on the phone opens in any browser; a web link travels back
  into the app via paste-import (Home → "Import a puzzle") or a
  `clueweave://p/<token>` link.
- **Quitting never loses a board.** In-progress attempts (marks, clock,
  penalties) persist per puzzle and resume exactly; the clock pauses whenever
  the app leaves the foreground.
- **Generate your own.** The generator (Home → "Generate a puzzle") makes
  brand-new boards that are **provably unique and solvable by pure logic** — it
  keeps only line-solvable grids, so the core promise holds for free. Generated
  puzzles land in a **Generated** library divided by their graded difficulty,
  carry symmetric/patterned badges (never name-hint), can be shared by link, and
  the good ones (Medium+ or badged) can be sent to the developer.
- **No data leaves the device.** No ads (a dormant, documented protocol exists
  for the future — `AdReadiness.swift` — with no reserved UI space).

## App Store description (draft)

> Deduce hidden pixel-art from number clues — pure logic, never a guess.
> Five difficulty tiers from Easy to MAX, explainable hints that tell you *why*
> a cell is certain, a 0–1600 Clueweave Score that measures real mastery, and
> an editor that only lets you publish puzzles with exactly one solution.
> Free. No ads. No account. Works completely offline — even on Apple Watch.
