// Sharing helpers: build a deep link to a puzzle and offer a native share sheet
// with a clipboard fallback. Pure-ish (touches navigator/clipboard only).

import type { Puzzle } from "../engine/types";
import { encodePuzzle } from "./shareCodec";

/** A shareable URL that reopens this exact puzzle. Library puzzles use their id;
 *  everything else is encoded into a self-contained token link. */
export function puzzleLink(puzzle: Puzzle, fromLibrary: boolean): string {
  const base = `${location.origin}${location.pathname}`;
  if (fromLibrary) return `${base}#/play/${encodeURIComponent(puzzle.id)}`;
  const token = encodePuzzle(puzzle.solution, puzzle.title);
  return `${base}#/p/${token}`;
}

export type ShareOutcome = "shared" | "copied" | "failed";

/** A link to the app itself (the menu). */
export function appLink(): string {
  return `${location.origin}${location.pathname}`;
}

/** Share the player's overall Pixelogic Score, disclosing a progress reset (#16). */
export function shareScore(opts: {
  score: number;
  title: string;
  solved: number;
  total: number;
  wasReset: boolean;
}): Promise<ShareOutcome> {
  const resetNote = opts.wasReset ? " (progress was reset at least once)" : "";
  const text = `My Pixelogic Score is ${opts.score.toLocaleString()}/1600 — ${opts.title} (${opts.solved}/${opts.total} solved)${resetNote}. ▦ Can you beat it?`;
  return shareResult(text, appLink());
}

/** Try the native share sheet first (mobile), then fall back to the clipboard. */
export async function shareResult(text: string, url: string): Promise<ShareOutcome> {
  const nav = navigator as Navigator & { share?: (d: ShareData) => Promise<void> };
  if (typeof nav.share === "function") {
    try {
      await nav.share({ title: "Pixelogic", text, url });
      return "shared";
    } catch (err) {
      // AbortError == user dismissed the sheet; don't fall through to clipboard.
      if (err instanceof DOMException && err.name === "AbortError") return "failed";
    }
  }
  try {
    await navigator.clipboard.writeText(`${text} ${url}`);
    return "copied";
  } catch {
    return "failed";
  }
}
