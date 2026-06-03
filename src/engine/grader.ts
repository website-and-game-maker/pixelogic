import { UNKNOWN, type Cell, type Clue, type Difficulty } from "./types";
import { solveLine } from "./lineSolver";
import { isLineSolvable } from "./solver";

/**
 * Grade a puzzle by the hardest technique required to solve it:
 *  - If pure propagation can't finish, it needs hypothesis/contradiction search
 *    → `hard` (or `expert` for large grids).
 *  - Otherwise grade by effort: how many propagation rounds it took, plus size.
 */
export function grade(rowClues: Clue[], colClues: Clue[]): Difficulty {
  const h = rowClues.length;
  const w = colClues.length;
  const area = h * w;

  if (!isLineSolvable(rowClues, colClues)) {
    return area >= 150 ? "expert" : "hard";
  }

  const rounds = countPropagationRounds(rowClues, colClues);

  if (rounds <= 2 && area <= 36) return "easy";
  if (rounds <= 4 && area <= 120) return "medium";
  if (area <= 120) return "medium";
  return "hard";
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
