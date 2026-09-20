// Progression model — decides what you should play next, and notices when you're
// bored (breezing through) or struggling (stuck or giving up).
//
// Pure and DOM-free: every function takes the library and the player's state as
// arguments rather than reaching for storage, so it is fully unit-testable and
// can be mirrored exactly by the Swift port.
//
// The rules and constants here are NORMATIVE and shared with the Apple apps.
// See docs/progression-model.md — change a number here and you must change it
// there, in the Swift port, and in both test suites.

import type { Difficulty, Puzzle } from "./types";
import { DIFFICULTY_ORDER } from "./puzzles";
import { DIFFICULTY_WEIGHT, parSeconds, penaltyTotal, type AssistTally } from "./scoring";
import { puzzleBadges, badgeWeightMultiplier } from "./badges";

// ---------------------------------------------------------------- tuning ----

/** Hints in a single attempt before it counts as struggling. */
export const HINT_STRUGGLE_THRESHOLD = 3;

/** Consecutive smart-next presses with no solve before it degrades to plain next. */
export const SPAM_THRESHOLD = 3;

export type FastSensitivity = "relaxed" | "normal" | "eager";
export type StruggleSensitivity = "forgiving" | "normal" | "quick";

/** How eagerly a fast solve promotes you: `factor` × par, over `streak` solves. */
export const FAST_TUNING: Record<FastSensitivity, { factor: number; streak: number }> = {
  relaxed: { factor: 0.5, streak: 3 },
  normal: { factor: 0.6, streak: 2 },
  eager: { factor: 0.75, streak: 2 },
};

/** How eagerly repeated struggle demotes you. */
export const STRUGGLE_TUNING: Record<StruggleSensitivity, { streak: number }> = {
  forgiving: { streak: 3 },
  normal: { streak: 2 },
  quick: { streak: 1 },
};

export interface ProgressionSettings {
  /** Whether the top-right arrow is the sheened smart-next (off = plain next). */
  smartNext: boolean;
  /** Master switch for promote/demote. Off still records streaks. */
  autoAdjustDifficulty: boolean;
  fastSensitivity: FastSensitivity;
  struggleSensitivity: StruggleSensitivity;
  /** Whether heavy hint use counts as struggling. */
  hintsCountAsStruggle: boolean;
}

export function defaultProgressionSettings(): ProgressionSettings {
  return {
    smartNext: true,
    autoAdjustDifficulty: true,
    fastSensitivity: "normal",
    struggleSensitivity: "normal",
    hintsCountAsStruggle: true,
  };
}

// ----------------------------------------------------------------- state ----

export interface ProgressionState {
  /** The tier the recommender currently believes suits the player. */
  workingTier: Difficulty;
  fastStreak: number;
  struggleStreak: number;
  smartNextUses: number;
  smartNextPrompted: boolean;
  spamCount: number;
}

export function defaultProgressionState(): ProgressionState {
  return {
    workingTier: "easy",
    fastStreak: 0,
    struggleStreak: 0,
    smartNextUses: 0,
    smartNextPrompted: false,
    spamCount: 0,
  };
}

/** The slice of a puzzle the progression model actually needs. */
export type ProgressionPuzzle = Pick<Puzzle, "id" | "difficulty" | "solution" | "named">;

// ------------------------------------------------------------ curriculum ----

/**
 * The library in teaching order: tier-major, original order within a tier. Raw
 * library order interleaves tiers (the 10×10 block holds both easy and medium
 * puzzles), which is exactly the "Medium → Easy" jump this replaces.
 */
export function curriculumOrder<T extends { difficulty: Difficulty }>(library: T[]): T[] {
  return library
    .map((p, i) => ({ p, i }))
    .sort((a, b) => {
      const t = DIFFICULTY_ORDER.indexOf(a.p.difficulty) - DIFFICULTY_ORDER.indexOf(b.p.difficulty);
      return t !== 0 ? t : a.i - b.i;
    })
    .map((x) => x.p);
}

/** Position of a puzzle in curriculum order, or -1 if it isn't in the library. */
export function curriculumIndex(library: ProgressionPuzzle[], id: string): number {
  return curriculumOrder(library).findIndex((p) => p.id === id);
}

/**
 * The puzzle `offset` steps away in curriculum order, or `null` at either end.
 * Deliberately does NOT wrap: the first puzzle has no previous and the last has
 * no next, so the arrows can grey out honestly.
 */
