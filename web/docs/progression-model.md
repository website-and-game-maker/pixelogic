# Progression model — shared contract

**Status:** normative. **Applies to:** the web app (`clueweave`) and the Apple apps
(`clueweave-apple`: ClueweaveKit, iOS/iPad, Watch).

This document defines how Clueweave decides *what puzzle you should play next*, and how
it notices that you are **bored** (breezing through) or **struggling** (stuck or giving
up). It exists so that two independent implementations produce **identical** behaviour
from identical inputs. Treat it the way `ShareCodec` and `Scoring` are treated: the
numbers are part of the product, not implementation detail.

If you change a rule or a constant here, change it in **both** implementations and in
**both** test suites in the same change. A divergence is a bug even if both sides pass
their own tests.

---

## 1. Vocabulary

| Term | Meaning |
|---|---|
| **Tier** | A difficulty level: `easy`, `medium`, `hard`, `expert` (shown as "Extra Hard"), `max`. Ordered by `DIFFICULTY_ORDER`. |
| **Curriculum order** | The whole built-in library sorted by *(tier index, original library index)*. Stable, deterministic, identical on every platform. |
| **Working tier** | The tier the recommender currently believes suits the player. Persisted. Moves up when bored, down when struggling. Not the same as "highest tier solved". |
| **Signal** | The single classification of one finished attempt: `fastClean`, `gaveUp`, `struggled`, `normal`, or `abandoned`. |
| **Par** | The existing per-tier target time from the scoring model. **Do not invent a new one** — reuse `parSeconds(difficulty, area)`. |

Curriculum order is *not* raw library order. Raw library order interleaves tiers (the
10×10 block contains both easy and medium puzzles), which is exactly the "Medium → Easy"
jump this model exists to remove.

---

## 2. Signals — how boredom and struggle are detected

One attempt produces exactly one signal. Evaluate in this order and stop at the first
match; the order encodes precedence, so a player who used Fill out is `gaveUp` even if
they were also fast.

```
classify(attempt, settings) -> Signal

  1. if attempt.voided                       -> gaveUp
        (voided == Fill out or Watch solve was used; the score is already 0)

  2. if not attempt.solved                   -> abandoned

  3. if attempt.assists.checkBoard > 0       -> struggled

  4. if settings.hintsCountAsStruggle
        and attempt.assists.hint >= HINT_STRUGGLE_THRESHOLD
                                             -> struggled

  5. if penaltyTotal(attempt.assists) == 0
        and attempt.elapsedMs <= fastFactor(settings) * parSeconds(tier, area) * 1000
                                             -> fastClean

  6. otherwise                               -> normal
```

Notes that matter:

- **`fastClean` requires a totally clean solve.** `penaltyTotal == 0` means no hints, no
  square/line/board checks. One peek disqualifies the attempt from promoting you. This
  is deliberate: speed with assists is not mastery.
- **`abandoned` changes no state.** Walking away, or browsing with the arrows, must not
  move the working tier. Only finished attempts teach the model anything.
- **`struggled` is about revealed difficulty, not slowness.** Being slow is `normal`.
  Taking the board apart with Check board, or leaning on hints repeatedly, is struggling.

---

## 3. State machine

Persisted state:

```
workingTier      : Tier     default = easy
fastStreak       : int      default = 0
struggleStreak   : int      default = 0
smartNextUses    : int      default = 0
smartNextPrompted: bool     default = false
spamCount        : int      default = 0
```

Transition:

```
apply(signal, state, settings, library, completed) -> state

  gaveUp, struggled:
      struggleStreak += 1
      fastStreak      = 0
      if settings.autoAdjustDifficulty and struggleStreak >= struggleStreakNeeded:
          if canDemote(workingTier, library, completed):
              workingTier = tier below workingTier
          struggleStreak = 0            # reset whether or not we actually demoted

  fastClean:
      fastStreak     += 1
      struggleStreak  = 0
      if settings.autoAdjustDifficulty and fastStreak >= fastStreakNeeded:
          if a tier above workingTier exists:
              workingTier = tier above workingTier
          fastStreak = 0

  normal:
      fastStreak = 0
      struggleStreak = 0

  abandoned:
      (no change)
```

