# Widgets, complications and the Live Activity

How Clueweave gets onto a Home Screen, a watch face and the Lock Screen — and
the constraints that shaped each decision.

> **Build status:** every file described here was written on a machine with no
> Swift toolchain and **has not been compiled**. The pure engine pieces
> (`WidgetSnapshot`, `DeepLink`, `LiveActivity`, `AppGroup`, the `PlayerStore`
> migration) are covered by the verifier and the test suite, so they can be
> checked the moment a toolchain is available: `swift run clueweave-verify`.
> The WidgetKit/ActivityKit UI has no such cover and needs a real
> `xcodebuild` before anyone claims it works.

## The four constraints

1. **Widgets are a separate process.** A widget extension has its own
   `UserDefaults.standard` and cannot see the app's. Everything shared moves
   into the App Group `group.com.clueweave.app`.
2. **Accessory families get one tap target.** On a watch face (and in the Lock
   Screen accessory slots) `Link` does nothing — only `widgetURL` is honoured. A
   complication may *show* three things and can only *go* one place.
3. **The watch app keeps no `PlayerStore`.** It is standalone by design
   (`progression-model.md` §9): completion only, no scores, no sync. Its
   complications therefore read a snapshot the **watch** builds from its own
   data, not the phone's.
4. **Live Activities cannot be authored on watchOS.** watchOS 11+ mirrors the
   iPhone's activity automatically. There is no watch-side ActivityKit code in
   this repo and there cannot be.

## The snapshot

Widgets never decode `SaveData` — it carries every player-created grid, and a
complication refreshes on the system's schedule, not ours. The apps distil their
state into `WidgetSnapshot` and write it to the App Group; the extensions read
only that.

It is deliberately **self-sufficient**: the continue entry carries its own title
and board, which is what lets a Continue widget draw a *custom* puzzle the
extension has never heard of.

| Field | Meaning |
|---|---|
| `score` | 0–1600 Clueweave Score. `nil` on the watch, which keeps no scores. |
| `solved` / `total` | Library completion. |
| `workingTier` | Where the progression model currently has you. |
| `tiers` | Per-difficulty counts + `tierSuggestion` for that tier. |
| `continueEntry` | The most recently saved unfinished board, with its marks. |
| `recommendation` | `recommend()`, excluding the board you're already on. |

Decoding is **field-by-field**, like `SaveData`: a snapshot from a newer app
must render on an older widget rather than blanking the face.

### The progress metric

The ring is **correctly filled cells ÷ cells the finished picture fills**, not
"cells marked either way". Crossing is optional, so the obvious metric would
show a player who never crosses at ~40% on a solved board. This one reaches
exactly 1.0 when the puzzle is solved, and a wrong fill simply doesn't count.

### `tierSuggestion`

What a per-difficulty widget offers: **first unsolved in curriculum order**
within the tier; once the tier is finished, the puzzle with **the most score
left to win**. That second branch reuses `recommend()`'s own gain formula
(`(100 − best) × tier weight × badge multiplier`), so the two can never
disagree about what "worth replaying" means.

## Deep links

One parser (`parseClueweaveLink`) shared by both apps and both widget bundles,
so a complication cannot build a URL the app doesn't understand.

| Link | Lands on |
|---|---|
| `clueweave://home` | the menu |
| `clueweave://tier/<raw>` | that difficulty's screen (`TierView` / `WatchTierListView`) |
| `clueweave://resume/<id>` | the saved attempt — **menu if it's gone** |
| `clueweave://puzzle/<id>` | that puzzle |
| `clueweave://recommended` | whatever `recommend()` picks now |
| `clueweave://p/<token>` | the pre-existing shared-puzzle import |

`resume` and `puzzle` reach the same screen. They are separate cases because a
stale Continue complication must not silently start a fresh board nobody asked
to restart — `resume` checks the attempt still exists and falls back to the
menu, `puzzle` does not.

Tier links use the **raw value** (`expert`), never the display name — "Extra
Hard" would not survive a URL.

## What each surface shows

### iOS — `Apps/Widgets`

