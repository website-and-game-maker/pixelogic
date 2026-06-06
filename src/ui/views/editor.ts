import type { Puzzle } from "../../engine/types";
import { cluesForGrid } from "../../engine/clues";
import { analyzeGrid } from "../../engine/generator";
import { createBoard, type Board } from "../render";
import { el, mount } from "../dom";
import { difficultyMeta } from "../format";
import { saveUserPuzzle, loadSave } from "../persistence";
import { encodePuzzle } from "../shareCodec";
import { setEditorDraft, clearEditorDraft, type EditorDraft } from "../editorDraft";
import { navigate } from "../router";

type Cleanup = () => void;

const SIZES = [5, 8, 10, 12, 15, 20];

export interface EditorOptions {
  /** Edit an existing custom puzzle by id. */
  editId?: string;
  /** Restore an in-progress draft (returning from Test). */
  restore?: EditorDraft;
}

export function renderEditor(host: HTMLElement, opts: EditorOptions = {}): Cleanup {
  // Resolve the starting state: restore draft > edit existing > blank.
  let editId: string | undefined;
  let startSolution: boolean[][] | undefined;
  let startTitle = "";

  if (opts.restore) {
    startSolution = opts.restore.solution.map((row) => row.slice());
    startTitle = opts.restore.title;
    editId = opts.restore.editId;
  } else if (opts.editId) {
    const existing = loadSave().userPuzzles.find((p) => p.id === opts.editId);
    if (existing) {
      startSolution = existing.solution.map((row) => row.slice());
      startTitle = existing.title;
      editId = existing.id;
    }
  } else {
    clearEditorDraft();
  }

  let width = startSolution?.[0]?.length ?? 10;
  let height = startSolution?.length ?? 10;
  let solution: boolean[][] =
    startSolution ?? Array.from({ length: height }, () => Array<boolean>(width).fill(false));

  let board: Board | null = null;
  let dragging = false;
  let paintVal = true;
  let unique = false;

  const boardWrap = el("div", { class: "board-wrap editor-board" });
  const verdict = el("div", { class: "verdict", attrs: { "aria-live": "polite" } });
  const guidance = el("p", { class: "verdict-guidance hidden" });
  const titleInput = el("input", {
    class: "title-input",
    attrs: { type: "text", placeholder: "Name your puzzle", maxlength: "40", value: startTitle },
  }) as HTMLInputElement;

  const sizeSelect = el("select", { class: "size-select", attrs: { "aria-label": "Grid size" } }) as HTMLSelectElement;
  for (const s of SIZES) {
    const opt = el("option", { text: `${s} × ${s}`, attrs: { value: String(s) } });
    if (s === width) opt.setAttribute("selected", "");
    sizeSelect.append(opt);
  }
  sizeSelect.addEventListener("change", () => {
    const s = Number(sizeSelect.value);
    width = height = s;
    solution = Array.from({ length: height }, () => Array<boolean>(width).fill(false));
    rebuild();
  });

  const saveBtn = el("button", { class: "btn primary", text: "💾 Save", on: { click: save } });
  const testBtn = el("button", { class: "btn", text: "▶ Test", on: { click: test } });
  const linkBtn = el("button", { class: "btn", text: "🔗 Copy link", on: { click: copyLink } });
  const clearBtn = el("button", { class: "btn ghost", text: "Clear", on: { click: clearGrid } });

  const view = el("div", { class: "view editor" }, [
    el("header", { class: "play-header" }, [
      el("button", { class: "btn ghost back-btn", text: "‹ Menu", on: { click: () => navigate("/") } }),
      el("div", { class: "play-title" }, [el("h1", { text: editId ? "Edit puzzle" : "Create a puzzle" })]),
      el("div", { class: "editor-size" }, [sizeSelect]),
    ]),
    el("p", { class: "editor-hint", text: "Tap or drag to draw. Clues and a uniqueness check update as you go." }),
    boardWrap,
    verdict,
    guidance,
    el("div", { class: "editor-form" }, [titleInput]),
    el("div", { class: "controls" }, [
      el("div", { class: "control-group" }, [saveBtn, testBtn, linkBtn]),
      el("div", { class: "control-group" }, [clearBtn]),
    ]),
    el("div", { class: "banner", attrs: { id: "editor-toast" } }),
  ]);
  mount(host, view);

  function cellFromPoint(x: number, y: number): [number, number] | null {
    if (!board) return null;
    const target = document.elementFromPoint(x, y) as HTMLElement | null;
    if (!target || !board.cellsEl.contains(target)) return null;
    const cell = target.closest<HTMLElement>(".cell");
    if (!cell || cell.dataset.r === undefined) return null;
    return [Number(cell.dataset.r), Number(cell.dataset.c)];
  }

  function paint(r: number, c: number, value: boolean): void {
    if (solution[r][c] === value) return;
    solution[r][c] = value;
    board?.cellsEl.querySelector<HTMLElement>(`.cell[data-r="${r}"][data-c="${c}"]`)?.classList.toggle("filled", value);
  }

  function onPointerDown(e: PointerEvent): void {
    const hit = cellFromPoint(e.clientX, e.clientY);
    if (!hit) return;
    e.preventDefault();
    const [r, c] = hit;
    paintVal = !solution[r][c];
    dragging = true;
    paint(r, c, paintVal);
  }
  function onPointerMove(e: PointerEvent): void {
    if (!dragging) return;
    const hit = cellFromPoint(e.clientX, e.clientY);
    if (hit) paint(hit[0], hit[1], paintVal);
  }
  function onPointerUp(): void {
    if (!dragging) return;
    dragging = false;
    rebuild();
  }

  window.addEventListener("pointermove", onPointerMove);
  window.addEventListener("pointerup", onPointerUp);

  function highlightAmbiguity(cell: { row: number; col: number } | undefined): void {
    board?.cellsEl.querySelectorAll(".ambiguous").forEach((n) => n.classList.remove("ambiguous"));
    if (cell) {
      board?.cellsEl
        .querySelector(`.cell[data-r="${cell.row}"][data-c="${cell.col}"]`)
        ?.classList.add("ambiguous");
    }
  }

  function rebuild(): void {
    board?.destroy();
    const { rowClues, colClues } = cluesForGrid(solution);
    board = createBoard({
      width,
      height,
      rowClues,
      colClues,
      getCell: (r, c) => (solution[r][c] ? "filled" : "empty"),
      interactive: false,
    });
    board.cellsEl.classList.add("drawable");
    board.cellsEl.addEventListener("pointerdown", onPointerDown);
    board.cellsEl.addEventListener("contextmenu", (e) => e.preventDefault());
    mount(boardWrap, board.element);
    analyze();
  }

  function filledCount(): number {
    return solution.reduce((sum, row) => sum + row.filter(Boolean).length, 0);
  }

  function analyze(): void {
    guidance.classList.add("hidden");
    if (filledCount() === 0) {
      verdict.className = "verdict empty";
      verdict.textContent = "Draw something to get started.";
      unique = false;
      saveBtn.toggleAttribute("disabled", true);
      testBtn.toggleAttribute("disabled", true);
      return;
    }
    verdict.className = "verdict checking";
    verdict.textContent = "Checking…";
    saveBtn.toggleAttribute("disabled", true);
    testBtn.toggleAttribute("disabled", false); // can always test-play your own drawing
    window.setTimeout(() => {
      const a = analyzeGrid(solution);
      unique = a.unique;
      if (a.unique) {
        verdict.className = "verdict unique";
        verdict.textContent = `✓ Unique — solvable by logic (${difficultyMeta(a.difficulty).label}).`;
        guidance.classList.add("hidden");
        highlightAmbiguity(undefined);
        saveBtn.toggleAttribute("disabled", false);
      } else {
        verdict.className = "verdict ambiguous";
        verdict.textContent = `⚠ Not unique — the clues match ${a.solutionCount}+ different pictures.`;
        guidance.classList.remove("hidden");
        if (a.ambiguity) {
          const { row, col } = a.ambiguity;
          guidance.textContent = `The highlighted cell (row ${row + 1}, column ${col + 1}) could be filled or empty under the same clues. Add or remove a filled cell near there — usually extending a run or breaking a symmetry — to pin the picture down. Save unlocks once there's exactly one solution.`;
          highlightAmbiguity(a.ambiguity);
        } else {
          guidance.textContent = "Adjust the picture so the clues allow only one solution — Save unlocks then.";
          highlightAmbiguity(undefined);
        }
        saveBtn.toggleAttribute("disabled", true);
      }
    }, 0);
  }

  function toast(msg: string): void {
    const t = view.querySelector<HTMLElement>("#editor-toast");
    if (t) t.textContent = msg;
  }

  function currentDraft(): EditorDraft {
    return { solution: solution.map((row) => row.slice()), title: titleInput.value.trim(), editId };
  }

  function buildPuzzle(id: string): Puzzle {
    const { rowClues, colClues } = cluesForGrid(solution);
    const { difficulty } = analyzeGrid(solution);
    return {
      id,
      title: titleInput.value.trim() || "My Puzzle",
      width,
      height,
      solution: solution.map((row) => row.slice()),
      rowClues,
      colClues,
      difficulty,
    };
  }

  function save(): void {
    if (!unique) return;
    const puzzle = buildPuzzle(editId ?? `u-${Date.now().toString(36)}`);
    saveUserPuzzle(puzzle);
    clearEditorDraft();
    navigate("/"); // back home so it's clear the puzzle was saved (no accidental re-saves)
  }

  function test(): void {
    setEditorDraft(currentDraft());
    navigate("/test");
  }

  async function copyLink(): Promise<void> {
    const token = encodePuzzle(solution, titleInput.value.trim() || "My Puzzle");
    const url = `${location.origin}${location.pathname}#/p/${token}`;
    try {
      await navigator.clipboard.writeText(url);
      toast("Link copied to clipboard!");
    } catch {
      toast(url);
    }
  }

  function clearGrid(): void {
    solution = Array.from({ length: height }, () => Array<boolean>(width).fill(false));
    rebuild();
  }

  rebuild();

  return () => {
    window.removeEventListener("pointermove", onPointerMove);
    window.removeEventListener("pointerup", onPointerUp);
    board?.destroy();
  };
}