### 3.1 `canDemote` — the "don't send me backwards into nothing" rule

Dropping a tier is only useful if there is unfinished work down there. If the player has
already cleared everything below, demoting would hand them a puzzle they have solved
instead of the challenge they are stuck on.

```
canDemote(tier, library, completed):
    below  = tier - 1        # nil if tier is the lowest
    below2 = tier - 2        # nil if there is no such tier
    if below is nil: return false
    return anyUnsolved(below) or anyUnsolved(below2)
```

So: a single give-up **keeps you on the tier** (the streak is only 1). Repeated give-ups
drop you one tier — unless the tier below *and* the tier below that are fully cleared, in
which case you hold position.

### 3.2 Streak resets

`fastStreak` and `struggleStreak` are **mutually exclusive**: any evidence of one zeroes
the other. A player who solves one puzzle fast and then grinds the next is not "half
promoted". Both also reset to 0 on a `normal` signal, which is the common case and keeps
the model from drifting on noise.

---

## 4. Tunable settings

All are user-facing and persisted with the other game settings.

| Setting | Type | Default | Effect |
|---|---|---|---|
| `smartNext` | bool | `true` | Whether the top-right arrow is the sheened smart-next. Off = a plain next-in-curriculum arrow. |
| `autoAdjustDifficulty` | bool | `true` | Master switch for promote/demote. Off = signals are still recorded, `workingTier` never moves. |
| `fastSensitivity` | enum | `normal` | How eagerly boredom promotes you. |
| `struggleSensitivity` | enum | `normal` | How eagerly struggle demotes you. |
| `hintsCountAsStruggle` | bool | `true` | Whether heavy hint use counts as struggling. |

Derived constants — **these exact numbers**:

| `fastSensitivity` | `fastFactor` (× par) | `fastStreakNeeded` |
|---|---|---|
| `relaxed` | 0.50 | 3 |
| `normal` | 0.60 | 2 |
| `eager` | 0.75 | 2 |

| `struggleSensitivity` | `struggleStreakNeeded` |
|---|---|
| `forgiving` | 3 |
| `normal` | 2 |
| `quick` | 1 |

```
HINT_STRUGGLE_THRESHOLD = 3      # hints in one attempt
SPAM_THRESHOLD          = 3      # consecutive smart-next presses with no solve
```

`autoAdjustDifficulty = false` must still record signals and streaks. Turning it back on
should resume from real history rather than a blank slate.

---

## 5. Recommendation

```
recommend(state, library, completed, bestScores, excludeId?) -> (puzzleId, reason)

  pool = library minus excludeId (when given)

  1. first unsolved puzzle in workingTier, in curriculum order
  2. else walk tiers upward from workingTier+1, first unsolved in curriculum order
  3. else walk tiers downward from workingTier-1, first unsolved in curriculum order
  4. else (everything solved) best improvement:
         argmax over pool of
             (100 - bestScore[id]) * DIFFICULTY_WEIGHT[tier] * badgeWeightMultiplier(id)
         tie-break by lowest curriculum index
```

**`excludeId` is required for correctness, not a convenience.** It drops one puzzle
from *every* branch, including step 4. Any caller acting as a "next" affordance passes
the puzzle currently on screen, because recommending the puzzle the player is already
sitting on is never a useful answer to "what next?" — and it happens constantly in
practice, whenever the current puzzle is the first unsolved one at the working tier.
The home-screen recommendation passes nothing, since the player is not on a puzzle.

Step 4 is why "Recommended puzzle" still has something to say to a completionist: it
points at the puzzle where raising the per-puzzle score would move the 0–1600 Clueweave
Score the most. Reuse `DIFFICULTY_WEIGHT` and `badgeWeightMultiplier` from the scoring
model — do not re-derive weights.

The `reason` string is UI copy and need not match across platforms verbatim, but it must
be truthful about which of the four branches fired. Suggested phrasings:

| Branch | Reason |
|---|---|
| 1 | "Next up at your level." |
| 2 | "You're breezing through — moving you up to {tier}." |
| 3 | "Backing off to {tier} for a bit." |
| 4 | "Everything's solved — this one has the most score left to win." |

