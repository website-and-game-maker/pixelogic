import { describe, it, expect } from "vitest";
import {
  propagate,
  countSolutions,
  solve,
  hasUniqueSolution,
  isLineSolvable,
} from "../src/engine/solver";
import { cluesForGrid } from "../src/engine/clues";
import { FILLED } from "../src/engine/types";

function gridFromBits(rows: string[]): boolean[][] {
  return rows.map((r) => [...r].map((ch) => ch === "#"));
}

describe("propagate / solve", () => {
  it("solves a simple line-solvable puzzle", () => {
    const sol = gridFromBits(["#.#", "###", "#.#"]);
    const { rowClues, colClues } = cluesForGrid(sol);
    const res = propagate(rowClues, colClues);
    expect(res.status).toBe("solved");
    const out = res.grid.map((row) => row.map((c) => c === FILLED));
    expect(out).toEqual(sol);
  });

  it("solve() returns the correct solution without search", () => {
    const sol = gridFromBits(["#.#", "###", "#.#"]);
    const { rowClues, colClues } = cluesForGrid(sol);
    const { solution, viaSearch } = solve(rowClues, colClues);
    expect(solution).toEqual(sol);
    expect(viaSearch).toBe(false);
  });

  it("isLineSolvable agrees with propagate", () => {
    const sol = gridFromBits(["#.#", "###", "#.#"]);
    const { rowClues, colClues } = cluesForGrid(sol);
    expect(isLineSolvable(rowClues, colClues)).toBe(true);
  });
});

describe("countSolutions / uniqueness", () => {
  it("reports exactly one solution for a well-formed puzzle", () => {
    const sol = gridFromBits(["#.#", "###", "#.#"]);
    const { rowClues, colClues } = cluesForGrid(sol);
    expect(countSolutions(rowClues, colClues)).toBe(1);
    expect(hasUniqueSolution(rowClues, colClues)).toBe(true);
  });

  it("detects the classic checkerboard ambiguity (>= 2 solutions)", () => {
    const rowClues = [[1], [1]];
    const colClues = [[1], [1]];
    expect(countSolutions(rowClues, colClues, 2)).toBe(2);
    expect(hasUniqueSolution(rowClues, colClues)).toBe(false);
  });

  it("solve() flags viaSearch on a non-line-solvable puzzle", () => {
    // Checkerboard ambiguity is not line-solvable; solve must search.
    const rowClues = [[1], [1]];
    const colClues = [[1], [1]];
    const { viaSearch } = solve(rowClues, colClues);
    expect(viaSearch).toBe(true);
  });
});
