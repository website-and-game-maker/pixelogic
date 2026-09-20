import { describe, it, expect } from "vitest";
import { LIBRARY, getPuzzle, byDifficulty } from "../src/engine/puzzles";
import { hasUniqueSolution, solve } from "../src/engine/solver";
import { isLogicSolvable } from "../src/engine/deduce";
import { gradeGrid } from "../src/engine/grader";

describe("puzzle library invariants", () => {
  it("ships a healthy number of puzzles", () => {
    expect(LIBRARY.length).toBeGreaterThanOrEqual(20);
  });

  it("has unique ids", () => {
    const ids = LIBRARY.map((p) => p.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("covers every difficulty tier", () => {
    expect(byDifficulty("easy").length).toBeGreaterThan(0);
    expect(byDifficulty("medium").length).toBeGreaterThan(0);
    expect(byDifficulty("hard").length).toBeGreaterThan(0);
    expect(byDifficulty("expert").length).toBeGreaterThan(0);
    expect(byDifficulty("max").length).toBeGreaterThan(0);
  });

  for (const p of LIBRARY) {
    describe(`"${p.title}" (${p.id})`, () => {
      it("has exactly one solution", () => {
        expect(hasUniqueSolution(p.rowClues, p.colClues)).toBe(true);
      });
      it("is solvable by logic and its stored tier matches the grader", () => {
        // Every puzzle is solvable without guessing (line logic + depth-1 contradiction).
        expect(isLogicSolvable(p.rowClues, p.colClues)).toBe(true);
        // Difficulty is derived from the grader, never hand-forced: the stored
        // tier must equal a fresh grade of the picture. Tier is a function of
        // solving *effort*, discounted by the information a symmetric/patterned
        // shape leaks — it is deliberately NOT tied to line-solvability, so a
        // small symmetric contradiction puzzle can be Medium and a heavy
        // symmetric 15×15 can be Extra Hard.
        expect(gradeGrid(p.solution)).toBe(p.difficulty);
      });
      it("the engine's solution matches the stored picture", () => {
        const { solution } = solve(p.rowClues, p.colClues);
        expect(solution).toEqual(p.solution);
      });
      it("clue counts match the grid dimensions", () => {
        expect(p.rowClues.length).toBe(p.height);
        expect(p.colClues.length).toBe(p.width);
      });
    });
  }
});

describe("getPuzzle", () => {
  it("finds a known puzzle", () => {
    expect(getPuzzle("heart")?.title).toBe("Heart");
  });
  it("returns undefined for an unknown id", () => {
    expect(getPuzzle("nope")).toBeUndefined();
  });
});