export function curriculumNeighbour(
  library: ProgressionPuzzle[],
  id: string,
  offset: number,
): string | null {
  const ordered = curriculumOrder(library);
  const idx = ordered.findIndex((p) => p.id === id);
  if (idx < 0) return null;
  const next = idx + offset;
  return next >= 0 && next < ordered.length ? ordered[next].id : null;
}

// ---------------------------------------------------------------- signals ----

export type Signal = "fastClean" | "gaveUp" | "struggled" | "normal" | "abandoned";

export interface AttemptOutcome {
  solved: boolean;
  /** Fill out or Watch solve was used — the attempt already scores 0. */
  voided: boolean;
  assists: AssistTally;
  elapsedMs: number;
  difficulty: Difficulty;
  /** width × height. */
  area: number;
}

/**
 * Classify one finished attempt. Order is precedence: a player who used Fill out
 * is `gaveUp` even if they were also fast, and a board check outranks a fast time.
 */
export function classifySignal(a: AttemptOutcome, settings: ProgressionSettings): Signal {
  if (a.voided || a.assists.voided) return "gaveUp";
  if (!a.solved) return "abandoned";
  if (a.assists.checkBoard > 0) return "struggled";
  if (settings.hintsCountAsStruggle && a.assists.hint >= HINT_STRUGGLE_THRESHOLD) return "struggled";
  const clean = penaltyTotal(a.assists) === 0;
  const parMs = parSeconds(a.difficulty, a.area) * 1000;
  if (clean && a.elapsedMs <= FAST_TUNING[settings.fastSensitivity].factor * parMs) return "fastClean";
  return "normal";
}

// ------------------------------------------------------------ tier moves ----

function tierStep(tier: Difficulty, step: number): Difficulty | null {
  const i = DIFFICULTY_ORDER.indexOf(tier) + step;
  return i >= 0 && i < DIFFICULTY_ORDER.length ? DIFFICULTY_ORDER[i] : null;
}

function hasUnsolved(library: ProgressionPuzzle[], tier: Difficulty | null, completed: Set<string>): boolean {
  if (!tier) return false;
  return library.some((p) => p.difficulty === tier && !completed.has(p.id));
}

/**
 * Dropping a tier only helps if there is unfinished work down there. If the
 * player has already cleared the tier below AND the one below that, demoting
 * would hand them a puzzle they've solved instead of the challenge they're
 * stuck on — so they hold position.
 */
export function canDemote(
  tier: Difficulty,
  library: ProgressionPuzzle[],
  completed: Set<string>,
): boolean {
  const below = tierStep(tier, -1);
  if (!below) return false;
  return hasUnsolved(library, below, completed) || hasUnsolved(library, tierStep(tier, -2), completed);
}

/**
 * Fold one signal into the player's progression state. Pure — returns a new
 * state and never mutates the input.
 *
 * `fastStreak` and `struggleStreak` are mutually exclusive: evidence of one
 * zeroes the other, so a fast solve followed by a grind doesn't leave the
 * player "half promoted".
 */
export function applySignal(
  signal: Signal,
  state: ProgressionState,
  settings: ProgressionSettings,
  library: ProgressionPuzzle[],
  completed: Set<string>,
): ProgressionState {
  const next: ProgressionState = { ...state };

  if (signal === "abandoned") return next;

  // Any finished attempt clears the smart-next spam guard.
  next.spamCount = 0;

  if (signal === "gaveUp" || signal === "struggled") {
    next.struggleStreak = state.struggleStreak + 1;
    next.fastStreak = 0;
    const needed = STRUGGLE_TUNING[settings.struggleSensitivity].streak;
    if (settings.autoAdjustDifficulty && next.struggleStreak >= needed) {
      if (canDemote(next.workingTier, library, completed)) {
        next.workingTier = tierStep(next.workingTier, -1) ?? next.workingTier;
      }
      next.struggleStreak = 0; // reset whether or not we actually moved
    }
    return next;
  }

  if (signal === "fastClean") {
    next.fastStreak = state.fastStreak + 1;
    next.struggleStreak = 0;
    const needed = FAST_TUNING[settings.fastSensitivity].streak;
    if (settings.autoAdjustDifficulty && next.fastStreak >= needed) {
      next.workingTier = tierStep(next.workingTier, 1) ?? next.workingTier;
      next.fastStreak = 0;
    }
    return next;
  }

  // normal
  next.fastStreak = 0;
  next.struggleStreak = 0;
  return next;
}

