# Agent handoff — tracking "bored" and "struggling"

**Read this first, then `docs/progression-model.md` for the normative detail.**

This is the brief for whoever implements the progression feature on this side. The
web app (`website-and-game-maker/clueweave`) is the **reference implementation** — it
is built, tested, and green. Match its behaviour exactly; where this brief and the
contract disagree, the contract wins.

---

## What we're building, in one paragraph

The game watches how each attempt goes and keeps a single piece of state — a
**working tier** — representing the difficulty it thinks suits the player. Solve
things quickly and cleanly and it moves you up. Keep giving up or leaning on help and
it moves you down. Everything else (the recommendation on the home screen, the glowing
→ button in the play view) is a read of that one number.

There is no hidden rating, no Elo, no decay. If you find yourself adding one, stop —
see contract §9.

---

## The two things you must detect

### Bored → `fastClean`

An attempt is `fastClean` when **all** of these hold:

- the player solved it,
- they used **zero** assists (`penaltyTotal(assists) == 0` — no hints, no square/line/
  board checks), and
- `elapsedMs <= fastFactor × parSeconds(tier, area) × 1000`, where `fastFactor` is
  `0.60` at the default sensitivity.

Reuse the existing `parSeconds` from the scoring model. Do **not** invent a new par.

The zero-assist requirement is deliberate and load-bearing: fast *with* help is not
mastery, and promoting on it pushes people into tiers they can't hold.

### Struggling → `gaveUp` / `struggled`

- `gaveUp` — Fill out or Watch solve was used. The attempt already scores 0.
- `struggled` — Check board was used, **or** hints reached `HINT_STRUGGLE_THRESHOLD`
  (3) in one attempt, and the `hintsCountAsStruggle` setting is on.

Being merely *slow* is not struggling. Slow is `normal`.

### Everything else

- `normal` — a finished solve that was neither fast-and-clean nor a struggle.
- `abandoned` — not solved. **Changes no state at all.** Browsing with the arrows or
  walking away must never move the working tier.

Classification order is precedence — evaluate top to bottom and stop at the first
match, so a player who used Fill out is `gaveUp` even if they were also under par.

---

## How the streaks move

Two counters, `fastStreak` and `struggleStreak`, and they are **mutually exclusive** —
any evidence of one zeroes the other. A `normal` signal zeroes both.

- `fastStreak` reaching **2** (default) → promote one tier, reset to 0.
- `struggleStreak` reaching **2** (default) → demote one tier, reset to 0 — *but only
  if demoting would actually help* (below).

### The rule people get wrong

Demotion is gated by `canDemote`. If the tier below **and** the tier two below are
both fully solved, **do not demote** — hold position and reset the streak anyway.
Otherwise you hand a stuck player a puzzle they already beat.

A single give-up therefore **keeps you on the tier**. It takes two.

---

## Worked traces — check your implementation against these

Default settings throughout (`fastFactor 0.60`, both streaks `2`).

**Bored player climbs.**
```
start                                   tier=easy   fast=0 struggle=0
solve Plus  (par 25s) in 12s, no help   fastClean → fast=1            (12s ≤ 15s)
solve Smiley(par 25s) in 10s, no help   fastClean → fast=2 → PROMOTE  tier=medium fast=0
```

**Struggling player drops.**
```
start                                   tier=hard   fast=0 struggle=0
Bird   — used Watch solve               gaveUp    → struggle=1        tier=hard (holds)
Anchor — used Check board               struggled → struggle=2 → DEMOTE tier=medium struggle=0
```

**Struggling, but there's nothing below worth playing.**
```
start, all easy+medium already solved   tier=hard
gave up                                 struggle=1                    tier=hard
gave up                                 struggle=2 → canDemote=false  tier=hard struggle=0
```

**Noise doesn't accumulate.**
```
fastClean                               fast=1
normal                                  fast=0 struggle=0   ← streak broken
fastClean                               fast=1              ← no promotion
```

**Assists disqualify a fast solve.**
```
solved in 8s (par 25s) with 1 square check   → normal, NOT fastClean
```

**Spam guard.**
```
press smart-next ×3 with no solve between    spamCount=3
press smart-next again                        → plain curriculum next, not a recommendation
finish any attempt                            spamCount=0
```

**Never recommend the puzzle you're on.** This one bit the web implementation — write
the test first.
```
tier=easy, Ghost is the only unsolved Easy, player is sitting on Ghost
press smart-next    → must NOT return Ghost; walks up and returns the first unsolved Medium
```
`recommend()` takes an `excludeId` that drops a puzzle from **all four** branches
(including best-improvement). `smartNextTarget` passes the current puzzle id; the
home-screen recommendation passes nothing.

---

## Where to put it

Per this repo's `CLAUDE.md` feature protocol: **engine first, test-driven.**

- `ClueweaveKit/Sources/ClueweaveKit/Progression.swift` — pure, `Sendable`, no UI. Mirror
  the web module's shape:

  ```swift
  public enum Signal { case fastClean, gaveUp, struggled, normal, abandoned }

  public func curriculumOrder(_ library: [Puzzle]) -> [Puzzle]
  public func curriculumNeighbour(_ library: [Puzzle], id: String, offset: Int) -> String?
  public func classifySignal(_ attempt: AttemptOutcome, _ settings: ProgressionSettings) -> Signal
  public func canDemote(_ tier: Difficulty, _ library: [Puzzle], _ completed: Set<String>) -> Bool
  public func applySignal(...) -> ProgressionState
  public func recommend(...) -> Recommendation?
  public func smartNextTarget(...) -> Recommendation?
  ```

- Tests in `Tests/ClueweaveKitTests/` **and** mirrored checks in
  `Sources/clueweave-verify/main.swift` so they run under bare Command Line Tools.
  The traces above make good test cases verbatim.

- `SaveData`: six new fields (`workingTier`, `fastStreak`, `struggleStreak`,
  `smartNextUses`, `smartNextPrompted`, `spamCount`). Register in `CodingKeys`, decode
  tolerantly through `field(...)`, add `PlayerStore` accessors, route mutations through
  `AppModel`. A corrupt progression block must fall back to defaults and never discard
  the rest of the save.

- `resetProgress()` restores all six to defaults. Settings survive. `userPuzzles` and
  `generatedPuzzles` must survive — that rule already exists and still applies.

- **Watch:** surfaces a "Recommended" row using `recommend()` over watch-local
  completion data. It does **not** run the state machine — no streaks on the wrist.

---

## Where the signals are raised

One call site per outcome. On the web these are in `src/ui/views/play.ts`:

- at the end of `handleWin()` — covers both a real solve and a Fill out, after the
  score is settled so the assist tally is final;
- in `watchSolve()` before navigating away — asking to be shown the answer is the
  clearest give-up there is.

Do the equivalent in `PlayViewModel`. Only **built-in library** puzzles teach the model
anything — custom, generated, shared, and test-play puzzles must not.

---

## Numbers you must not drift on

| | |
|---|---|
| `fastFactor` | relaxed `0.50` · normal `0.60` · eager `0.75` |
| `fastStreakNeeded` | relaxed `3` · normal `2` · eager `2` |
| `struggleStreakNeeded` | forgiving `3` · normal `2` · quick `1` |
| `HINT_STRUGGLE_THRESHOLD` | `3` |
| `SPAM_THRESHOLD` | `3` |

These are product, not implementation detail — same standing as par times and share
tokens. Changing one means changing it in both repos and both test suites in the same
change.
