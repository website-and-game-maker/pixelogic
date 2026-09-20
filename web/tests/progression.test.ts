import { describe, it, expect } from "vitest";
import type { Difficulty } from "../src/engine/types";
import { emptyTally, type AssistTally } from "../src/engine/scoring";
import {
  FAST_TUNING,
  STRUGGLE_TUNING,
  HINT_STRUGGLE_THRESHOLD,
  SPAM_THRESHOLD,
  applySignal,
  canDemote,
  classifySignal,
  curriculumNeighbour,
  curriculumOrder,
  defaultProgressionSettings,
  defaultProgressionState,
  recommend,
  smartNextTarget,
  type ProgressionPuzzle,
  type ProgressionSettings,
  type ProgressionState,
} from "../src/engine/progression";

const grid = (rows: string[]): boolean[][] => rows.map((r) => [...r].map((c) => c === "#"));
/** A plain 3×3 with no symmetry and no single-run lines, so it earns no badges. */
const PLAIN = ["#.#", "...", "#.."];

const pz = (
  id: string,
  difficulty: Difficulty,
  opts: { named?: boolean; rows?: string[] } = {},
): ProgressionPuzzle => ({
  id,
  difficulty,
  solution: grid(opts.rows ?? PLAIN),
  named: opts.named ?? false,
});

const settings = (patch: Partial<ProgressionSettings> = {}): ProgressionSettings => ({
  ...defaultProgressionSettings(),
  ...patch,
});
const state = (patch: Partial<ProgressionState> = {}): ProgressionState => ({
  ...defaultProgressionState(),
  ...patch,
});
const tally = (patch: Partial<AssistTally> = {}): AssistTally => ({ ...emptyTally(), ...patch });

/** easy×2, medium×2, hard×1 — deliberately shuffled so tier-major sorting shows. */
const LIB: ProgressionPuzzle[] = [
  pz("m1", "medium"),
  pz("e1", "easy"),
  pz("h1", "hard"),
  pz("e2", "easy"),
  pz("m2", "medium"),
];

describe("curriculum order", () => {
  it("is tier-major and stable within a tier", () => {
    expect(curriculumOrder(LIB).map((p) => p.id)).toEqual(["e1", "e2", "m1", "m2", "h1"]);
  });

  it("does not wrap at either end", () => {
    expect(curriculumNeighbour(LIB, "e1", -1)).toBeNull();
    expect(curriculumNeighbour(LIB, "h1", 1)).toBeNull();
    expect(curriculumNeighbour(LIB, "e1", 1)).toBe("e2");
    expect(curriculumNeighbour(LIB, "h1", -1)).toBe("m2");
  });

  it("returns null for an unknown puzzle", () => {
    expect(curriculumNeighbour(LIB, "nope", 1)).toBeNull();
  });
});

describe("signal classification", () => {
  const base = { solved: true, voided: false, elapsedMs: 1000, difficulty: "easy" as Difficulty, area: 9 };
  // easy par = 9 × 1.0s = 9000ms; normal fastFactor 0.6 ⇒ fast at ≤ 5400ms.

  it("treats a clean solve inside the fast window as fastClean", () => {
    expect(classifySignal({ ...base, assists: tally() }, settings())).toBe("fastClean");
  });

  it("treats a clean but slow solve as normal", () => {
    expect(classifySignal({ ...base, elapsedMs: 8000, assists: tally() }, settings())).toBe("normal");
  });

  it("requires a zero assist penalty for fastClean", () => {
    // Fast enough, but one square check means it is not mastery.
    expect(classifySignal({ ...base, assists: tally({ checkSquare: 1 }) }, settings())).toBe("normal");
  });

  it("ranks giving up above being fast", () => {
    expect(classifySignal({ ...base, voided: true, assists: tally() }, settings())).toBe("gaveUp");
    expect(classifySignal({ ...base, assists: tally({ voided: true }) }, settings())).toBe("gaveUp");
  });

  it("ranks a board check above being fast", () => {
    expect(classifySignal({ ...base, assists: tally({ checkBoard: 1 }) }, settings())).toBe("struggled");
  });

  it("counts heavy hint use as struggling, when enabled", () => {
    const heavy = tally({ hint: HINT_STRUGGLE_THRESHOLD });
    expect(classifySignal({ ...base, assists: heavy }, settings())).toBe("struggled");
    expect(classifySignal({ ...base, assists: heavy }, settings({ hintsCountAsStruggle: false }))).toBe("normal");
  });

  it("reports an unfinished attempt as abandoned", () => {
    expect(classifySignal({ ...base, solved: false, assists: tally() }, settings())).toBe("abandoned");
  });
});

