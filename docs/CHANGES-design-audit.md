# Clueweave — design-audit changes

This document records the changes made to `clueweave-apple` in response to the
design/standards audit. Everything here is iOS/watchOS Swift source plus a few
generated image assets — none of it could be compiled on the authoring machine,
so **give it a build pass in Xcode** before shipping. Where a number is
referenced (e.g. “#3”) it maps to the audit item.

> Scope note: the canonical web domain (#1) and the watch complications (#8)
> are being handled separately by the project owner and are **not** touched here.

---

## 1. Dark Mode (#2)

The app previously forced light mode (`.preferredColorScheme(.light)` in
`ClueweaveApp.swift`), which the comment justified as keeping system surfaces
(Form, sheets) coherent with the hand-tuned baby-blue palette.

**What changed**

- `Theme.swift` gained a `Color(lightHex:darkHex:)` initializer that resolves
  per-trait via `UIColor { traits in … }`. Every surface/ink/brand/board token
  is now light **and** dark adaptive. Dark variants are deep teal-charcoals so
  the brand turquoise still reads as the brand at night.
  - `primaryDeep` (the app tint *and* link color) is **brightened** in dark so
    it stays legible on dark surfaces.
  - The “soft” tint backgrounds (`accentSoft`, `symmetrySoft`) get dark variants,
    paired with adaptive text colors.
- `Theme.symmetryInk` was added so the play-screen symmetry strip’s text (which
  used a hard-coded hex) adapts instead of going low-contrast on dark.
- `ClueweaveApp.swift` — removed `.preferredColorScheme(.light)`; the app now
  follows the system appearance.
- `CreateViews.swift` — the editor verdict colors (unique green / not-unique
  amber) are now `Color(lightHex:darkHex:)` so they read on the dark canvas.

**Deliberately left fixed:** the difficulty and badge **chips** stay as fixed
pastel pills (light tint + dark text). They’re self-contained and read clearly
on either appearance, and keeping them constant preserves the tier color
language exactly.

## 2. Touch targets (#3)

- `PlayView.swift` — the previous/next puzzle arrows were ~35×35 pt (a 15 pt
  glyph + 10 pt padding). They’re now a **44×44 pt** hit target with an explicit
  `contentShape(Circle())`, meeting the HIG minimum.

## 3. “Built with AI” + support email (#4, #6)

The “no human author” framing is intentional and was **kept**. The audit’s only
real conflict — a personal Gmail receiving feedback while the app claims no
human — is resolved by labeling the address correctly.

- `SecondaryViews.swift`
  - `SuggestionMail.address` → **`pats-sire-06@icloud.com`** (a disposable
    mailbox), documented in code as the human *manager’s* address.
  - The About “Built entirely with AI” card now adds one clause: a human manager
    publishes the app and reads feedback at a disposable address but authored
    none of the game — so the claim and the contact are coherent.
  - The Settings “Feedback” footer and the About “Send a suggestion” card now
    describe the recipient as the project’s human manager at a disposable email.

## 4. Privacy policy → dedicated page (#5)

Previously the in-app “Privacy policy” link pointed at a web *About* anchor
(`…/#/about`), which is fragile (offline / wrong-domain) and weak for App Review
5.1.1(i).

- `SecondaryViews.swift` — new self-contained **`PrivacyView`** (a real policy:
  what’s collected = nothing, where data lives, sharing, children, contact,
  “Last updated”). It resolves offline and never depends on a web URL.
- `Theme.swift` — added `Route.privacy`; `ClueweaveApp.swift` routes it.
- Reachable from three places:
  - **Home footer** — a small, understated, website-style `Privacy Policy` link
    (plain system text, underlined, muted) at the very bottom. The redundant
    “About” footer link was **removed** (About is still in the toolbar).
  - **Settings → Privacy** — now an in-app `NavigationLink` to `PrivacyView`
    instead of the web link.
  - **About → “Your privacy”** card — links into the dedicated page.

> The matching **web** dedicated privacy page is still pending — the `clueweave`
> web folder detached mid-session, so `router.ts` / `menu.ts` couldn’t be read.

## 5. Watch board uses the brand palette (#7)

The watch board rendered with the generic system `.teal` / `.gray`, so a filled
cell didn’t match the phone/web turquoise.

- `WatchPalette.swift` — added a `Color(hex:)` helper and board tokens
  `cellFill` (brand `#23C2B1`), `cellCross` (`#9BB9BF`), `cellEmpty`.
- `WatchPlayView.swift` — the board’s filled cell, crossed-cell mark, the
  paint-mode toggle tint, and the win label now use those brand colors.

**Layout and interaction are unchanged** — only the colors were aligned. The
watch app remains standalone + embedded (no `project.yml` change), so its
Family Sharing eligibility is untouched.

## 6. MAX difficulty chip is a gradient (#10)

- `Theme.swift` — added `Theme.maxChipGradient` (`#2B2140 → #4A2D5E`).
- `DifficultyChip` now renders the **MAX** tier with that gradient (web parity);
  all other tiers keep their flat pastel pill.

## 7. Visibility: high-visibility mode + over-fill warning (#11)

Two aids, both in `BoardView.swift`:

- **High-visibility board** — a Settings → **Accessibility** toggle
  (`Toggle("High-visibility board")`). When on:
  - crosses are solid **black** and thicker (3 pt),
  - grid lines darken (minor → `lineMajor`, major → `ink @ 55%`),
  - unmet clue numbers render **black**.
  - Stored under `@AppStorage("clueweave.ios.highVisibility")`. Read by
    `PlayView`, `TutorialView`, and `ExplainerView`, passed into `BoardView`.
- **Over-fill warning** (always on, low-noise) — if a row or column holds **more
  filled cells than its clue total allows**, that line’s clue numbers turn
  **plum** (`Theme.overfill`, distinct from the red mistake cue). It signals
  “too many here” without touching the cells themselves.
- The **tutorial** (`CreateViews.swift`) final step now mentions all three
  states: crossing out empties, the plum “too many” clues, and the black
  high-visibility crosses.

> The over-fill color is intentionally *not* gated behind the toggle — it’s a
> calm, generally-useful aid. Easy to gate to high-visibility only if preferred.

## 8. Native delete on tiled cards (#12)

True swipe-to-delete is a `List` affordance; the My Puzzles / Generated grids are
`LazyVGrid` tiles, so the iOS-native equivalent is the **long-press context
menu** (haptic + blurred card preview).

- `HomeView.swift` — the custom and generated card context menus now lead with
  **Play**, then Edit (customs) / Share (generated), then a destructive
  **Delete**. The multi-select **Manage** mode is kept for bulk deletes.

## 9. Score laurel, tiered by score (#13 + new request)

The score laurel was a `Text("🌿")` glyph. It levels up with the Clueweave Score.

> **Superseded by the licensing pass.** This was briefly five PNG imagesets
> rasterized from the Apple emoji font. That art could not ship: Apple's font
> license does not permit redistributing the emoji artwork as bitmaps inside an
> app bundle, and it is a known App Store rejection. The imagesets
> (`Laurel{,Green,Bronze,Silver,Gold}.imageset`) have been **deleted**.

- The laurel is now the **SF Symbol** `laurel.leading` / `laurel.trailing` —
  shipped by the OS and licensed for in-app use — tinted and sized per tier.
  No bitmap ships, and the mirrored pair no longer needs `scaleEffect(x: -1)`.
- `HomeView.swift` — `laurelTier(for: score)` returns a `(tint, height)` pair.
  Tints come from `Theme`; `Theme.bronze` / `Theme.silver` were added because
  those tiers used to be encoded in the artwork itself. Thresholds unchanged:

  | Score | Tint | Height |
  |------:|------|-------:|
  | 0–29 | `Theme.primary` | 30 |
  | 30–119 | `Theme.primaryDeep` | 42 |
  | 120–349 | `Theme.bronze` | 50 |
  | 350–799 | `Theme.silver` | 58 |
  | 800–1600 | `Theme.gold` | 68 |

  The first upgrade at **30** arrives after only a little play, so the change is
  visible soon. (The laurel tier is independent of the `scoreTitle` word shown
  beside it; align the thresholds if you want them to flip in lockstep.)

---

## Files changed

```
Apps/iOS/Theme.swift            adaptive colors, symmetryInk, overfill,
                                maxChipGradient, gradient DifficultyChip,
                                Route.privacy
Apps/iOS/ClueweaveApp.swift     removed forced light mode; Route.privacy dest
Apps/iOS/PlayView.swift         44pt nav arrows; symmetry text token;
                                high-visibility passthrough
Apps/iOS/BoardView.swift        high-visibility mode; over-fill clue warning
Apps/iOS/HomeView.swift         tiered laurel symbol; native Play/Edit/Delete
                                context menus; understated privacy footer link
Apps/iOS/SecondaryViews.swift   PrivacyView; email + AI/manager copy;
                                Accessibility toggle; Settings privacy link;
                                Explainer high-visibility passthrough
Apps/iOS/CreateViews.swift      dark-mode verdict colors; tutorial copy;
                                tutorial high-visibility passthrough
Apps/Watch/WatchPalette.swift   Color(hex:) + brand board tokens
Apps/Watch/WatchPlayView.swift  board uses brand palette
Apps/iOS/Assets.xcassets/  (laurel imagesets removed — SF Symbol instead)
```

## New persistence keys

- `clueweave.ios.highVisibility` (`@AppStorage`, default `false`).

## Still open / handoff

- **Web dedicated privacy page (#5, web side)** — needs the `clueweave` web
  folder reattached to read `router.ts` / `menu.ts` and wire a `#/privacy` view
  + footer link to match the phone.
- **Build pass** — compile in Xcode; run the iPhone/iPad/Watch schemes.
- The laurel is now the SF Symbol `laurel.leading`/`laurel.trailing`, tinted per
  tier (see §9). If you want a bespoke wreath, swap the `Image(systemName:)`
  calls in `HomeView.swift` — but do **not** reintroduce rasterized emoji art.
