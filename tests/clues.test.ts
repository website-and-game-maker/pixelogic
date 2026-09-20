import { describe, it, expect } from "vitest";
import { cluesForLine, cluesForGrid, satisfiedClueParts } from "../src/engine/clues";
import { UNKNOWN, FILLED, EMPTY, type Cell } from "../src/engine/types";

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

describe("satisfiedClueParts", () => {
  // 0 = unknown, 1 = filled, 2 = crossed
  const line = (s: string): Cell[] =>
    [...s].map((ch) => (ch === "#" ? FILLED : ch === "x" ? EMPTY : UNKNOWN)) as Cell[];

  it("greys a finished number while the rest of the line is untouched", () => {
    // "###" is closed by a cross; nothing after it is decided yet.
    expect(satisfiedClueParts(line("###x......"), [3, 2])).toEqual([true, false]);
  });

  it("greys a full-length run even when the player hasn't crossed after it", () => {
    // The clue forbids the run growing past 3, so the 3 is settled.
    expect(satisfiedClueParts(line("###......."), [3, 2])).toEqual([true, false]);
  });

  it("does not grey a run that is still too short", () => {
    expect(satisfiedClueParts(line("##........"), [3, 2])).toEqual([false, false]);
  });

  it("works inward from both ends at once", () => {
    expect(satisfiedClueParts(line("##x....x##"), [2, 3, 2])).toEqual([true, false, true]);
  });

  it("greys the whole chain once the line is complete", () => {
    expect(satisfiedClueParts(line("##x###x##x"), [2, 3, 2])).toEqual([true, true, true]);
  });

  it("refuses to guess when the leading cell is undecided", () => {
    // The "###" could still belong to either number — nothing is provable.
    expect(satisfiedClueParts(line(".###......"), [3, 3])).toEqual([false, false]);
  });

  it("stops at a wrong-length run instead of mismatching the rest", () => {
    expect(satisfiedClueParts(line("####x....."), [3, 2])).toEqual([false, false]);
  });

  it("never marks the same run for two different numbers", () => {
    // One closed run of 2 with everything else unknown: only the left 2 is safe.
    const flags = satisfiedClueParts(line("##x......."), [2, 2]);
    expect(flags).toEqual([true, false]);
  });

  it("handles an empty clue and an empty line", () => {
    expect(satisfiedClueParts(line("xxxxx"), [])).toEqual([]);
    expect(satisfiedClueParts(line("....."), [3])).toEqual([false]);
  });
});
