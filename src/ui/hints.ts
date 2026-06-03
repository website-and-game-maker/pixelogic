import { UNKNOWN, FILLED, EMPTY, type Cell, type Puzzle } from "../engine/types";
import { solveLine } from "../engine/lineSolver";
import { propagate } from "../engine/solver";

export interface Hint {
  row: number;
  col: number;
  value: typeof FILLED | typeof EMPTY;
  reason: string;
}

function clueText(clue: number[]): string {
  return clue.length === 0 ? "0" : clue.join(" ");
}

function column(grid: Cell[][], c: number): Cell[] {
  return grid.map((row) => row[c]);
}

/** True if the player's filled cells already match the solution exactly. */
function isSolved(puzzle: Puzzle, marks: Cell[][]): boolean {
  for (let r = 0; r < puzzle.height; r++) {
    for (let c = 0; c < puzzle.width; c++) {
      if ((marks[r][c] === FILLED) !== puzzle.solution[r][c]) return false;
    }
  }
  return true;
}

/**
 * Build a solver grid keeping only the player's *correct* marks. Mistaken fills
 * and mistaken crosses are discarded (treated as UNKNOWN) so a hint is always a
 * valid logical deduction toward the real solution.
 */
function cleanState(puzzle: Puzzle, marks: Cell[][]): Cell[][] {
  return marks.map((row, r) =>
    row.map((cell, c) => {
      const shouldFill = puzzle.solution[r][c];
      if (cell === FILLED && shouldFill) return FILLED;
      if (cell === EMPTY && !shouldFill) return EMPTY;
      return UNKNOWN;
    }),
  );
}

/**
 * Return the next logically-forced cell given the player's current (correct)
 * marks, with a human-readable reason — or null if the board is already solved.
 */
export function nextHint(puzzle: Puzzle, marks: Cell[][]): Hint | null {
  if (isSolved(puzzle, marks)) return null;

  const clean = cleanState(puzzle, marks);

  // 1) Prefer a single-line deduction (easiest to explain).
  for (let r = 0; r < puzzle.height; r++) {
    const solved = solveLine(clean[r], puzzle.rowClues[r]);
    if (!solved) continue;
    for (let c = 0; c < puzzle.width; c++) {
      if (clean[r][c] === UNKNOWN && solved[c] !== UNKNOWN) {
        const value = solved[c] as typeof FILLED | typeof EMPTY;
        return {
          row: r,
          col: c,
          value,
          reason: `Row ${r + 1} (clue ${clueText(puzzle.rowClues[r])}): this cell must be ${
            value === FILLED ? "filled" : "empty"
          }.`,
        };
      }
    }
  }
  for (let c = 0; c < puzzle.width; c++) {
    const solved = solveLine(column(clean, c), puzzle.colClues[c]);
    if (!solved) continue;
    for (let r = 0; r < puzzle.height; r++) {
      if (clean[r][c] === UNKNOWN && solved[r] !== UNKNOWN) {
        const value = solved[r] as typeof FILLED | typeof EMPTY;
        return {
          row: r,
          col: c,
          value,
          reason: `Column ${c + 1} (clue ${clueText(puzzle.colClues[c])}): this cell must be ${
            value === FILLED ? "filled" : "empty"
          }.`,
        };
      }
    }
  }

  // 2) Fall back to a deduction that needs combined row+column propagation.
  const prop = propagate(puzzle.rowClues, puzzle.colClues, clean);
  for (let r = 0; r < puzzle.height; r++) {
    for (let c = 0; c < puzzle.width; c++) {
      if (clean[r][c] === UNKNOWN && prop.grid[r][c] !== UNKNOWN) {
        const value = prop.grid[r][c] as typeof FILLED | typeof EMPTY;
        return {
          row: r,
          col: c,
          value,
          reason: `Combining row ${r + 1} and column ${c + 1} forces this cell to be ${
            value === FILLED ? "filled" : "empty"
          }.`,
        };
      }
    }
  }

  return null;
}
