// Shared library-puzzle card: score pill (top-left), best time (top-right),
// title, then difficulty + clickable badge chips. Used by the menu and the
// badge filter pages.

import type { Puzzle } from "../engine/types";
import { puzzleBadges } from "../engine/badges";
import { el } from "./dom";
import { difficultyMeta, sizeLabel, formatTime } from "./format";
import { getBestTime, getPuzzleScore } from "./persistence";
import { navigate } from "./router";

/** A clickable badge chip linking to that badge's filter page. Cards are
 *  <button>s, so chips are spans with button semantics (no nested buttons). */
export function badgeChip(b: { key: string; label: string }): HTMLElement {
  const open = (e: Event): void => {
    e.stopPropagation();
    e.preventDefault();
    navigate(`/badge/${b.key}`);
  };
  return el("span", {
    class: `chip chip-badge chip-${b.key}`,
    text: b.label,
    attrs: { role: "button", tabindex: "0", "aria-label": `See all ${b.key} puzzles` },
    on: {
      click: open,
      keydown: (e) => {
        const ev = e as KeyboardEvent;
        if (ev.key === "Enter" || ev.key === " ") open(e);
      },
    },
  });
}

/** Card for a built-in library puzzle. */
export function libraryCard(p: Puzzle, completed: Set<string>): HTMLElement {
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
        el("div", { class: "card-chips" }, [
          el("span", { class: `chip ${meta.className}`, text: meta.label }),
          ...puzzleBadges(p).map(badgeChip),
        ]),
        el("span", { class: "card-size", text: sizeLabel(p.width, p.height) }),
      ]),
    ],
  );
}