---

## 6. Smart next vs. plain next

Two distinct affordances. Do not merge them.

**Bottom nav strip — `←` / `→`.** Walks **curriculum order**, always, for everyone. No
wraparound: on the first puzzle `←` is disabled, on the last `→` is disabled. Visually
distinct from the assist buttons. This is the predictable manual browse, and it never
consults the model or mutates state.

**Top-right arrow — smart next.** Larger, with an animated sheen when active.

```
smartNext(state, currentPuzzleId, settings) -> puzzleId | nil

  if not settings.smartNext:            return curriculumNext(currentPuzzleId)
  if state.spamCount >= SPAM_THRESHOLD: return curriculumNext(currentPuzzleId)
  return recommend(...).puzzleId
```

`spamCount` increments on every smart-next press and resets to 0 on any solve. Once it
trips, the button quietly behaves as plain next — the player mashing it gets a sane,
ordered walk instead of the recommender flinging them around the library.

### 6.1 First-use opt-out prompt

On the **first three** presses of the smart-next button (`smartNextUses <= 3`), show a
dismissible prompt after navigating: what it picked, why, and an offer to turn it off.
Choosing "just go in order" sets `smartNext = false`, which removes the sheen and turns
the button into a plain next arrow. Set `smartNextPrompted = true` once answered and stop
asking. Reachable again from Settings in both directions.

---

## 7. Persistence

Add the six state fields plus the five settings. **Both platforms must decode tolerantly**:
a missing or corrupt progression block falls back to defaults and must never discard the
rest of the save.

- **Web** — extend `SaveData` in `src/ui/persistence.ts`. Do **not** bump `version`; the
  existing loader already merges field-by-field over `defaultSaveData()`, so old saves
  pick up defaults for free.
- **Apple** — add to `SaveData`, register in `CodingKeys`, decode through the existing
  `field(...)` helper, add `PlayerStore` accessors, and route mutations through
  `AppModel` so SwiftUI observes them. Per the repo protocol, `resetProgress()` clears
  progression state but must not touch `userPuzzles` or `generatedPuzzles`.

Progression state **is** progress: `resetProgress()` restores all six fields to defaults.
Settings survive a reset.

---

## 8. Test obligations

Both suites must cover, with the same fixtures:

1. Curriculum order is tier-major and stable; `curriculumNext` on the last puzzle is nil;
   `curriculumPrev` on the first is nil.
2. Each signal classifies correctly, including precedence (voided + fast → `gaveUp`;
   checkBoard + fast → `struggled`).
3. `fastClean` requires zero assist penalty.
4. Promotion needs `fastStreakNeeded` **consecutive** fast solves; one `normal` in
   between resets it.
5. Demotion needs `struggleStreakNeeded` consecutive struggles.
6. `canDemote` is false when the tier below and two below are fully cleared → the working
   tier holds.
7. `autoAdjustDifficulty = false` records streaks but never moves the tier.
8. Recommendation walks up before down, and falls back to best-improvement only when the
   library is fully solved.
9. Best-improvement respects difficulty weight × badge multiplier, not raw score gap.
10. `spamCount >= SPAM_THRESHOLD` degrades smart next to curriculum next; a solve resets it.
11. Each sensitivity enum maps to the exact constants in §4.
12. `smartNextTarget` never returns the puzzle it was called on — including when that
    puzzle is the only unsolved one at the working tier, where the naive
    implementation returns it every time.

Apple additionally mirrors these into `Sources/clueweave-verify/main.swift` so they run
under bare Command Line Tools.

---

## 9. Deliberate non-goals

- **No cross-device sync.** Progression is local, like everything else.
- **No hidden rating.** `workingTier` is the whole model. There is no Elo, no per-puzzle
  skill estimate, no decay over time. If it can't be explained in one sentence to a
  player, it doesn't belong here.
- **The Watch does not run the state machine.** It has its own `@AppStorage` state and no
  `PlayerStore`. It surfaces a "Recommended" row using the same `recommend()` function
  over watch-local completion data, and does not attempt to track streaks.
