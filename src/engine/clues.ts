import type { Clue } from "./types";

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
