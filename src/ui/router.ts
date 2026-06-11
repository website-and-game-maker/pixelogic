import type { Puzzle } from "../engine/types";
import { cluesForGrid } from "../engine/clues";
import { analyzeGrid } from "../engine/generator";
import { getPuzzle, LIBRARY } from "../engine/puzzles";
import { loadSave, isTutorialSeen } from "./persistence";
import { decodePuzzle } from "./shareCodec";
import { renderMenu } from "./views/menu";
import { renderPlay } from "./views/play";
import { renderEditor } from "./views/editor";
import { renderExplainer } from "./views/explainer";
import { renderTutorial } from "./views/tutorial";
import { renderAbout } from "./views/about";
import { renderBadgeList, isBadgeKey } from "./views/badgeList";
import { getEditorDraft } from "./editorDraft";

type Cleanup = () => void;

let host: HTMLElement;
let currentCleanup: Cleanup | null = null;

/** Navigate to an app path like "/play/heart". */
export function navigate(path: string): void {
  const target = `#${path}`;
  if (location.hash === target) render();
  else location.hash = target;
}

function findPuzzle(id: string): { puzzle: Puzzle; fromLibrary: boolean } | null {
  const lib = getPuzzle(id);
  if (lib) return { puzzle: lib, fromLibrary: true };
  const user = loadSave().userPuzzles.find((p) => p.id === id);
  if (user) return { puzzle: user, fromLibrary: false };
  return null;
}

function puzzleFromToken(token: string): Puzzle | null {
  try {
    const { solution, title } = decodePuzzle(token);
    const { rowClues, colClues } = cluesForGrid(solution);
    const { difficulty } = analyzeGrid(solution);
    return {
      id: "shared",
      title,
      width: solution[0].length,
      height: solution.length,
      solution,
      rowClues,
      colClues,
      difficulty,
    };
  } catch {
    return null;
  }
}

function render(): void {
  currentCleanup?.();
  currentCleanup = null;
  host.scrollTo?.({ top: 0 });
  window.scrollTo(0, 0);

  const raw = location.hash.replace(/^#/, "") || "/";
  const segments = raw.split("/").filter(Boolean);
  const [route, arg, arg2] = segments;

  // First-ever visit (no hash, tutorial never seen): redirect to the tutorial
  // route. Afterwards the bare URL just shows the menu — no #/ needed (#21).
  if (!route && !isTutorialSeen()) {
    navigate("/tutorial");
    return;
  }

  if (!route) {
    renderMenu(host);
    return;
  }
  if (route === "tutorial") {
    currentCleanup = renderTutorial(host);
    return;
  }
  if (route === "about") {
    renderAbout(host);
    return;
  }
  if (route === "badge" && arg && isBadgeKey(arg)) {
    renderBadgeList(host, arg);
    return;
  }
  if (route === "editor") {
    if (arg === "draft") {
      const draft = getEditorDraft();
      currentCleanup = renderEditor(host, draft ? { restore: draft } : undefined);
    } else if (arg) {
      currentCleanup = renderEditor(host, { editId: decodeURIComponent(arg) });
    } else {
      currentCleanup = renderEditor(host);
    }
    return;
  }
  if (route === "test") {
    const draft = getEditorDraft();
    if (draft) {
      const { rowClues, colClues } = cluesForGrid(draft.solution);
      const puzzle: Puzzle = {
        id: "draft",
        title: draft.title || "Your puzzle",
        width: draft.solution[0].length,
        height: draft.solution.length,
        solution: draft.solution,
        rowClues,
        colClues,
        difficulty: analyzeGrid(draft.solution).difficulty,
      };
      currentCleanup = renderPlay(host, puzzle, { fromLibrary: false, testReturn: "/editor/draft" });
      return;
    }
  }
  if (route === "play" && arg) {
    const found = findPuzzle(decodeURIComponent(arg));
    if (found) {
      currentCleanup = renderPlay(host, found.puzzle, { fromLibrary: found.fromLibrary });
      return;
    }
  }
  if (route === "explain" && arg) {
    const found = findPuzzle(decodeURIComponent(arg));
    if (found) {
      currentCleanup = renderExplainer(host, found.puzzle);
      return;
    }
  }
  if (route === "p" && arg) {
    // tokens can contain characters that survived the slash-split; rejoin.
    const token = arg2 ? `${arg}/${arg2}` : arg;
    const puzzle = puzzleFromToken(token);
    if (puzzle) {
      currentCleanup = renderPlay(host, puzzle, { fromLibrary: false });
      return;
    }
  }

  // Unknown / not found → menu.
  renderMenu(host);
}

export function startRouter(appHost: HTMLElement): void {
  host = appHost;
  window.addEventListener("hashchange", render);
  render();
}

export { LIBRARY };
