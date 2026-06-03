import { UNKNOWN, FILLED, EMPTY, type Cell, type Line, type Clue } from "./types";

/**
 * Feasibility predicate: can the runs `clue[clueIdx..]` be placed within
 * `state[pos..]` consistently with the cells already fixed in `state`?
 *
 * DP over (pos, clueIdx), memoized. At each position we either leave the cell
 * empty (forbidden if it is a fixed FILLED) or place the next run here (every
 * cell of the run must be allowed-filled, and the gap cell after it must be
 * allowed-empty).
 */
export function lineFeasible(state: Line, clue: Clue): boolean {
  const n = state.length;
  const k = clue.length;
  const memo = new Map<number, boolean>();

  function fits(pos: number, clueIdx: number): boolean {
    if (clueIdx === k) {
      for (let i = pos; i < n; i++) if (state[i] === FILLED) return false;
      return true;
    }
    if (pos >= n) return false;

    const key = pos * (k + 1) + clueIdx;
    const cached = memo.get(key);
    if (cached !== undefined) return cached;

    let result = false;
    const run = clue[clueIdx];

    // Option A: leave cell `pos` empty (only if it isn't a fixed FILLED).
    if (state[pos] !== FILLED && fits(pos + 1, clueIdx)) {
      result = true;
    }

    // Option B: place the run starting at `pos`.
    if (!result && pos + run <= n) {
      let ok = true;
      for (let i = pos; i < pos + run; i++) {
        if (state[i] === EMPTY) {
          ok = false;
          break;
        }
      }
      const after = pos + run;
      if (ok && after < n && state[after] === FILLED) ok = false;
      if (ok) {
        const nextPos = after < n ? after + 1 : after; // skip the mandatory gap
        if (fits(nextPos, clueIdx + 1)) result = true;
      }
    }

    memo.set(key, result);
    return result;
  }

  return fits(0, 0);
}

/**
 * Return a new line in which every cell that is FILLED in all valid completions
 * is set to FILLED, every cell EMPTY in all valid completions is set to EMPTY,
 * and the rest stay UNKNOWN. Returns `null` if the line is infeasible.
 */
export function solveLine(state: Line, clue: Clue): Line | null {
  if (!lineFeasible(state, clue)) return null;
  const n = state.length;
  const out: Cell[] = state.slice();
  for (let i = 0; i < n; i++) {
    if (out[i] !== UNKNOWN) continue;
    const tryFilled = state.slice();
    tryFilled[i] = FILLED;
    const tryEmpty = state.slice();
    tryEmpty[i] = EMPTY;
    const canFill = lineFeasible(tryFilled, clue);
    const canEmpty = lineFeasible(tryEmpty, clue);
    if (canFill && !canEmpty) out[i] = FILLED;
    else if (!canFill && canEmpty) out[i] = EMPTY;
  }
  return out;
}
