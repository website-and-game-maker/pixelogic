import { describe, it, expect } from "vitest";
import { grade, gradeGrid } from "../src/engine/grader";
import { cluesForGrid } from "../src/engine/clues";
import { isLineSolvable } from "../src/engine/solver";
import { isSymmetric } from "../src/engine/symmetry";

function bits(rows: string[]) {
  return rows.map((r) => [...r].map((c) => c === "#"));
}

const DIFFS = ["easy", "medium", "hard", "expert", "max"] as const;

describe("grade", () => {
  it("grades a trivially line-solvable small puzzle as easy", () => {
    const { rowClues, colClues } = cluesForGrid(bits(["##", "##"]));
    expect(grade(rowClues, colClues)).toBe("easy");
  });

  it("returns a valid difficulty for a larger line-solvable puzzle", () => {
    const { rowClues, colClues } = cluesForGrid(
      bits(["#.#.#", ".###.", "#####", ".###.", "#.#.#"]),
    );
    expect(DIFFS).toContain(grade(rowClues, colClues));
  });

  it("does NOT over-grade a trivial non-line-solvable puzzle", () => {
    // A 2×2 with one filled cell per line is ambiguous (not line-solvable), but
    // the search space is tiny. The old grader called *anything* non-line-
    // solvable "expert"; the effort model correctly keeps this at the bottom.
    const rowClues = [[1], [1]];
    const colClues = [[1], [1]];
    expect(isLineSolvable(rowClues, colClues)).toBe(false);
    expect(grade(rowClues, colClues)).toBe("easy");
  });

  it("does not inflate a tiny puzzle just for needing a what-if (clue-only)", () => {
    // Letter A needs a contradiction proof, but on a 5×5 that proof is "look at
    // the two ways this can sit in a five-cell line". Weighting each what-if by
    // the longest line keeps it honest; a flat weight used to shove this two
    // whole tiers up. Judged on clues alone (no grid ⇒ no symmetry discount).
    const letterA = bits([".###.", "#...#", "#####", "#...#", "#...#"]);
    const { rowClues, colClues } = cluesForGrid(letterA);
    expect(isLineSolvable(rowClues, colClues)).toBe(false);
    expect(grade(rowClues, colClues)).toBe("medium");
  });
});

describe("gradeGrid", () => {
  it("grades a small symmetric contradiction picture as easy", () => {
    // Ground truth from playtesting: Letter A is *easy*. It is 25 cells, you can
    // hold the whole board in your head, and the mirror axis hands you half of
    // it. Two things used to over-grade it — a flat per-contradiction weight and
    // an easy ceiling that sat below every 5×5 — and between them they shipped a
    // trivial puzzle as Hard. Both are fixed; this test pins the outcome.
    const letterA = bits([".###.", "#...#", "#####", "#...#", "#...#"]);
    expect(isSymmetric(letterA)).toBe(true);
    expect(gradeGrid(letterA)).toBe("easy");
  });

  it("grades an irregular 10×10 with no shape discount as hard", () => {
    // The other half of the same playtest: Cat is hard. It is asymmetric and
    // unpatterned, so nothing discounts it, and 100 cells of real deduction is
    // genuinely more work than any 5×5 — which sweep-counting used to miss.
    const cat = bits([
      "#........#",
      "##......##",
      ".########.",
      ".#.####.#.",
      ".########.",
      ".########.",
      ".########.",
      ".#######..",
      ".#######.#",
      ".######.##",
    ]);
    expect(isSymmetric(cat)).toBe(false);
    expect(gradeGrid(cat)).toBe("hard");
  });

  it("leaves an asymmetric line-solvable picture below expert", () => {
    const cornerBlock = bits(["###..", "###..", "###..", ".....", "....."]);
    expect(isSymmetric(cornerBlock)).toBe(false);
    expect(["easy", "medium", "hard"]).toContain(gradeGrid(cornerBlock));
  });
});
