# Pixelogic for Apple platforms

Native Swift port of the [Pixelogic web game](https://website-and-game-maker.github.io/pixelogic/)
for **iPhone, iPad and Apple Watch**. Free, no ads, no accounts, fully offline.

## Layout

```
PixelogicKit/        SwiftPM package — the whole game engine (pure, UI-free)
  Sources/PixelogicKit/     solver, uniqueness prover, grader, badges, scoring,
                            hints, session model, persistence, web-compatible
                            share codec, 32-puzzle verified library, ad-readiness
  Sources/pixelogic-verify/ 273-check verifier that runs with bare CLT
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
cd PixelogicKit && swift run pixelogic-verify    # → VERIFY OK (273 checks)

# Apps: require full Xcode
brew install xcodegen
xcodegen generate
open Pixelogic.xcodeproj   # select the Pixelogic / PixelogicWatch schemes
```

## Guarantees (verified, not aspirational)

- Every puzzle has **exactly one solution** and is **solvable by pure logic**
  — proven by the engine at test time, same as the web app.
- Difficulty, badges, par times, penalties and the 0–1600 Pixelogic Score are
  **numerically identical** to the web implementation.
- Custom-puzzle share links are **byte-compatible** with the web app
  (a token minted on the phone opens in any browser and vice versa).
- **No data leaves the device.** No ads (a dormant, documented protocol exists
  for the future — `AdReadiness.swift` — with no reserved UI space).

## App Store description (draft)

> Deduce hidden pixel-art from number clues — pure logic, never a guess.
> Five difficulty tiers from Easy to MAX, explainable hints that tell you *why*
> a cell is certain, a 0–1600 Pixelogic Score that measures real mastery, and
> an editor that only lets you publish puzzles with exactly one solution.
> Free. No ads. No account. Works completely offline — even on Apple Watch.
