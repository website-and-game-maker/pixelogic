import { UNKNOWN, FILLED, EMPTY, type Cell, type Clue } from "../engine/types";
import { cluesForLine, satisfiedClueParts } from "../engine/clues";
import type { ClueStyle } from "./persistence";
import { el } from "./dom";

export type CellView = "filled" | "cross" | "empty";

export interface BoardConfig {
  width: number;
  height: number;
  rowClues: Clue[];
  colClues: Clue[];
  getCell: (r: number, c: number) => CellView;
  isMistake?: (r: number, c: number) => boolean;
  /** How to draw a clue once its line's filled runs match it ("none" = unchanged). */
  satisfiedStyle?: ClueStyle;
  /** Adds button semantics + data attributes used by input handling. */
  interactive?: boolean;
  /** Accessible name for the grid (interactive boards). */
  gridLabel?: string;
}

function cellLabel(r: number, c: number, view: CellView): string {
  const state = view === "filled" ? ", filled" : view === "cross" ? ", crossed" : "";
  return `Row ${r + 1}, column ${c + 1}${state}`;
}

export interface Board {
  element: HTMLElement;
  cellsEl: HTMLElement;
  refresh(): void;
  destroy(): void;
}

/** The stack of numbers for one line, plus handles on each so individual
 *  numbers can be greyed as the player finishes them. */
function clueNumbers(clue: Clue): { wrap: HTMLElement; nums: HTMLElement[] } {
  const wrap = el("div", { class: "clue-stack" });
  const nums: HTMLElement[] = [];
  if (clue.length === 0) {
    wrap.append(el("span", { class: "clue-num clue-zero", text: "0" }));
  } else {
    for (const n of clue) {
      const span = el("span", { class: "clue-num", text: String(n) });
      wrap.append(span);
      nums.push(span);
    }
  }
  return { wrap, nums };
}

