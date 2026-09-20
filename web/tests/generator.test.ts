import { describe, it, expect } from "vitest";
import { bitmapToGrid, puzzleFromBitmap, analyzeGrid } from "../src/engine/generator";

describe("bitmapToGrid", () => {
  it("parses # and . into booleans", () => {
    expect(bitmapToGrid(["#.", ".#"])).toEqual([
      [true, false],
      [false, true],
    ]);
  });
  it("throws on ragged rows", () => {
    expect(() => bitmapToGrid(["##", "#"])).toThrow();
  });
  it("throws on empty input", () => {
    expect(() => bitmapToGrid([])).toThrow();
  });
});

describe("puzzleFromBitmap", () => {
  it("builds a uniquely-solvable puzzle with clues and a difficulty", () => {
    const { puzzle, unique } = puzzleFromBitmap(["#.#", "###", "#.#"], "X", "x1");
    expect(unique).toBe(true);
    expect(puzzle.width).toBe(3);
    expect(puzzle.height).toBe(3);
    expect(puzzle.rowClues.length).toBe(3);
    expect(puzzle.colClues.length).toBe(3);
    expect(["easy", "medium", "hard", "expert"]).toContain(puzzle.difficulty);
  });
  it("honors a forced difficulty", () => {
    const { puzzle } = puzzleFromBitmap(["##", "##"], "Block", "b", "hard");
    expect(puzzle.difficulty).toBe("hard");
  });
});

describe("analyzeGrid", () => {
  it("flags an ambiguous grid as not unique", () => {
    const a = analyzeGrid([
      [true, false],
      [false, true],
    ]);
    expect(a.unique).toBe(false);
    expect(a.solutionCount).toBeGreaterThanOrEqual(2);
  });
  it("confirms a well-formed grid is unique", () => {
    const a = analyzeGrid([
      [true, false, true],
      [true, true, true],
      [true, false, true],
    ]);
    expect(a.unique).toBe(true);
    expect(a.solutionCount).toBe(1);
  });
});
