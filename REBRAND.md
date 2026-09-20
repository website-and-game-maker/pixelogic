# Rebrand: Pixelogic → Clueweave

A licensing/IP pass. The game, engine, levels, and mechanics are unchanged except
where noted. **No levels were removed.** The color scheme was deliberately left
alone (a separate pass owns it), with one unavoidable exception noted below.

## 1. Name

`Pixelogic` → **`Clueweave`**, everywhere: UI copy, package/module names, bundle
identifiers, URL scheme, storage keys, docs, and social metadata.

Why it had to change: the old name collides with **Pixologic, Inc.** (ZBrush,
now Maxon) and **Pixelogic Media Partners, LLC**, and with existing nonogram
apps of the same name.

| Surface | Before | After |
|---|---|---|
| iOS/watch bundle | `com.pixelogic.app` | `com.clueweave.app` |
| URL scheme | `pixelogic://` | `clueweave://` |
| Swift module | `PixelogicKit` | `ClueweaveKit` |
| Verifier target | `pixelogic-verify` | `clueweave-verify` |
| Xcode project | `Pixelogic.xcodeproj` | `Clueweave.xcodeproj` |
| Web base path | `/pixelogic/` | `/clueweave/` |
| Save key | `pixelogic.save.v1` | `clueweave.save.v1` |
| Score name | "Pixelogic Score" | "Clueweave Score" |

**Player data is preserved.** Renaming the storage keys would have silently wiped
progress, so each platform adopts its old key once and then retires it:
`persistence.ts` (`readRaw`), `PlayerStore.swift` (`readRaw`), plus the loose
`@AppStorage` prefs in `ClueweaveApp.swift` and `ClueweaveWatchApp.swift`.
Covered by two new tests in `tests/persistence.test.ts`.

## 2. "Picross" removed

`Picross` is a live **Nintendo** trademark and was used in the package
description, README, project guide, the About screen, and the iOS help text.
All replaced with **nonogram**, the generic (unownable) term for the genre.
`griddler` was dropped from the design spec for the same reason.

## 3. Rasterized Apple emoji removed

The five `Laurel*.imageset` PNGs were rasterized from the **Apple Color Emoji**
font — the repo's own audit note said so. Apple's font license does not permit
redistributing that artwork as bitmaps in an app bundle, and it is a known App
Store rejection.

- Deleted all five imagesets.
- The laurel is now the **SF Symbol** `laurel.leading`/`laurel.trailing`, which
  Apple licenses for in-app use, tinted and sized per tier.
- `scripts/make-og.mjs` screenshotted a 🌿 glyph straight into the shipped
  `public/og-image.png`; it now draws a plain SVG sprig. Image regenerated.

**This is the one place color had to move.** The bronze/silver tiers used to be
encoded *inside* the artwork, so `Theme.bronze` and `Theme.silver` were added as
**placeholders** — fold them into the palette during the color pass.

Emoji used as ordinary *text* at runtime (🧠, 🎯, ▦ …) is untouched and fine —
that is the system font rendering, not redistribution.

## 4. Two puzzles redrawn (none deleted)

Two bitmaps read as other companies' characters:

- **Ghost** — dome + two eye notches + flat scalloped hem: a Pac-Man ghost
  (Bandai Namco). Redrawn as a drifting wisp with a trailing tail.
- **Mushroom** — wide spotted cap on a squat stem: a Super Mario power-up
  (Nintendo). Redrawn as a woodland toadstool with gills and a ringed stem.

Both keep their `id`, title, and place in the library, so share links, save data,
and progression order are unaffected. Both were re-proved rather than asserted —
`hasUniqueSolution` + `isLogicSolvable` pass, and each tier is **the grader's own
verdict, not a forced value**. The two engines agree:

| Puzzle | Unique | Logic-solvable | Web tier | Swift tier |
|---|---|---|---|---|
| Ghost | ✅ | ✅ | `hard` | `hard` |
| Mushroom | ✅ | ✅ | `hard` | `hard` |

Two knock-on effects, both derived by the engine rather than chosen:

- Ghost grades harder than its old art did, so it moved into the Swift **Hard**
  block to keep the array grouped by tier (curriculum order is tier-major with
  stable within-tier ordering, so the move keeps the two platforms aligned).
- Mushroom's old art was H-symmetric; the new art is not, so it loses the
  **Symmetric** badge and its score weight goes `0.765 → 0.9`. It now counts
  slightly more toward the 1600. Nothing else in the library shifts.

## 5. Left alone, deliberately

- **Levels** — nothing deleted; only the two bitmaps above changed.
- **Color scheme** — untouched apart from §3.
- **App icon** — a generic nonogram grid; no IP concern.
- **Nunito** — SIL Open Font License, fine to ship.
- **SF Symbols** — licensed for in-app use.
- **Claude / Anthropic credit** in the About screen — truthful nominative use,
  and removing it would make the page false.
