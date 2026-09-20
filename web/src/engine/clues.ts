import { UNKNOWN, FILLED, EMPTY, type Cell, type Clue } from "./types";

/** Run-length encode the filled runs of a line. `[]` for an all-empty line. */
export function cluesForLine(line: boolean[]): Clue {
  const clue: number[] = [];
  let run = 0;
  for (const filled of line) {
    if (filled) {
      run++;
    } else if (run > 0) {
      clue.push(run);
      run = 0;
    }
  }
  if (run > 0) clue.push(run);
  return clue;
}

/**
 * Which individual numbers in a clue the player has provably finished, so a chain
 * like "3 1 2" can grey its numbers one at a time instead of waiting for the whole
 * line to be done.
 *
 * Scans inward from both ends and stops at the first thing it can't be sure of.
 * A run only counts when it matches its clue number exactly AND is anchored: every
 * cell between it and the end it was matched from is already decided. That makes
 * the greying trustworthy — a number never goes grey while its run could still
 * turn out to belong somewhere else.
 *
 * A run bounded by an undecided cell still counts if it is already at full length,
 * because the clue forbids it from growing any further — but the scan stops there,
 * since nothing beyond it is pinned down yet.
 */
export function satisfiedClueParts(line: Cell[], clue: Clue): boolean[] {
  const done = clue.map(() => false);
  if (clue.length === 0) return done;
  const len = line.length;

  // ---- from the left ----
  let i = 0;
  let pos = 0;
  while (pos < len && i < clue.length) {
    const cell = line[pos];
    if (cell === UNKNOWN) break;
    if (cell === EMPTY) {
      pos++;
      continue;
    }
    let end = pos;
    while (end < len && line[end] === FILLED) end++;
    if (end - pos !== clue[i]) break; // wrong length — can't match this number
    done[i] = true;
    i++;
    const closed = end === len || line[end] === EMPTY;
    if (!closed) break; // full length but open-ended: stop before guessing further
    pos = end + 1;
  }
  const matchedFromLeft = i;

  // ---- from the right, never crossing what the left scan already claimed ----
  let j = clue.length - 1;
  let back = len - 1;
  while (back >= 0 && j >= matchedFromLeft) {
    const cell = line[back];
    if (cell === UNKNOWN) break;
    if (cell === EMPTY) {
      back--;
      continue;
    }
    let start = back;
    while (start >= 0 && line[start] === FILLED) start--;
    if (back - start !== clue[j]) break;
    done[j] = true;
    j--;
    const closed = start < 0 || line[start] === EMPTY;
    if (!closed) break;
    back = start - 1;
  }

  return done;
}

/** Derive row and column clues from a solution grid. */
export function cluesForGrid(solution: boolean[][]): {
  rowClues: Clue[];
  colClues: Clue[];
} {
  const height = solution.length;
  const width = height > 0 ? solution[0].length : 0;
  const rowClues = solution.map(cluesForLine);
  const colClues: Clue[] = [];
  for (let c = 0; c < width; c++) {
    const column: boolean[] = [];
    for (let r = 0; r < height; r++) column.push(solution[r][c]);
    colClues.push(cluesForLine(column));
  }
  return { rowClues, colClues };
}
