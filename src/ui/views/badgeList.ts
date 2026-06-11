// Badge filter page (#3): every library puzzle carrying a given badge, grouped
// by difficulty (empty tiers hidden), with the standard header chrome so it
// feels like part of the game, not an orphaned list.

import type { Difficulty, Puzzle } from "../../engine/types";
import { LIBRARY, DIFFICULTY_ORDER } from "../../engine/puzzles";
import { puzzleBadges, BADGE_INFO, type BadgeKey } from "../../engine/badges";
import { el, mount } from "../dom";
import { difficultyMeta } from "../format";
import { libraryCard } from "../cards";
import { loadSave } from "../persistence";
import { navigate } from "../router";
import { DIFF_HEADING } from "./menu";

export function isBadgeKey(key: string): key is BadgeKey {
  return key === "symmetric" || key === "named" || key === "patterned";
}

export function renderBadgeList(host: HTMLElement, key: BadgeKey): void {
  const info = BADGE_INFO[key];
  const completed = new Set(loadSave().completed);

  const matches = LIBRARY.filter((p) => puzzleBadges(p).some((b) => b.key === key));

  function tierSection(d: Difficulty, puzzles: Puzzle[]): HTMLElement | null {
    if (puzzles.length === 0) return null; // don't show empty difficulty levels
    return el("section", { class: "menu-section" }, [
      el("h2", { class: "section-title" }, [
        el("span", { class: `chip ${difficultyMeta(d).className}`, text: DIFF_HEADING[d] }),
        el("span", { class: "subsection-count", text: `${puzzles.length}` }),
      ]),
      el("div", { class: "card-grid" }, puzzles.map((p) => libraryCard(p, completed))),
    ]);
  }

  const sections = DIFFICULTY_ORDER.map((d) =>
    tierSection(d, matches.filter((p) => p.difficulty === d)),
  ).filter((s): s is HTMLElement => s !== null);

  const view = el("div", { class: "view badge-list" }, [
    el("header", { class: "play-header" }, [
      el("button", { class: "btn ghost back-btn", text: "‹ Menu", on: { click: () => navigate("/") } }),
      el("div", { class: "play-title" }, [
        el("h1", { text: `${info.icon} ${info.name} puzzles` }),
        el("div", { class: "play-sub" }, [
          el("span", { class: `chip chip-badge chip-${key}`, text: `${matches.length} puzzles` }),
        ]),
      ]),
      el("div", { class: "header-spacer" }),
    ]),
    el("p", { class: "badge-blurb", text: info.blurb }),
    el("p", {
      class: "badge-scoring-note",
      text:
        info.multiplier < 1
          ? `Because they're a little easier, ${info.name} puzzles count slightly less toward your Pixelogic Score.`
          : `Because they're harder, ${info.name} puzzles count for more in your Pixelogic Score.`,
    }),
    ...sections,
    el("footer", { class: "menu-footer" }, [
      el("button", { class: "btn ghost", text: "‹ Back to all puzzles", on: { click: () => navigate("/") } }),
    ]),
  ]);

  mount(host, view);
}
