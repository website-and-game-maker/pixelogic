# Pixelogic for Apple Watch — design rationale

The Watch app is **not** a shrunken phone app. It was redesigned around three
hard constraints of the wrist: a ~40–45 mm screen, fingertip-sized touch
targets, and 5–15 second interaction bursts.

## What changed, and why

| Decision | Rationale |
|---|---|
| **"Pocket set" only: the eight 5×5 puzzles** | 5×5 cells on a 45 mm screen are ≈ 7 mm — right at Apple's minimum touch-target size. 10×10 would be 3.5 mm: unusable. Rather than zooming/panning (fiddly, loses the "whole puzzle at a glance" property that makes nonograms fun), the Watch gets a curated set sized for the medium. |
| **One mode toggle, giant cells** | The phone's assist toolbar (hint/check/fill-out) is cut entirely. On the wrist you play in short bursts; assists are a desk activity. Paint/Cross is a single bottom toggle with haptic feedback. |
| **Digital Crown steps through puzzles** | List navigation without occluding the tiny screen with fingers. |
| **No timer pressure, no scores** | Watch play is casual/ambient. Completion ticks (and a wrist-sized celebration) replace the scoring system; the Pixelogic Score remains a phone/web concern. The platforms share the *game*, not the grind. |
| **No editor, no About, no sharing** | Text entry and long-form reading are anti-patterns on watchOS. |
| **Same engine, same guarantee** | PixelogicKit runs identically — every wrist puzzle is provably unique and logic-solvable. The clue rails render exactly like the big apps so knowledge transfers. |

## Interaction model

- **Tap** a cell → applies the current mode (paint/cross), with `.click` haptic.
- **Mode toggle** pinned at the bottom; large, high-contrast.
- **Crown** on the home list scrolls puzzles; complication-style completion rings show progress.
- **Win**: full-screen reveal of the picture + its name + a success haptic; tap to return.

Family Sharing / standalone: the Watch app is fully standalone (no phone
required, no connectivity) — the engine and puzzles ship in the binary.