// ------------------------------------------------------- recommendation ----

export interface Recommendation {
  puzzleId: string;
  tier: Difficulty;
  /** Player-facing copy explaining which branch fired. */
  reason: string;
}

const TIER_LABEL: Record<Difficulty, string> = {
  easy: "Easy",
  medium: "Medium",
  hard: "Hard",
  expert: "Extra Hard",
  max: "Max",
};

function firstUnsolvedIn(
  ordered: ProgressionPuzzle[],
  tier: Difficulty,
  completed: Set<string>,
): ProgressionPuzzle | undefined {
  return ordered.find((p) => p.difficulty === tier && !completed.has(p.id));
}

/**
 * What to play next. Walks the working tier, then upward, then downward, and
 * once the whole library is solved switches to "best improvement" — the puzzle
 * where raising the per-puzzle score would move the 0–1600 Clueweave Score most.
 *
 * `excludeId` drops one puzzle from every branch. Callers acting as a "next"
 * affordance pass the puzzle currently on screen, because recommending the
 * puzzle you are already sitting on is never a useful answer to "what next?".
 */
export function recommend(
  state: ProgressionState,
  library: ProgressionPuzzle[],
  completed: Set<string>,
  bestScores: Record<string, number>,
  excludeId?: string,
): Recommendation | null {
  const pool = excludeId ? library.filter((p) => p.id !== excludeId) : library;
  if (pool.length === 0) return null;
  const ordered = curriculumOrder(pool);
  const at = DIFFICULTY_ORDER.indexOf(state.workingTier);

  // 1. the working tier itself
  const here = firstUnsolvedIn(ordered, state.workingTier, completed);
  if (here) return { puzzleId: here.id, tier: here.difficulty, reason: "Next up at your level." };

  // 2. upward
  for (let i = at + 1; i < DIFFICULTY_ORDER.length; i++) {
    const hit = firstUnsolvedIn(ordered, DIFFICULTY_ORDER[i], completed);
    if (hit) {
      return {
        puzzleId: hit.id,
        tier: hit.difficulty,
        reason: `You're breezing through — moving you up to ${TIER_LABEL[hit.difficulty]}.`,
      };
    }
  }

  // 3. downward
  for (let i = at - 1; i >= 0; i--) {
    const hit = firstUnsolvedIn(ordered, DIFFICULTY_ORDER[i], completed);
    if (hit) {
      return {
        puzzleId: hit.id,
        tier: hit.difficulty,
        reason: `Backing off to ${TIER_LABEL[hit.difficulty]} for a bit.`,
      };
    }
  }

  // 4. everything solved — most score left to win
  let best: { p: ProgressionPuzzle; gain: number } | null = null;
  for (const p of ordered) {
    const gain =
      (100 - (bestScores[p.id] ?? 0)) *
      DIFFICULTY_WEIGHT[p.difficulty] *
      badgeWeightMultiplier(puzzleBadges(p));
    if (!best || gain > best.gain) best = { p, gain }; // ties keep the earlier (lower) index
  }
  if (!best) return null;
  return {
    puzzleId: best.p.id,
    tier: best.p.difficulty,
    reason: "Everything's solved — this one has the most score left to win.",
  };
}

/**
 * Where the top-right arrow should go. Falls back to plain curriculum order when
 * smart next is switched off, or when the player is mashing it (the spam guard),
 * so a spammer gets a sane ordered walk instead of being flung around the library.
 */
export function smartNextTarget(
  state: ProgressionState,
  currentPuzzleId: string,
  settings: ProgressionSettings,
  library: ProgressionPuzzle[],
  completed: Set<string>,
  bestScores: Record<string, number>,
): Recommendation | null {
  const plain = (): Recommendation | null => {
    const id = curriculumNeighbour(library, currentPuzzleId, 1);
    if (!id) return null;
    const p = library.find((q) => q.id === id)!;
    return { puzzleId: id, tier: p.difficulty, reason: "Next puzzle in order." };
  };
  if (!settings.smartNext) return plain();
  if (state.spamCount >= SPAM_THRESHOLD) return plain();
  return recommend(state, library, completed, bestScores, currentPuzzleId);
}

/** Whether the first-use opt-out prompt should be shown for this press. */
export function shouldPromptSmartNext(state: ProgressionState, settings: ProgressionSettings): boolean {
  return settings.smartNext && !state.smartNextPrompted && state.smartNextUses <= 3;
}
