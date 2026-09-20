import { UNKNOWN, type Cell, type Clue, type Difficulty } from "./types";
import { solveLine } from "./lineSolver";
import { isLineSolvable } from "./solver";
import { solveByLogic } from "./deduce";
import { cluesForGrid } from "./clues";
import { isSymmetric } from "./symmetry";
import { detectPatterned } from "./badges";

const TIER_ORDER: Difficulty[] = ["easy", "medium", "hard", "expert", "max"];

function capAt(d: Difficulty, cap: Difficulty): Difficulty {
  return TIER_ORDER.indexOf(d) > TIER_ORDER.indexOf(cap) ? cap : d;
}

/**
 * Grade by reasoning effort, judged from the clues alone:
 *  - line-solvable puzzles are graded by how many full propagation sweeps a
 *    deduction-only solver needs (size doesn't matter — a big trivial picture
 *    is still easy);
 *  - puzzles where pure line logic stalls need hypothesis/contradiction
 *    reasoning and start at `expert`.
 * `gradeGrid` refines this with whole-picture rules (symmetry, pattern, Max).
 */
export function grade(rowClues: Clue[], colClues: Clue[]): Difficulty {
  if (!isLineSolvable(rowClues, colClues)) return "expert";
  const rounds = countPropagationRounds(rowClues, colClues);
  if (rounds <= 2) return "easy";
  if (rounds <= 4) return "medium";
  return "hard";
}

// Below this effort score a contradiction puzzle is "Extra Hard" (expert); at
// or above it, "Max". Chosen from measured effort on the library's contradiction
// puzzles (`npx vite-node scripts/tune.ts`):
//   true Expert-tier puzzles today top out at Enigma, effort ≈197.5
//   true Max-tier puzzles today start at Leviathan, effort ≈231.5
// 200 sat right on top of Enigma with only a ~2.5 margin — a hair's-width cliff
// where a one-step change in the solver could silently flip its tier. 215 is
// the (rounded) midpoint of the real 197.5–231.5 gap in the data, so it keeps
// both neighbors comfortably clear on their existing side while leaving room
// for the new mid-effort Expert puzzles (added to close the old 44→113 gap)
// to land anywhere up to ~200 without crowding the boundary.
const EXPERT_MAX_EFFORT_CUTOFF = 215;

/**
 * Grade a full solution grid:
 *  - contradiction puzzles are split into Extra Hard vs Max by total reasoning
 *    effort (how many what-if proofs, how many forced steps, how long the lines);
 *  - a symmetric picture leaks information → capped at Hard;
 *  - a patterned picture (one run per line) is mostly "continue the shape" →
 *    capped at Medium.
 *  Both whole-picture caps are shortcuts for *line* solving only — mirroring a
 *  row's clue gives you its twin for free, and continuing a single run is easy
 *  to guess. Neither shortcut helps a hypothesis/contradiction proof: proving a
 *  cell is forced by contradiction takes the same what-if propagation whether
 *  or not the rest of the grid happens to mirror or run-continue. So a puzzle
 *  that needed contradiction reasoning (not line-solvable) is never capped by
 *  either rule — a what-if proof stays a what-if proof regardless of the
 *  picture's shape. (Regression: "Letter A" is left-right symmetric AND needs
 *  one contradiction step; it must grade `expert`, not get dragged to `hard`.)
 */
export function gradeGrid(solution: boolean[][]): Difficulty {
  const { rowClues, colClues } = cluesForGrid(solution);
  const area = solution.length * (solution[0]?.length ?? 0);

  const lineSolvable = isLineSolvable(rowClues, colClues);
  let d: Difficulty;
  if (lineSolvable) {
    d = grade(rowClues, colClues);
  } else {
    const { steps } = solveByLogic(rowClues, colClues);
    const contradictions = steps.filter((s) => s.technique === "contradiction").length;
    // Effort blends the number of what-if proofs (weighted heavily — each is a
    // full sub-deduction), the sheer number of forced steps, and the line size.
    const effort = steps.length + 15 * contradictions + area / 2;
    d = effort >= EXPERT_MAX_EFFORT_CUTOFF ? "max" : "expert";
  }

  if (lineSolvable) {
    if (isSymmetric(solution)) d = capAt(d, "hard");
    if (detectPatterned(solution)) d = capAt(d, "medium");
  }
  return d;
}

/** Number of full row+column sweeps propagation needs to reach its fixpoint. */
function countPropagationRounds(rowClues: Clue[], colClues: Clue[]): number {
  const h = rowClues.length;
  const w = colClues.length;
  const grid: Cell[][] = Array.from({ length: h }, () => Array<Cell>(w).fill(UNKNOWN));

  let rounds = 0;
  let changed = true;
  while (changed) {
    changed = false;
    rounds++;
    for (let r = 0; r < h; r++) {
      const next = solveLine(grid[r], rowClues[r]);
      if (!next) return rounds;
      for (let c = 0; c < w; c++) {
        if (next[c] !== grid[r][c]) {
          grid[r][c] = next[c];
          changed = true;
        }
      }
    }
    for (let c = 0; c < w; c++) {
      const column = grid.map((row) => row[c]);
      const next = solveLine(column, colClues[c]);
      if (!next) return rounds;
      for (let r = 0; r < h; r++) {
        if (next[r] !== grid[r][c]) {
          grid[r][c] = next[r];
          changed = true;
        }
      }
    }
  }
  return rounds;
}