describe("promotion", () => {
  const none = new Set<string>();

  it("needs consecutive fast solves", () => {
    const s = settings(); // normal ⇒ 2 in a row
    expect(FAST_TUNING[s.fastSensitivity].streak).toBe(2);
    let st = applySignal("fastClean", state(), s, LIB, none);
    expect(st.workingTier).toBe("easy");
    expect(st.fastStreak).toBe(1);
    st = applySignal("fastClean", st, s, LIB, none);
    expect(st.workingTier).toBe("medium");
    expect(st.fastStreak).toBe(0);
  });

  it("is reset by a normal solve in between", () => {
    const s = settings();
    let st = applySignal("fastClean", state(), s, LIB, none);
    st = applySignal("normal", st, s, LIB, none);
    expect(st.fastStreak).toBe(0);
    st = applySignal("fastClean", st, s, LIB, none);
    expect(st.workingTier).toBe("easy");
  });

  it("cannot climb past the top tier", () => {
    const s = settings();
    let st = state({ workingTier: "max" });
    st = applySignal("fastClean", st, s, LIB, none);
    st = applySignal("fastClean", st, s, LIB, none);
    expect(st.workingTier).toBe("max");
  });
});

describe("demotion", () => {
  it("holds on a single give-up, drops on the second", () => {
    const s = settings();
    expect(STRUGGLE_TUNING[s.struggleSensitivity].streak).toBe(2);
    let st = state({ workingTier: "hard" });
    st = applySignal("gaveUp", st, s, LIB, new Set());
    expect(st.workingTier).toBe("hard");
    st = applySignal("gaveUp", st, s, LIB, new Set());
    expect(st.workingTier).toBe("medium");
  });

  it("holds position when everything below is already cleared", () => {
    const cleared = new Set(["e1", "e2", "m1", "m2"]);
    expect(canDemote("hard", LIB, cleared)).toBe(false);
    let st = state({ workingTier: "hard" });
    const s = settings();
    st = applySignal("gaveUp", st, s, LIB, cleared);
    st = applySignal("gaveUp", st, s, LIB, cleared);
    expect(st.workingTier).toBe("hard");
  });

  it("still demotes when only the tier two below has work left", () => {
    const cleared = new Set(["m1", "m2"]); // medium done, easy not
    expect(canDemote("hard", LIB, cleared)).toBe(true);
  });

  it("never demotes below the lowest tier", () => {
    expect(canDemote("easy", LIB, new Set())).toBe(false);
  });

  it("treats struggling the same as giving up", () => {
    const s = settings({ struggleSensitivity: "quick" });
    const st = applySignal("struggled", state({ workingTier: "hard" }), s, LIB, new Set());
    expect(st.workingTier).toBe("medium");
  });
});

describe("autoAdjustDifficulty = false", () => {
  it("records streaks but never moves the tier", () => {
    const s = settings({ autoAdjustDifficulty: false });
    let st = applySignal("fastClean", state(), s, LIB, new Set());
    st = applySignal("fastClean", st, s, LIB, new Set());
    expect(st.workingTier).toBe("easy");
    expect(st.fastStreak).toBe(2);
  });
});

describe("recommendation", () => {
  const scores: Record<string, number> = {};

  it("prefers the working tier", () => {
    const r = recommend(state({ workingTier: "medium" }), LIB, new Set(), scores);
    expect(r?.puzzleId).toBe("m1");
    expect(r?.reason).toBe("Next up at your level.");
  });

  it("walks upward before downward", () => {
    // medium fully solved, both easy and hard still have work
    const done = new Set(["m1", "m2"]);
    const r = recommend(state({ workingTier: "medium" }), LIB, done, scores);
    expect(r?.puzzleId).toBe("h1");
    expect(r?.reason).toContain("moving you up");
  });

  it("falls back downward only when nothing above is left", () => {
    const done = new Set(["m1", "m2", "h1"]);
    const r = recommend(state({ workingTier: "medium" }), LIB, done, scores);
    expect(r?.puzzleId).toBe("e1");
    expect(r?.reason).toContain("Backing off");
  });

  it("switches to best improvement once the library is solved", () => {
    const all = new Set(LIB.map((p) => p.id));
    // e1 has the widest raw gap, but hard weighs 4× easy.
    const best = { e1: 0, e2: 100, m1: 100, m2: 100, h1: 50 };
    const r = recommend(state({ workingTier: "easy" }), LIB, all, best);
    expect(r?.puzzleId).toBe("h1"); // 50×4 = 200 beats 100×1 = 100
    expect(r?.reason).toContain("most score left");
  });

  it("weighs badge multipliers, not just the raw score gap", () => {
    const lib = [pz("plain", "hard"), pz("badged", "hard", { named: true })];
    const all = new Set(["plain", "badged"]);
    // Identical gap and tier; the Name-hint badge (×0.9) makes `badged` worth less.
    const r = recommend(state({ workingTier: "hard" }), lib, all, { plain: 40, badged: 40 });
    expect(r?.puzzleId).toBe("plain");
  });

  it("returns null for an empty library", () => {
    expect(recommend(state(), [], new Set(), {})).toBeNull();
  });

  it("can exclude a puzzle from every branch", () => {
    // m1 would win outright; excluded, it must fall to the next unsolved medium.
    const r = recommend(state({ workingTier: "medium" }), LIB, new Set(), scores, "m1");
    expect(r?.puzzleId).toBe("m2");
  });

  it("excludes from the best-improvement branch too", () => {
    const all = new Set(LIB.map((p) => p.id));
    const best = { e1: 0, e2: 100, m1: 100, m2: 100, h1: 50 };
    // h1 wins normally (50×4); excluded, e1 (100×1) takes it.
    const r = recommend(state({ workingTier: "easy" }), LIB, all, best, "h1");
    expect(r?.puzzleId).toBe("e1");
  });
});

