import { UNKNOWN, FILLED, EMPTY, type Puzzle } from "../../engine/types";
import { GameState } from "../gameState";
import { createBoard, playWinReveal, type CellView, type BoardConfig } from "../render";
import { attachInput } from "../input";
import { nextHint } from "../hints";
import { el, mount } from "../dom";
import { formatTime, difficultyMeta, sizeLabel } from "../format";
import {
  loadSave,
  getSettings,
  recordProgress,
  clearProgress,
  markCompleted,
  recordBestTime,
  setSettings,
} from "../persistence";
import { openSettings, openRules } from "../settings";
import { puzzleLink, shareResult } from "../share";
import { navigate } from "../router";
import { LIBRARY } from "../../engine/puzzles";

type Cleanup = () => void;

export interface PlayOptions {
  /** Built-in puzzle: enables completion tracking + "next puzzle". */
  fromLibrary: boolean;
  /** Set when test-playing an editor draft. Back/overlay return here (not Menu). */
  testReturn?: string;
}

/** Render the play view for a puzzle. */
export function renderPlay(host: HTMLElement, puzzle: Puzzle, opts: PlayOptions): Cleanup {
  const { fromLibrary, testReturn } = opts;
  const isTest = !!testReturn;
  const isCustomSaved = !fromLibrary && puzzle.id.startsWith("u-");

  const save = loadSave();
  const saved = save.progress[puzzle.id];
  const state = new GameState(
    puzzle,
    fromLibrary && saved ? saved.marks : undefined,
    fromLibrary && saved ? saved.elapsedMs : 0,
  );
  let settings = save.settings;
  let mistakeCheck = settings.mistakeCheck;
  let solved = false;
  let revealed = false;
  let saveTimer: number | null = null;

  const cellView = (r: number, c: number): CellView =>
    state.marks[r][c] === FILLED ? "filled" : state.marks[r][c] === EMPTY ? "cross" : "empty";

  // The config object is captured by the board and re-read on every refresh, so
  // mutating its fields (e.g. when settings change) takes effect on refresh().
  const boardConfig: BoardConfig = {
    width: puzzle.width,
    height: puzzle.height,
    rowClues: puzzle.rowClues,
    colClues: puzzle.colClues,
    getCell: cellView,
    isMistake: (r, c) => mistakeCheck && state.marks[r][c] === FILLED && !puzzle.solution[r][c],
    dimSatisfied: settings.highlightClues,
    interactive: true,
    gridLabel: `${puzzle.title} — ${puzzle.height} by ${puzzle.width} nonogram grid`,
  };
  const board = createBoard(boardConfig);
  const detachInput = attachInput(board, state);

  // ---- header ----
  const meta = difficultyMeta(puzzle.difficulty);
  const timerEl = el("span", { class: "timer", text: formatTime(state.elapsedMs()) });
  const timerWrap = el("div", { class: "timer-wrap" }, [timerEl]);

  const rulesBtn = el("button", {
    class: "icon-btn",
    text: "❔",
    attrs: { type: "button", "aria-label": "How to play", title: "How to play" },
    on: { click: () => openRules() },
  });
  const settingsBtn = el("button", {
    class: "icon-btn",
    text: "⚙",
    attrs: { type: "button", "aria-label": "Game settings", title: "Settings" },
    on: { click: () => openSettings("game", applySettings) },
  });

  const backLabel = isTest ? "‹ Editor" : "‹ Menu";
  const backBtn = el("button", {
    class: "btn ghost back-btn",
    text: backLabel,
    on: { click: goBack },
  });

  const header = el("header", { class: "play-header" }, [
    backBtn,
    el("div", { class: "play-title" }, [
      el("h1", { text: puzzle.title }),
      el("div", { class: "play-sub" }, [
        el("span", { class: `chip ${meta.className}`, text: meta.label }),
        el("span", { class: "chip muted", text: sizeLabel(puzzle.width, puzzle.height) }),
        isTest ? el("span", { class: "chip muted", text: "Test play" }) : null,
      ]),
    ]),
    el("div", { class: "play-tools" }, [rulesBtn, settingsBtn, timerWrap]),
  ]);

  // ---- banner (hints / messages / share) ----
  const banner = el("div", { class: "banner", attrs: { role: "status", "aria-live": "polite" } });

  // ---- controls ----
  const fillBtn = el("button", { class: "seg active", text: "✏️ Fill", attrs: { type: "button" } });
  const crossBtn = el("button", { class: "seg", text: "✕ Cross", attrs: { type: "button" } });
  fillBtn.addEventListener("click", () => state.setMode("fill"));
  crossBtn.addEventListener("click", () => state.setMode("cross"));
  const modeToggle = el("div", { class: "segmented", attrs: { role: "group", "aria-label": "Mark mode" } }, [
    fillBtn,
    crossBtn,
  ]);

  const undoBtn = el("button", { class: "btn", text: "↶ Undo", on: { click: () => state.undo() } });
  const redoBtn = el("button", { class: "btn", text: "↷ Redo", on: { click: () => state.redo() } });

  const hintBtn = el("button", { class: "btn", text: "💡 Hint", on: { click: showHint } });

  const mistakeBtn = el("button", {
    class: `btn toggle ${mistakeCheck ? "on" : ""}`,
    text: "🔎 Check mistakes",
    on: {
      click: () => {
        mistakeCheck = !mistakeCheck;
        setSettings({ mistakeCheck });
        mistakeBtn.classList.toggle("on", mistakeCheck);
        board.refresh();
      },
    },
  });

  const explainBtn = el("button", {
    class: "btn",
    text: "🧠 Watch solve",
    on: { click: () => navigate(`/explain/${encodeURIComponent(puzzle.id)}`) },
  });

  const solveBtn = el("button", {
    class: "btn ghost",
    text: "Reveal",
    on: { click: revealSolution },
  });

  const restartBtn = el("button", {
    class: "btn ghost",
    text: "↺ Restart",
    on: { click: restart },
  });

  const controls = el("div", { class: "controls" }, [
    modeToggle,
    el("div", { class: "control-group" }, [undoBtn, redoBtn]),
    el("div", { class: "control-group" }, [hintBtn, mistakeBtn]),
    el("div", { class: "control-group" }, [explainBtn, solveBtn, restartBtn]),
  ]);

  // ---- win overlay ----
  const winEmoji = el("div", { class: "win-emoji", text: "🎉" });
  const winHeading = el("h2", { text: "Solved!" });
  const winTime = el("p", { class: "win-time" });
  const winActions = el("div", { class: "win-actions" });
  const winClose = el("button", {
    class: "modal-close",
    text: "✕",
    attrs: { type: "button", "aria-label": "Close and admire the picture" },
    on: { click: closeWinOverlay },
  });
  const winCard = el("div", { class: "win-card" }, [winClose, winEmoji, winHeading, winTime, winActions]);
  const winOverlay = el(
    "div",
    {
      class: "win-overlay hidden",
      attrs: { role: "dialog", "aria-modal": "true", "aria-label": "Puzzle solved" },
    },
    [winCard],
  );

  const layout = el("div", { class: "view play" }, [
    header,
    el("div", { class: "board-wrap" }, [board.element]),
    banner,
    controls,
    winOverlay,
  ]);
  mount(host, layout);

  // ---- behaviour ----
  function goBack(): void {
    navigate(isTest ? testReturn! : "/");
  }

  function applySettings(): void {
    settings = getSettings();
    mistakeCheck = settings.mistakeCheck;
    mistakeBtn.classList.toggle("on", mistakeCheck);
    boardConfig.dimSatisfied = settings.highlightClues;
    timerWrap.classList.toggle("hidden", !settings.showTimer);
    board.refresh();
  }

  function refreshControls(): void {
    undoBtn.toggleAttribute("disabled", !state.canUndo());
    redoBtn.toggleAttribute("disabled", !state.canRedo());
    fillBtn.classList.toggle("active", state.mode === "fill");
    crossBtn.classList.toggle("active", state.mode === "cross");
  }

  function scheduleSave(): void {
    if (!fromLibrary || solved || revealed) return;
    if (saveTimer !== null) return; // coalesce a burst of changes into one write
    saveTimer = window.setTimeout(flushSave, 400);
  }
  function flushSave(): void {
    if (saveTimer !== null) {
      window.clearTimeout(saveTimer);
      saveTimer = null;
    }
    if (!fromLibrary || solved || revealed) return;
    recordProgress({ puzzleId: puzzle.id, marks: state.marks, elapsedMs: state.elapsedMs() });
  }
  function cancelSave(): void {
    if (saveTimer !== null) {
      window.clearTimeout(saveTimer);
      saveTimer = null;
    }
  }

  function onChange(): void {
    board.refresh();
    refreshControls();
    scheduleSave();
    if (!solved && state.isSolved()) handleWin();
  }
  state.subscribe(onChange);

  function showHint(): void {
    const hint = nextHint(puzzle, state.marks);
    if (!hint) {
      banner.textContent = state.isSolved() ? "Already solved! 🎉" : "No further logical step found.";
      return;
    }
    banner.textContent = `💡 ${hint.reason}`;
    const cell = board.cellsEl.querySelector<HTMLElement>(
      `.cell[data-r="${hint.row}"][data-c="${hint.col}"]`,
    );
    if (cell) {
      cell.classList.add("hinted");
      window.setTimeout(() => cell.classList.remove("hinted"), 1600);
    }
  }

  function revealSolution(): void {
    revealed = true;
    cancelSave();
    state.pause();
    state.batch(true, () => {
      for (let r = 0; r < puzzle.height; r++) {
        for (let c = 0; c < puzzle.width; c++) {
          state.setCell(r, c, puzzle.solution[r][c] ? FILLED : EMPTY, false);
        }
      }
    });
  }

  function restart(): void {
    revealed = false;
    solved = false;
    state.batch(true, () => {
      for (let r = 0; r < puzzle.height; r++) {
        for (let c = 0; c < puzzle.width; c++) state.setCell(r, c, UNKNOWN, false);
      }
    });
    cancelSave();
    if (fromLibrary) clearProgress(puzzle.id);
    banner.textContent = "";
    winOverlay.classList.add("hidden");
    board.element.classList.remove("solved");
    state.start();
  }

  function buildWinActions(): void {
    winActions.replaceChildren();
    const shareBtn = el("button", {
      class: "btn",
      text: "🔗 Share",
      on: { click: () => doShare(shareBtn) },
    });

    if (isTest) {
      winActions.append(
        el("button", {
          class: "btn primary",
          text: "‹ Back to editor",
          on: { click: () => navigate(testReturn!) },
        }),
        el("button", { class: "btn ghost", text: "Admire", on: { click: closeWinOverlay } }),
      );
      return;
    }

    if (!revealed) winActions.append(shareBtn);

    if (fromLibrary) {
      winActions.append(
        el("button", { class: "btn primary", text: "Next puzzle →", on: { click: goNext } }),
      );
    } else if (isCustomSaved) {
      winActions.append(
        el("button", {
          class: "btn primary",
          text: "✏️ Edit",
          on: { click: () => navigate(`/editor/${encodeURIComponent(puzzle.id)}`) },
        }),
      );
    }
    winActions.append(
      el("button", { class: "btn ghost", text: "Menu", on: { click: () => navigate("/") } }),
    );
  }

  function handleWin(): void {
    solved = true;
    state.pause();
    cancelSave();
    // Revealing the answer doesn't count as solving it.
    if (fromLibrary && !revealed) markCompleted(puzzle.id);
    playWinReveal(board);
    const elapsed = state.elapsedMs();
    if (revealed) {
      winTime.textContent = "Revealed";
    } else if (fromLibrary) {
      const { best, isNew } = recordBestTime(puzzle.id, elapsed);
      winTime.textContent = isNew
        ? `🏅 New best — ${formatTime(elapsed)}`
        : `Time ${formatTime(elapsed)} · Best ${formatTime(best)}`;
    } else {
      winTime.textContent = `Time: ${formatTime(elapsed)}`;
    }
    winHeading.textContent = revealed ? "Revealed" : "Solved!";
    winEmoji.textContent = revealed ? "🧩" : "🎉";
    // Keep the accessible names honest on the reveal path.
    winOverlay.setAttribute("aria-label", revealed ? "Solution revealed" : "Puzzle solved");
    winClose.setAttribute("aria-label", revealed ? "Close" : "Close and admire the picture");
    buildWinActions();
    window.setTimeout(() => {
      winOverlay.classList.remove("hidden");
      (winOverlay.querySelector(".win-actions .btn") as HTMLElement | null)?.focus();
    }, 650);
  }

  /** Esc closes the win dialog; Tab is trapped inside the card. */
  function onWinKey(e: KeyboardEvent): void {
    if (winOverlay.classList.contains("hidden")) return;
    if (e.key === "Escape") {
      e.preventDefault();
      closeWinOverlay();
      return;
    }
    if (e.key !== "Tab") return;
    const f = Array.from(
      winCard.querySelectorAll<HTMLElement>('button, [tabindex]:not([tabindex="-1"])'),
    ).filter((n) => !n.hasAttribute("disabled") && n.offsetParent !== null);
    if (f.length === 0) {
      e.preventDefault();
      return;
    }
    const first = f[0];
    const last = f[f.length - 1];
    const active = document.activeElement as HTMLElement | null;
    if (!winCard.contains(active)) {
      e.preventDefault();
      first.focus();
    } else if (e.shiftKey && active === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && active === last) {
      e.preventDefault();
      first.focus();
    }
  }
  document.addEventListener("keydown", onWinKey);

  /** Close the win popup to admire the finished picture; leave a share affordance. */
  function closeWinOverlay(): void {
    winOverlay.classList.add("hidden");
    banner.replaceChildren();
    if (revealed) {
      banner.textContent = "Revealed — try the next one!";
    } else {
      const msg = el("span", { text: `🎉 Solved in ${formatTime(state.elapsedMs())}. ` });
      const shareBtn = el("button", {
        class: "btn small",
        text: "🔗 Share result",
        on: { click: () => doShare(shareBtn) },
      });
      banner.append(msg, shareBtn);
    }
    // Always return focus to a stable, visible control (not the hidden ✕).
    backBtn.focus();
  }

  async function doShare(btn: HTMLElement): Promise<void> {
    const url = puzzleLink(puzzle, fromLibrary);
    const text = `I solved “${puzzle.title}” on Pixelogic in ${formatTime(state.elapsedMs())}! ▦ Can you?`;
    const outcome = await shareResult(text, url);
    if (outcome === "copied") {
      const old = btn.textContent;
      btn.textContent = "✓ Link copied!";
      window.setTimeout(() => (btn.textContent = old), 1800);
    } else if (outcome === "failed") {
      banner.textContent = "Couldn't open share — copy the link from the address bar.";
    }
  }

  function goNext(): void {
    const idx = LIBRARY.findIndex((p) => p.id === puzzle.id);
    const next = LIBRARY[(idx + 1) % LIBRARY.length];
    navigate(`/play/${encodeURIComponent(next.id)}`);
  }

  // timer tick
  applySettings();
  state.start();
  refreshControls();
  const tick = window.setInterval(() => {
    if (!solved) timerEl.textContent = formatTime(state.elapsedMs());
  }, 500);

  return () => {
    window.clearInterval(tick);
    document.removeEventListener("keydown", onWinKey);
    state.pause();
    flushSave();
    detachInput();
    board.destroy();
  };
}
