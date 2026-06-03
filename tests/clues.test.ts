import { describe, it, expect } from "vitest";
import { cluesForLine, cluesForGrid } from "../src/engine/clues";

describe("cluesForLine", () => {
  it("encodes runs of filled cells", () => {
    expect(cluesForLine([true, true, false, true])).toEqual([2, 1]);
  });
  it("returns [] for an empty line", () => {
    expect(cluesForLine([false, false, false])).toEqual([]);
  });
  it("returns [n] for a full line", () => {
    expect(cluesForLine([true, true, true])).toEqual([3]);
  });
  it("handles leading and trailing fills", () => {
    expect(cluesForLine([true, false, false, true, true])).toEqual([1, 2]);
  });
});

describe("cluesForGrid", () => {
  it("derives row and column clues", () => {
    const g = [
      [true, false],
      [true, true],
    ];
    const { rowClues, colClues } = cluesForGrid(g);
    expect(rowClues).toEqual([[1], [2]]);
    expect(colClues).toEqual([[2], [1]]);
  });
  it("handles an empty grid", () => {
    expect(cluesForGrid([])).toEqual({ rowClues: [], colClues: [] });
  });
});