/** Build a board element with aligned clues and a refreshable cell grid. */
export function createBoard(config: BoardConfig): Board {
  const { width, height, rowClues, colClues } = config;

  const maxRowClue = Math.max(1, ...rowClues.map((c) => c.length));
  const maxColClue = Math.max(1, ...colClues.map((c) => c.length));

  // NB: CSS repeat() requires a *literal* count — a custom property only works as
  // the track size, not the repetition count — so the templates are set inline here.
  const colsTemplate = `repeat(${width}, var(--cell))`;
  const rowsTemplate = `repeat(${height}, var(--cell))`;

  const corner = el("div", { class: "board-corner" });

  const colCluesEl = el("div", { class: "col-clues", style: { gridTemplateColumns: colsTemplate } });
  const colClueEls: HTMLElement[] = [];
  const colNumEls: HTMLElement[][] = [];
  for (let c = 0; c < width; c++) {
    const { wrap, nums } = clueNumbers(colClues[c]);
    const cell = el("div", { class: "col-clue", dataset: { c: String(c) } }, [wrap]);
    if ((c + 1) % 5 === 0 && c + 1 < width) cell.classList.add("major-col");
    colCluesEl.append(cell);
    colClueEls.push(cell);
    colNumEls.push(nums);
  }

  const rowCluesEl = el("div", { class: "row-clues", style: { gridTemplateRows: rowsTemplate } });
  const rowClueEls: HTMLElement[] = [];
  const rowNumEls: HTMLElement[][] = [];
  for (let r = 0; r < height; r++) {
    const { wrap, nums } = clueNumbers(rowClues[r]);
    const cell = el("div", { class: "row-clue", dataset: { r: String(r) } }, [wrap]);
    if ((r + 1) % 5 === 0 && r + 1 < height) cell.classList.add("major-row");
    rowCluesEl.append(cell);
    rowClueEls.push(cell);
    rowNumEls.push(nums);
  }

  const cellsEl = el("div", {
    class: "board-cells",
    style: { gridTemplateColumns: colsTemplate, gridTemplateRows: rowsTemplate },
  });
  if (config.interactive) {
    cellsEl.setAttribute("role", "group");
    cellsEl.setAttribute("aria-label", config.gridLabel ?? "Puzzle grid");
  }
  const cellEls: HTMLElement[][] = [];
  for (let r = 0; r < height; r++) {
    const row: HTMLElement[] = [];
    for (let c = 0; c < width; c++) {
      const cell = el(config.interactive ? "button" : "div", {
        class: "cell",
        dataset: { r: String(r), c: String(c) },
        style: { ["--i" as string]: String(r * width + c) },
      });
      if (config.interactive) {
        cell.setAttribute("type", "button");
        cell.setAttribute("aria-label", cellLabel(r, c, "empty"));
        cell.setAttribute("aria-pressed", "false");
        cell.tabIndex = r === 0 && c === 0 ? 0 : -1; // roving tabindex
      }
      if ((c + 1) % 5 === 0 && c + 1 < width) cell.classList.add("major-col");
      if ((r + 1) % 5 === 0 && r + 1 < height) cell.classList.add("major-row");
      cellsEl.append(cell);
      row.push(cell);
    }
    cellEls.push(row);
  }

  const element = el(
    "div",
    {
      class: "board",
      style: {
        ["--cols" as string]: String(width),
        ["--rows" as string]: String(height),
        ["--max-row-clue" as string]: String(maxRowClue),
        ["--max-col-clue" as string]: String(maxColClue),
      },
    },
    [corner, colCluesEl, rowCluesEl, cellsEl],
  );

  function fitCell(): void {
    const availW = Math.min(window.innerWidth * 0.94, 620);
    const availH = Math.max(260, window.innerHeight * 0.6);
    const byW = availW / (width + 0.62 * maxRowClue);
    const byH = availH / (height + 0.62 * maxColClue);
    const size = Math.max(18, Math.min(64, Math.floor(Math.min(byW, byH) * 0.98)));
    element.style.setProperty("--cell", `${size}px`);
  }

  function refresh(): void {
    for (let r = 0; r < height; r++) {
      for (let c = 0; c < width; c++) {
        const view = config.getCell(r, c);
        const cell = cellEls[r][c];
        cell.classList.toggle("filled", view === "filled");
        cell.classList.toggle("cross", view === "cross");
        if (config.interactive) {
          cell.setAttribute("aria-label", cellLabel(r, c, view));
          cell.setAttribute("aria-pressed", view === "filled" ? "true" : "false");
        }
        if (config.isMistake) cell.classList.toggle("mistake", config.isMistake(r, c));
      }
    }
    // Clues have exactly two states: "done" (the line's filled runs match the
    // clue) and not-done (including a 0-clue line that wrongly has filled
    // cells). HOW a done clue is drawn (grey/strike/hide) is the board's
    // data-clue-style attribute, driven by the user's setting; "none" clears it.
    const style = config.satisfiedStyle ?? "none";
    element.dataset.clueStyle = style;
    if (style !== "none") {
      for (let r = 0; r < height; r++) {
        const line = Array.from({ length: width }, (_, c) => cellState(config.getCell(r, c)));
        const filled = line.map((s) => s === FILLED);
        rowClueEls[r].classList.toggle("done", clueEquals(cluesForLine(filled), rowClues[r]));
        markParts(rowNumEls[r], satisfiedClueParts(line, rowClues[r]));
      }
      for (let c = 0; c < width; c++) {
        const line = Array.from({ length: height }, (_, r) => cellState(config.getCell(r, c)));
        const filled = line.map((s) => s === FILLED);
        colClueEls[c].classList.toggle("done", clueEquals(cluesForLine(filled), colClues[c]));
        markParts(colNumEls[c], satisfiedClueParts(line, colClues[c]));
      }
    } else {
      for (const node of rowClueEls) node.classList.remove("done");
      for (const node of colClueEls) node.classList.remove("done");
      for (const nums of [...rowNumEls, ...colNumEls]) {
        for (const n of nums) n.classList.remove("done");
      }
    }
  }

  function markParts(nums: HTMLElement[], flags: boolean[]): void {
    for (let i = 0; i < nums.length; i++) nums[i].classList.toggle("done", flags[i] === true);
  }

  fitCell();
  refresh();
  window.addEventListener("resize", fitCell);

  return {
    element,
    cellsEl,
    refresh,
    destroy() {
      window.removeEventListener("resize", fitCell);
    },
  };
}

function clueEquals(a: Clue, b: Clue): boolean {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

/** A rendered cell back into the tri-state the clue logic reasons about. An
 *  un-marked cell is genuinely unknown — that's what stops a number greying
 *  while its run could still shift. */
function cellState(view: CellView): Cell {
  return view === "filled" ? FILLED : view === "cross" ? EMPTY : UNKNOWN;
}

/** Trigger the staggered win reveal animation on a board. */
export function playWinReveal(board: Board): void {
  board.element.classList.add("solved");
}
