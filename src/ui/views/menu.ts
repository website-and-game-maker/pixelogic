import type { Puzzle, Difficulty } from "../../engine/types";
import { LIBRARY, DIFFICULTY_ORDER } from "../../engine/puzzles";
import { isSymmetric } from "../../engine/symmetry";
import { scoreTitle } from "../../engine/scoring";
import { el, mount } from "../dom";
import { difficultyMeta, sizeLabel, formatTime } from "../format";
import {
  loadSave,
  deleteUserPuzzle,
  getBestTime,
  getPuzzleScore,
  getPixelogicScore,
  wasProgressReset,
} from "../persistence";
import { openSettings } from "../settings";
import { shareScore } from "../share";
import { navigate } from "../router";

const DIFF_HEADING: Record<Difficulty, string> = {
  easy: "Easy",
  medium: "Medium",
  hard: "Hard",
  expert: "Extra Hard",
  max: "Max",
};

function symmetricChip(p: Puzzle): HTMLElement | null {
  return isSymmetric(p.solution)
    ? el("span", { class: "chip chip-symmetry", text: "◈ Symmetric" })
    : null;
}

export function renderMenu(host: HTMLElement): void {
  const save = loadSave();
  const completed = new Set(save.completed);

  // ---- library card: score top-left, best time top-right ----
  function libraryCard(p: Puzzle): HTMLElement {
    const meta = difficultyMeta(p.difficulty);
    const done = completed.has(p.id);
    const sc = getPuzzleScore(p.id);
    const best = getBestTime(p.id);
    return el(
      "button",
      {
        class: `puzzle-card ${done ? "done" : ""}`,
        attrs: { type: "button", "aria-label": `Play ${p.title}${sc !== undefined ? `, best score ${sc}` : ""}` },
        on: { click: () => navigate(`/play/${encodeURIComponent(p.id)}`) },
      },
      [
        el("div", { class: "card-corners" }, [
          sc !== undefined
            ? el("span", { class: "score-pill", attrs: { title: "Best score" }, html: `<b>${sc}</b><i>/100</i>` })
            : el("span", { class: "score-pill empty", text: "—" }),
          best !== undefined
            ? el("span", { class: "time-pill", text: `⏱ ${formatTime(best)}` })
            : el("span", { class: "time-pill empty", text: done ? "✓" : "" }),
        ]),
        el("span", { class: "card-title", text: p.title }),
        el("div", { class: "card-foot" }, [
          el("div", { class: "card-chips" }, [el("span", { class: `chip ${meta.className}`, text: meta.label }), symmetricChip(p)]),
          el("span", { class: "card-size", text: sizeLabel(p.width, p.height) }),
        ]),
      ],
    );
  }

  // ---- custom card: editable + deletable, with manage-mode checkbox ----
  function customCard(p: Puzzle): HTMLElement {
    const meta = difficultyMeta(p.difficulty);
    const card = el(
      "button",
      {
        class: "puzzle-card custom",
        dataset: { id: p.id },
        attrs: { type: "button", "aria-label": `Play ${p.title}` },
        on: {
          click: () => {
            if (mySection.classList.contains("managing")) {
              checkbox.checked = !checkbox.checked;
              card.classList.toggle("selected", checkbox.checked);
            } else {
              navigate(`/play/${encodeURIComponent(p.id)}`);
            }
          },
        },
      },
      [
        el("div", { class: "card-corners" }, [
          el("span", { class: "card-icon mini", text: "▦" }),
          el("span", { class: "card-size", text: sizeLabel(p.width, p.height) }),
        ]),
        el("span", { class: "card-title", text: p.title }),
        el("div", { class: "card-foot" }, [
          el("div", { class: "card-chips" }, [el("span", { class: `chip ${meta.className}`, text: meta.label }), symmetricChip(p)]),
        ]),
      ],
    );
    const checkbox = el("input", {
      class: "card-select",
      attrs: { type: "checkbox", "aria-label": `Select ${p.title}` },
    }) as HTMLInputElement;
    checkbox.addEventListener("click", (e) => {
      e.stopPropagation();
      card.classList.toggle("selected", checkbox.checked);
    });
    const actions = el("div", { class: "card-actions" }, [
      actionIcon("✏️", `Edit ${p.title}`, "Edit", "card-action", () => navigate(`/editor/${encodeURIComponent(p.id)}`)),
      actionIcon("🗑", `Delete ${p.title}`, "Delete", "card-action danger", () => {
        if (card.classList.contains("confirm-delete")) {
          deleteUserPuzzle(p.id);
          renderMenu(host);
        } else {
          card.classList.add("confirm-delete");
          window.setTimeout(() => card.classList.remove("confirm-delete"), 2600);
        }
      }),
    ]);
    card.append(checkbox, actions, el("span", { class: "delete-hint", text: "Tap 🗑 again to delete" }));
    return card;
  }

  function section(title: string, puzzles: Puzzle[]): HTMLElement | null {
    if (puzzles.length === 0) return null;
    return el("section", { class: "menu-section" }, [
      el("h2", { class: "section-title", text: title }),
      el("div", { class: "card-grid" }, puzzles.map(libraryCard)),
    ]);
  }

  const sections: (HTMLElement | null)[] = DIFFICULTY_ORDER.map((d) =>
    section(DIFF_HEADING[d], LIBRARY.filter((p) => p.difficulty === d)),
  );

  // ---- My Puzzles (grouped by tier) with Manage / mass delete ----
  const mySection = el("section", { class: "menu-section my-puzzles" });
  if (save.userPuzzles.length > 0) {
    const groups = DIFFICULTY_ORDER.map((d) => ({ d, list: save.userPuzzles.filter((p) => p.difficulty === d) })).filter(
      (g) => g.list.length > 0,
    );
    const manageBtn = el("button", { class: "btn small", text: "Manage" });
    const delSelBtn = el("button", { class: "btn small danger", text: "Delete selected" });
    const delAllBtn = el("button", { class: "btn small danger", text: "Delete all" });
    const manageBar = el("div", { class: "manage-bar hidden" }, [delSelBtn, delAllBtn]);
    manageBtn.addEventListener("click", () => {
      const on = mySection.classList.toggle("managing");
      manageBtn.textContent = on ? "Done" : "Manage";
      manageBar.classList.toggle("hidden", !on);
    });
    delSelBtn.addEventListener("click", () => {
      const ids = selectedIds().filter(Boolean);
      if (ids.length === 0) return;
      ids.forEach((id) => deleteUserPuzzle(id));
      renderMenu(host);
    });
    delAllBtn.addEventListener("click", () => {
      if (delAllBtn.classList.contains("armed")) {
        for (const p of save.userPuzzles) deleteUserPuzzle(p.id);
        renderMenu(host);
      } else {
        delAllBtn.classList.add("armed");
        delAllBtn.textContent = "Tap again to delete ALL";
        window.setTimeout(() => {
          delAllBtn.classList.remove("armed");
          delAllBtn.textContent = "Delete all";
        }, 2600);
      }
    });

    mySection.append(
      el("div", { class: "section-head" }, [el("h2", { class: "section-title", text: "My Puzzles" }), manageBtn]),
      manageBar,
      ...groups.map((g) =>
        el("div", { class: "menu-subsection" }, [
          el("h3", { class: "subsection-title" }, [
            el("span", { class: `chip ${difficultyMeta(g.d).className}`, text: DIFF_HEADING[g.d] }),
            el("span", { class: "subsection-count", text: `${g.list.length}` }),
          ]),
          el("div", { class: "card-grid" }, g.list.map(customCard)),
        ]),
      ),
    );
    sections.push(mySection);
  }

  function selectedIds(): string[] {
    return Array.from(mySection.querySelectorAll<HTMLElement>(".puzzle-card.selected")).map((c) => c.dataset.id ?? "");
  }

  // ---- adaptive Surprise me: jump to the player's frontier tier ----
  function surpriseId(): string {
    let frontier = 0;
    for (let i = 0; i < DIFFICULTY_ORDER.length; i++) {
      if (LIBRARY.some((p) => p.difficulty === DIFFICULTY_ORDER[i] && completed.has(p.id))) frontier = i;
    }
    const ft = DIFFICULTY_ORDER[frontier];
    const ftList = LIBRARY.filter((p) => p.difficulty === ft);
    const fullyCleared = ftList.length > 0 && ftList.every((p) => completed.has(p.id));
    const start = fullyCleared ? Math.min(frontier + 1, DIFFICULTY_ORDER.length - 1) : frontier;
    for (let i = start; i < DIFFICULTY_ORDER.length; i++) {
      const pool = LIBRARY.filter((p) => p.difficulty === DIFFICULTY_ORDER[i] && !completed.has(p.id));
      if (pool.length) return pool[Math.floor(Math.random() * pool.length)].id;
    }
    const unsolved = LIBRARY.filter((p) => !completed.has(p.id));
    const pool = unsolved.length ? unsolved : LIBRARY;
    return pool[Math.floor(Math.random() * pool.length)].id;
  }

  const pix = getPixelogicScore();
  const progressLine =
    completed.size > 0
      ? `${completed.size} of ${LIBRARY.length} solved`
      : "Pick a puzzle and deduce the hidden picture from the number clues.";

  const view = el("div", { class: "view menu" }, [
    el("div", { class: "menu-tools" }, [
      el("button", {
        class: "icon-btn",
        text: "🎓",
        attrs: { type: "button", "aria-label": "How to play tutorial", title: "How to play" },
        on: { click: () => navigate("/tutorial") },
      }),
      el("button", {
        class: "icon-btn",
        text: "⚙",
        attrs: { type: "button", "aria-label": "Settings", title: "Settings" },
        on: { click: () => openSettings("home", () => renderMenu(host)) },
      }),
    ]),
    el("header", { class: "menu-header" }, [
      el("div", { class: "brand" }, [el("span", { class: "logo", text: "▦" }), el("h1", { text: "Pixelogic" })]),
      el("div", { class: "pixelogic-score", attrs: { role: "group", "aria-label": `Pixelogic Score ${pix} of 1600` } }, [
        el("span", { class: "laurel", text: "🌿" }),
        el("div", { class: "score-core" }, [
          el("span", { class: "score-value", text: pix.toLocaleString() }),
          el("span", { class: "score-cap", text: "/ 1600" }),
          el("span", { class: "score-title", text: scoreTitle(pix) }),
        ]),
        el("span", { class: "laurel flip", text: "🌿" }),
      ]),
      el("button", {
        class: "btn small score-share",
        text: "🔗 Share score",
        on: {
          click: (e) => {
            const btn = e.currentTarget as HTMLButtonElement;
            shareScore({
              score: pix,
              title: scoreTitle(pix),
              solved: completed.size,
              total: LIBRARY.length,
              wasReset: wasProgressReset(),
            }).then((outcome) => {
              if (outcome === "copied") {
                const old = btn.textContent;
                btn.textContent = "✓ Copied!";
                window.setTimeout(() => (btn.textContent = old), 1800);
              }
            });
          },
        },
      }),
      el("p", { class: "tagline", text: progressLine }),
      el("div", { class: "menu-actions" }, [
        el("button", { class: "btn primary", text: "✏️ Create your own", on: { click: () => navigate("/editor") } }),
        el("button", { class: "btn", text: "🎲 Surprise me", on: { click: () => navigate(`/play/${encodeURIComponent(surpriseId())}`) } }),
      ]),
    ]),
    ...sections.filter((s): s is HTMLElement => s !== null),
    el("footer", { class: "menu-footer" }, [
      el("p", { html: 'Every puzzle is <strong>provably solvable by logic alone</strong> — no guessing required.' }),
    ]),
  ]);

  mount(host, view);
}

/** A small icon affordance inside a puzzle card (mouse + keyboard activatable). */
function actionIcon(
  glyph: string,
  ariaLabel: string,
  title: string,
  className: string,
  onActivate: () => void,
): HTMLElement {
  const activate = (e: Event) => {
    e.stopPropagation();
    e.preventDefault();
    onActivate();
  };
  return el("span", {
    class: className,
    text: glyph,
    attrs: { role: "button", tabindex: "0", "aria-label": ariaLabel, title },
    on: {
      click: activate,
      keydown: (e) => {
        const ev = e as KeyboardEvent;
        if (ev.key === "Enter" || ev.key === " ") activate(e);
      },
    },
  });
}
