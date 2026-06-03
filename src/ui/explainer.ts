import { UNKNOWN, FILLED, type Cell, type Puzzle } from "../engine/types";
import { solveLine } from "../engine/lineSolver";

export interface DeducedCell {
  r: number;
  c: number;
  value: Cell;
}

export interface SolveStep {
  lineType: "row" | "col";
  index: number;
  cells: DeducedCell[];
  caption: string;
}

function clueText(clue: number[]): string {
  return clue.length === 0 ? "0" : clue.join(" ");
}

function column(grid: Cell[][], c: number): Cell[] {
  return grid.map((row) => row[c]);
}

function isComplete(grid: Cell[][]): boolean {
  return grid.every((row) => row.every((cell) => cell !== UNKNOWN));
}

/**
 * Replay pure-logic propagation as an ordered list of human-readable steps,
 * one per line that makes progress. Used by the "watch it solve" view.
 */
export function solveSteps(puzzle: Puzzle): SolveStep[] {
  const h = puzzle.height;
  const w = puzzle.width;
  const grid: Cell[][] = Array.from({ length: h }, () => Array<Cell>(w).fill(UNKNOWN));
  const steps: SolveStep[] = [];

  let changed = true;
  while (changed && !isComplete(grid)) {
    changed = false;

    for (let r = 0; r < h; r++) {
      const solved = solveLine(grid[r], puzzle.rowClues[r]);
      if (!solved) continue;
      const cells = collectChanges(grid[r], solved, (c) => ({ r, c, value: solved[c] }));
      if (cells.length === 0) continue;
      for (const cell of cells) grid[r][cell.c] = cell.value;
      steps.push({
        lineType: "row",
        index: r,
        cells,
        caption: `Row ${r + 1} (clue ${clueText(puzzle.rowClues[r])}) → ${describe(cells)}.`,
      });
      changed = true;
    }

    for (let c = 0; c < w; c++) {
      const solved = solveLine(column(grid, c), puzzle.colClues[c]);
      if (!solved) continue;
      const cells = collectChanges(column(grid, c), solved, (r) => ({ r, c, value: solved[r] }));
      if (cells.length === 0) continue;
      for (const cell of cells) grid[cell.r][c] = cell.value;
      steps.push({
        lineType: "col",
        index: c,
        cells,
        caption: `Column ${c + 1} (clue ${clueText(puzzle.colClues[c])}) → ${describe(cells)}.`,
      });
      changed = true;
    }
  }

  return steps;
}

function collectChanges(
  before: Cell[],
  after: Cell[],
  make: (i: number) => DeducedCell,
): DeducedCell[] {
  const cells: DeducedCell[] = [];
  for (let i = 0; i < before.length; i++) {
    if (before[i] === UNKNOWN && after[i] !== UNKNOWN) cells.push(make(i));
  }
  return cells;
}

function describe(cells: DeducedCell[]): string {
  const fills = cells.filter((c) => c.value === FILLED).length;
  const empties = cells.length - fills;
  const parts: string[] = [];
  if (fills) parts.push(`fill ${fills}`);
  if (empties) parts.push(`cross ${empties}`);
  return parts.join(", ");
}
