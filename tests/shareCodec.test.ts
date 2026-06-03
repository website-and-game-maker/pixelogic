import { describe, it, expect } from "vitest";
import { encodePuzzle, decodePuzzle } from "../src/ui/shareCodec";

describe("shareCodec", () => {
  it("round-trips a grid and title", () => {
    const solution = [
      [true, false, true],
      [false, true, false],
    ];
    const token = encodePuzzle(solution, "My Puzzle");
    const decoded = decodePuzzle(token);
    expect(decoded.solution).toEqual(solution);
    expect(decoded.title).toBe("My Puzzle");
  });

  it("produces a URL-safe token (no +, /, or =)", () => {
    const token = encodePuzzle([[true, true], [false, false]], "Tëst ✓ name");
    expect(token).not.toMatch(/[+/=]/);
  });

  it("handles unicode titles", () => {
    const token = encodePuzzle([[true]], "Café ☕");
    expect(decodePuzzle(token).title).toBe("Café ☕");
  });

  it("throws on malformed tokens", () => {
    expect(() => decodePuzzle("!!!not-base64!!!")).toThrow();
  });

  it("throws when the bit length disagrees with dimensions", () => {
    const bad = btoa(JSON.stringify({ w: 2, h: 2, t: "x", b: "1" }))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
    expect(() => decodePuzzle(bad)).toThrow();
  });
});