| Widget | Families | Tap |
|---|---|---|
| **Continue** | small, medium, circular, rectangular, inline | the unfinished board |
| **Difficulty** | small, medium, circular, rectangular, inline | that tier (medium also links the suggestion separately) |
| **Progress** | medium, large | each tier row links to its own tier |

Only **Progress** has several tap targets, because only medium and large
support `Link` at all. The Difficulty widget's *configuration* is an
`AppIntent`, so it is one gallery entry that can be stacked twice (Hard and
Extra Hard) instead of five near-identical entries.

### watchOS — `Apps/WatchComplications`

| Complication | Families | Tap |
|---|---|---|
| **Clueweave** (launcher) | circular, corner, inline | `primaryLink` |
| **Continue** | circular, corner, rectangular, inline | the unfinished board |
| **Difficulty** | circular, corner, rectangular, inline | that tier |

The launcher is **not** hard-wired to `home`: if there is an unfinished board,
opening the menu just makes you find it again. `WidgetSnapshot.primaryLink`
walks board → recommendation → home.

**The rectangular fallback is "continue, else the recommendation"** — never a
blank slot and never a bare "open the app". Rectangular is the only accessory
family with room for real content; leaving it empty wastes the most valuable
slot on the face.

### Live Activity — `Apps/Widgets/ClueweaveLiveActivity.swift`

Lock Screen, Dynamic Island (compact, minimal and expanded), and the `.small`
activity family, which is what the paired watch mirrors.

The clock is a `Text(timerInterval:)` anchored in the past by the banked time,
so it keeps counting while the app is suspended *and* a resumed attempt shows
its true total rather than restarting from zero. A **paused** attempt has no
`timerStart` and shows a frozen number: a Live Activity cannot tick a paused
clock, and a clock that runs while the game is paused is worse than one that
stops.

It starts on the **first real mark**, not when the play screen appears —
opening a puzzle to look at it should not put a card on someone's Lock Screen.
It ends on solve (lingering 20s so the win is visible), on give-up, on restart,
and on leaving the screen. Backgrounding does *not* end it; that is the case it
exists for. Updates are throttled to one every 2 s, because ActivityKit budgets
them and a nonogram is dozens of marks a minute.

Player switch: `clueweave.ios.liveActivity`, an iOS-local `@AppStorage` like
`highVisibility`. It is **not** in `GameSettings` — that shape is a
cross-platform contract, and Live Activities are an iOS-only surface.

## Migrations

Two stack, and they must run in this order — see `PlayerStore.readRaw`:

1. **Rebrand:** `pixelogic.save.v1` → `clueweave.save.v1`.
2. **App Group:** app-local `UserDefaults.standard` → the shared suite.

A player upgrading straight from a pre-rebrand build hits both, which is why
the fallback stores are searched under *both* keys. A save already in the
shared suite always wins — migration must never overwrite newer progress.
The watch gained one new wrist-local key, `clueweave.watch.attempt`; it is
additive and has no legacy form.

## When the snapshot is republished

Publishing encodes JSON, so it happens at checkpoints, never per touch:

- a solve, a board being put down, the app backgrounding (`persistNow`);
- restart, import, custom/generated deletion, progress reset;
- once per launch, so a face added while the app was closed fills in.

Each publish is followed by `WidgetCenter.reloadAllTimelines()`. Reloading
without publishing just re-renders stale data, so the two always go together —
which is why they live in one method (`PlayerStore.refreshWidgets()` on iOS,
`WatchProgress.publishSnapshot()` on the watch).

## Deployment targets

The widget extensions sit **above** their host apps: iOS 18 and watchOS 11,
against the apps' iOS 16 / watchOS 9. `AppIntentConfiguration`,
`containerBackground` and `supplementalActivityFamily` all want a modern floor,
and paying for them with availability branches in every view is a worse trade
than "older devices keep the app, without widgets". An extension with a higher
minimum than its host is supported; the system simply doesn't install it.

`LiveActivityController` is the exception — it lives in the **app**, which is
still iOS 16, so every ActivityKit call sits behind an explicitly
`@available(iOS 16.2, *)` method rather than a `#available` guard wrapped
around a closure.
