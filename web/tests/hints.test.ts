import { describe, it, expect } from "vitest";
import { nextHint } from "../src/ui/hints";
import { solveSteps } from "../src/ui/explainer";
import { getPuzzle } from "../src/engine/puzzles";
import { UNKNOWN, FILLED, EMPTY, type Cell } from "../src/engine/types";

const plus = getPuzzle("plus")!;

function emptyMarks(): Cell[][] {
  return Array.from({ length: plus.height }, () => Array<Cell>(plus.width).fill(UNKNOWN));
}

describe("nextHint", () => {
  it("returns a forced cell that matches the solution, with a reason", () => {
    const hint = nextHint(plus, emptyMarks());
    expect(hint).not.toBeNull();
    const correct = plus.solution[hint!.row][hint!.col] ? FILLED : EMPTY;
    expect(hint!.value).toBe(correct);
    expect(hint!.reason.length).toBeGreaterThan(0);
  });

  it("returns null when the board is already solved", () => {
    const marks = plus.solution.map((row) => row.map((b) => (b ? FILLED : EMPTY) as Cell));
    expect(nextHint(plus, marks)).toBeNull();
  });

  it("ignores a mistaken fill and still gives a valid deduction", () => {
    const marks = emptyMarks();
    marks[0][0] = FILLED; // wrong: plus has no fill at (0,0)
    const hint = nextHint(plus, marks);
    expect(hint).not.toBeNull();
    const correct = plus.solution[hint!.row][hint!.col] ? FILLED : EMPTY;
    expect(hint!.value).toBe(correct);
  });
});

describe("solveSteps", () => {
  it("reconstructs the full solution from ordered, non-empty steps", () => {
    const steps = solveSteps(plus);
    expect(steps.length).toBeGreaterThan(0);
    const grid = Array.from({ length: plus.height }, () =>
      Array<Cell>(plus.width).fill(UNKNOWN),
    );
    for (const step of steps) {
      expect(step.cells.length).toBeGreaterThan(0);
      for (const cell of step.cells) grid[cell.r][cell.c] = cell.value;
    }
    const asBool = grid.map((row) => row.map((c) => c === FILLED));
    expect(asBool).toEqual(plus.solution);
  });
});