describe("smart next", () => {
  const scores: Record<string, number> = {};

  it("uses the recommendation while under the spam threshold", () => {
    const r = smartNextTarget(state({ workingTier: "medium" }), "e1", settings(), LIB, new Set(), scores);
    expect(r?.puzzleId).toBe("m1");
  });

  it("never recommends the puzzle you are already on", () => {
    // Working tier medium, sitting on m1 — the obvious pick is where we already are.
    const r = smartNextTarget(state({ workingTier: "medium" }), "m1", settings(), LIB, new Set(), scores);
    expect(r?.puzzleId).not.toBe("m1");
    expect(r?.puzzleId).toBe("m2");
  });

  it("moves on even when the current puzzle is the only one left at the tier", () => {
    // Every medium but m1 is solved, and we're sitting on m1 → must look elsewhere.
    const done = new Set(["m2"]);
    const r = smartNextTarget(state({ workingTier: "medium" }), "m1", settings(), LIB, done, scores);
    expect(r?.puzzleId).toBe("h1");
  });

  it("degrades to plain curriculum order once spammed", () => {
    const spammed = state({ workingTier: "medium", spamCount: SPAM_THRESHOLD });
    const r = smartNextTarget(spammed, "e1", settings(), LIB, new Set(), scores);
    expect(r?.puzzleId).toBe("e2"); // next in order, not the recommendation
    expect(r?.reason).toBe("Next puzzle in order.");
  });

  it("is plain next when smart next is switched off", () => {
    const r = smartNextTarget(state({ workingTier: "medium" }), "e1", settings({ smartNext: false }), LIB, new Set(), scores);
    expect(r?.puzzleId).toBe("e2");
  });

  it("has nowhere to go past the last puzzle when plain", () => {
    const r = smartNextTarget(state(), "h1", settings({ smartNext: false }), LIB, new Set(), scores);
    expect(r).toBeNull();
  });

  it("clears the spam guard on any finished attempt", () => {
    const spammed = state({ spamCount: SPAM_THRESHOLD });
    expect(applySignal("normal", spammed, settings(), LIB, new Set()).spamCount).toBe(0);
    expect(applySignal("gaveUp", spammed, settings(), LIB, new Set()).spamCount).toBe(0);
    // ...but merely walking away is not a finished attempt.
    expect(applySignal("abandoned", spammed, settings(), LIB, new Set()).spamCount).toBe(SPAM_THRESHOLD);
  });
});

describe("sensitivity tuning constants", () => {
  it("maps each fast sensitivity to the contracted numbers", () => {
    expect(FAST_TUNING.relaxed).toEqual({ factor: 0.5, streak: 3 });
    expect(FAST_TUNING.normal).toEqual({ factor: 0.6, streak: 2 });
    expect(FAST_TUNING.eager).toEqual({ factor: 0.75, streak: 2 });
  });

  it("maps each struggle sensitivity to the contracted numbers", () => {
    expect(STRUGGLE_TUNING.forgiving).toEqual({ streak: 3 });
    expect(STRUGGLE_TUNING.normal).toEqual({ streak: 2 });
    expect(STRUGGLE_TUNING.quick).toEqual({ streak: 1 });
  });

  it("changes the fast window with sensitivity", () => {
    const base = { solved: true, voided: false, assists: tally(), difficulty: "easy" as Difficulty, area: 9 };
    // par 9000ms: relaxed ⇒ 4500, normal ⇒ 5400, eager ⇒ 6750
    expect(classifySignal({ ...base, elapsedMs: 5000 }, settings({ fastSensitivity: "relaxed" }))).toBe("normal");
    expect(classifySignal({ ...base, elapsedMs: 5000 }, settings({ fastSensitivity: "normal" }))).toBe("fastClean");
    expect(classifySignal({ ...base, elapsedMs: 6000 }, settings({ fastSensitivity: "normal" }))).toBe("normal");
    expect(classifySignal({ ...base, elapsedMs: 6000 }, settings({ fastSensitivity: "eager" }))).toBe("fastClean");
  });
});
