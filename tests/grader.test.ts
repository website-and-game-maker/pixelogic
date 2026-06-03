import { describe, it, expect } from "vitest";
import { grade } from "../src/engine/grader";
import { cluesForGrid } from "../src/engine/clues";

function bits(rows: string[]) {
  return rows.map((r) => [...r].map((c) => c === "#"));
}

const DIFFS = ["easy", "medium", "hard", "expert"] as const;

describe("grade", () => {
  it("grades a trivially line-solvable small puzzle as easy or medium", () => {
    const { rowClues, colClues } = cluesForGrid(bits(["##", "##"]));
    expect(["easy", "medium"]).toContain(grade(rowClues, colClues));
  });

  it("returns a valid difficulty for a larger line-solvable puzzle", () => {
    const { rowClues, colClues } = cluesForGrid(
      bits(["#.#.#", ".###.", "#####", ".###.", "#.#.#"]),
    );
    expect(DIFFS).toContain(grade(rowClues, colClues));
  });

  it("classifies a non-line-solvable puzzle as hard or expert", () => {
    // checkerboard ambiguity is not line-solvable
    const rowClues = [[1], [1]];
    const colClues = [[1], [1]];
    expect(["hard", "expert"]).toContain(grade(rowClues, colClues));
  });
});
