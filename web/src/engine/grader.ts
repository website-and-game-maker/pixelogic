import type { Clue, Difficulty } from "./types";
import { solveByLogic } from "./deduce";
import { cluesForGrid } from "./clues";
import { detectSymmetry } from "./symmetry";
import { detectPatterned } from "./badges";

const TIER_ORDER: Difficulty[] = ["easy", "medium", "hard", "expert", "max"];

/**
 * Effective-work cutoffs. A puzzle's `effectiveWork` (see below) is bucketed
 * into a tier by these thresholds. They were chosen by measuring every curated
 * puzzle on the unified work scale and placing the boundaries where the natural
 * gaps fall, so the tiers are monotonic in real solving effort.
 *
 *   effectiveWork < 25   → easy
 *                 < 55   → medium
 *                 < 80   → hard
 *                 < 120  → expert   (shown as "Extra Hard")
 *                 else   → max
 *
 * The easy ceiling is deliberately set above every 5×5 in the library. A 5×5 is
 * 25 cells — small enough to hold entirely in your head — so it reads as easy to
 * a player no matter how many forced steps the solver logs getting there.
 *
 * Each boundary sits in the middle of a real gap in the measured spread, not
 * hard against a puzzle's score, so a small future change to a bitmap can't flip
 * a tier by accident. The nearest puzzle to any cutoff is ~5 work units away.
 *
 * These numbers are **product**, on the same footing as par times and share
 * tokens: they must stay identical to the Apple engine (`Grader.swift`). Changing
 * one means changing it in both repos and both test suites in the same change.
 */
const TIER_CUTOFFS: ReadonlyArray<readonly [number, Difficulty]> = [
  [25, "easy"],
  [55, "medium"],
  [80, "hard"],
  [120, "expert"],
];

function tierForEffort(effort: number): Difficulty {
  for (const [ceiling, tier] of TIER_CUTOFFS) {
    if (effort < ceiling) return tier;
  }
  return "max";
}

/**
 * Raw solving work, computed uniformly for every puzzle — line-solvable or not.
 *
 *   work = deductionSteps + longestLine × contradictionProofs + area / 4
 *
 * `solveByLogic` runs the same line-then-depth-1-contradiction reasoning a
 * careful human uses, so the step count is a faithful proxy for effort. Each
 * what-if (contradiction) proof is a full sub-deduction, so it is weighted
 * heavily — but **how** heavily has to depend on the board. A what-if on a 5×5
 * means eyeballing a couple of placements in a five-cell line; the same proof
 * on a 15×15 is real work you have to hold in your head. Scaling by the longest
 * line keeps small puzzles honest (a flat weight used to shove tiny grids two
 * whole tiers up) while leaving the big contradiction puzzles where they were.
 * The area term is a small allowance for sheer bookkeeping — divided by four so
 * a big-but-trivial picture (e.g. a 10×10 that falls out in two sweeps) never
 * masquerades as difficult.
 */
function rawWork(rowClues: Clue[], colClues: Clue[], area: number): number {
  const { steps } = solveByLogic(rowClues, colClues);
  const contradictions = steps.filter((s) => s.technique === "contradiction").length;
  const longestLine = Math.max(rowClues.length, colClues.length);
  return steps.length + longestLine * contradictions + area / 4;
}

/**
 * How much a picture's shape *leaks* to a human that the blind solver can't use.
 * Symmetry and single-run patterning are genuine head-starts, so they discount
 * the work **proportionally** (never a hard cap — a hard puzzle stays hard, it
 * just eases toward the next tier down rather than snapping to it).
 */
function informationFactor(solution: boolean[][]): number {
  const s = detectSymmetry(solution);
  let factor = 1;
  if (s.horizontal && s.vertical) factor *= 0.55; // both mirror axes leak the most
  else if (s.horizontal || s.vertical) factor *= 0.7; // one axis
  else if (s.rotational) factor *= 0.55; // 180° rotation is as strong as two axes
  if (detectPatterned(solution)) factor *= 0.65; // one solid run per line — "continue the shape"
  return factor;
}

/**
 * Grade from the clues alone (no grid). Used by the editor's quick read and by
 * tests. Without the solution grid we can't see symmetry or patterning, so this
 * is the *undiscounted* work tier — `gradeGrid` refines it with the whole-picture
 * information factor.
 */
export function grade(rowClues: Clue[], colClues: Clue[]): Difficulty {
  const area = rowClues.length * colClues.length;
  return tierForEffort(rawWork(rowClues, colClues, area));
}

/**
 * Grade a full solution grid. This is the authoritative tier shown to the player:
 * unified solving work, discounted by the information the picture's shape gives a
 * human (symmetry, patterning). Size enters only through the small area term in
 * the work — a picture is not hard just for being large.
 */
export function gradeGrid(solution: boolean[][]): Difficulty {
  const { rowClues, colClues } = cluesForGrid(solution);
  const area = solution.length * (solution[0]?.length ?? 0);
  const effort = rawWork(rowClues, colClues, area) * informationFactor(solution);
  return tierForEffort(effort);
}

/** Exposed for callers that need the canonical tier ordering. */
export { TIER_ORDER };
