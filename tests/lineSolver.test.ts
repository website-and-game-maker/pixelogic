import { describe, it, expect } from "vitest";
import { solveLine, lineFeasible } from "../src/engine/lineSolver";
import { UNKNOWN, FILLED, EMPTY } from "../src/engine/types";

const U = UNKNOWN,
  F = FILLED,
  E = EMPTY;

describe("solveLine", () => {
  it("fills a fully-determined line (clue == length)", () => {
    expect(solveLine([U, U, U], [3])).toEqual([F, F, F]);
  });
  it("marks an empty line", () => {
    expect(solveLine([U, U, U], [])).toEqual([E, E, E]);
  });
  it("forces the overlap of a long run", () => {
    // length 5, run of 4 -> the middle 3 cells are always filled
    expect(solveLine([U, U, U, U, U], [4])).toEqual([U, F, F, F, U]);
  });
  it("uses an existing fill to pin a run to the edge", () => {
    expect(solveLine([F, U, U, U, U], [2])).toEqual([F, F, E, E, E]);
  });
  it("returns null for an infeasible line", () => {
    expect(solveLine([F, E, F], [3])).toBeNull();
  });
  it("respects a crossed cell when placing two runs", () => {
    const r = solveLine([U, E, U, U], [1, 1]);
    expect(r).not.toBeNull();
    expect(r![0]).toBe(FILLED);
    expect(r![1]).toBe(EMPTY);
  });
  it("does not over-determine an ambiguous line", () => {
    // length 4, clue [1] -> nothing is forced (every cell could be the one)
    expect(solveLine([U, U, U, U], [1])).toEqual([U, U, U, U]);
  });
  it("completes a tightly packed multi-run line", () => {
    // length 5, clue [2,2] -> only one arrangement: ##.##
    expect(solveLine([U, U, U, U, U], [2, 2])).toEqual([F, F, E, F, F]);
  });
});

describe("lineFeasible", () => {
  it("true when an arrangement exists", () => {
    expect(lineFeasible([U, U, U], [1])).toBe(true);
  });
  it("false when clue cannot fit", () => {
    expect(lineFeasible([U, U], [3])).toBe(false);
  });
  it("false when runs cannot fit with required gaps", () => {
    expect(lineFeasible([U, U, U], [1, 1, 1])).toBe(false); // needs 5 cells
  });
  it("true for the empty clue on an all-unknown line", () => {
    expect(lineFeasible([U, U, U], [])).toBe(true);
  });
  it("false for the empty clue when a cell is filled", () => {
    expect(lineFeasible([U, F, U], [])).toBe(false);
  });
});
