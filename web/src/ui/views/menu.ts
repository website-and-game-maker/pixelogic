import type { Puzzle, Difficulty } from "../../engine/types";
import { LIBRARY, DIFFICULTY_ORDER } from "../../engine/puzzles";
import { puzzleBadges } from "../../engine/badges";
import { recommend } from "../../engine/progression";
import { scoreTitle } from "../../engine/scoring";
import { el, mount } from "../dom";
import { difficultyMeta, sizeLabel } from "../format";
import { libraryCard, badgeChip } from "../cards";
import { loadSave, deleteUserPuzzle, getClueweaveScore, wasProgressReset } from "../persistence";
import { openSettings } from "../settings";
import { shareScore } from "../share";
import { navigate } from "../router";

export const DIFF_HEADING: Record<Difficulty, string> = {
  easy: "Easy",
  medium: "Medium",
  hard: "Hard",
  expert: "Extra Hard",
  max: "Max",
};

export function renderMenu(host: HTMLElement): void {
  const save = loadSave();
  const completed = new Set(save.completed);

  // ---- custom card: playable, editable, deletable, manage-mode selectable ----
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
          el("div", { class: "card-chips" }, [
            el("span", { class: `chip ${meta.className}`, text: meta.label }),
            ...puzzleBadges(p).map(badgeChip),
          ]),
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
      el("div", { class: "card-grid" }, puzzles.map((p) => libraryCard(p, completed))),
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
      const ids = Array.from(mySection.querySelectorAll<HTMLElement>(".puzzle-card.selected"))
        .map((c) => c.dataset.id ?? "")
        .filter(Boolean);
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

  // ---- Recommended puzzle ----
  // Replaces the old random "Surprise me". This names its pick and says why, so
  // the choice is legible rather than a dice roll. See docs/progression-model.md.
  const rec = recommend(save.progression, LIBRARY, completed, save.bestScores);
  const recPuzzle = rec ? LIBRARY.find((p) => p.id === rec.puzzleId) : undefined;
  const recommendBtn =
    rec && recPuzzle
      ? el(
          "button",
          {
            class: "btn recommend",
            attrs: {
              type: "button",
              "aria-label": `Recommended puzzle: ${recPuzzle.title}, ${difficultyMeta(recPuzzle.difficulty).label}. ${rec.reason}`,
            },
            on: { click: () => navigate(`/play/${encodeURIComponent(rec.puzzleId)}`) },
          },
          [
            el("span", { class: "rec-head", text: "🎯 Recommended puzzle" }),
            el("span", { class: "rec-pick" }, [
              el("span", { class: "rec-title", text: recPuzzle.title }),
              el("span", {
                class: `chip ${difficultyMeta(recPuzzle.difficulty).className}`,
                text: difficultyMeta(recPuzzle.difficulty).label,
              }),
            ]),
            el("span", { class: "rec-reason", text: rec.reason }),
          ],
        )
      : null;

  const pix = getClueweaveScore();
  const progressLine =
    completed.size > 0
      ? `${completed.size} of ${LIBRARY.length} solved`
      : "Pick a puzzle and deduce the hidden picture from the number clues.";

  const shareBtn = el("button", {
    class: "btn small score-share",
    text: "🔗 Share score",
    on: {
      click: () => {
        shareScore({
          score: pix,
          title: scoreTitle(pix),
          solved: completed.size,
          total: LIBRARY.length,
          wasReset: wasProgressReset(),
        }).then((outcome) => {
          if (outcome === "copied") {
            const old = shareBtn.textContent;
            shareBtn.textContent = "✓ Copied!";
            window.setTimeout(() => (shareBtn.textContent = old), 1800);
          }
        });
      },
    },
  });

  // Header order (#2): brand → tagline → Clueweave Score → actions, with the
  // action buttons sitting close to the first section's divider line.
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
        text: "ℹ",
        attrs: { type: "button", "aria-label": "About Clueweave", title: "About" },
        on: { click: () => navigate("/about") },
      }),
      el("button", {
        class: "icon-btn",
        text: "⚙",
        attrs: { type: "button", "aria-label": "Settings", title: "Settings" },
        on: { click: () => openSettings("home", () => renderMenu(host)) },
      }),
    ]),
    el("header", { class: "menu-header" }, [
      el("div", { class: "brand" }, [el("span", { class: "logo", text: "▦" }), el("h1", { text: "Clueweave" })]),
      el("p", { class: "tagline", text: progressLine }),
      el("div", { class: "score-block" }, [
        el("div", { class: "clueweave-score", attrs: { role: "group", "aria-label": `Clueweave Score ${pix} of 1600` } }, [
          el("span", { class: "laurel", text: "🌿" }),
          el("div", { class: "score-core" }, [
            el("span", { class: "score-value", text: pix.toLocaleString() }),
            el("span", { class: "score-cap", text: "/ 1600" }),
            el("span", { class: "score-title", text: scoreTitle(pix) }),
          ]),
          el("span", { class: "laurel flip", text: "🌿" }),
        ]),
        shareBtn,
      ]),
      el("div", { class: "menu-actions" }, [
        el("button", { class: "btn primary", text: "✏️ Create your own", on: { click: () => navigate("/editor") } }),
        recommendBtn,
      ]),
    ]),
    ...sections.filter((s): s is HTMLElement => s !== null),
    el("footer", { class: "menu-footer" }, [
      el("p", { html: 'Every puzzle is <strong>provably solvable by logic alone</strong> — no guessing required.' }),
      // Understated, website-style privacy link (About lives in the top toolbar,
      // so the old footer About link here was redundant — mirrors the iOS app).
      el("button", {
        class: "privacy-link",
        text: "Privacy Policy",
        attrs: { type: "button" },
        on: { click: () => navigate("/privacy") },
      }),
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
