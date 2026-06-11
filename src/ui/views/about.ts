// About & FAQ (#5, #9): user-facing explanations of the game's mechanisms —
// concepts and "aha"s, not algorithms or tuning constants.

import { el, mount } from "../dom";
import { navigate } from "../router";

interface Section {
  icon: string;
  title: string;
  html: string;
}

const SECTIONS: Section[] = [
  {
    icon: "▦",
    title: "What is Pixelogic?",
    html: `<p>Pixelogic is a nonogram (picross) game: the numbers along each row and column
      describe the runs of filled cells in that line, and from those clues alone you can
      reconstruct a hidden pixel picture. Our promise is simple: <strong>every puzzle can be
      finished with certain logic — never a guess.</strong></p>`,
  },
  {
    icon: "🧠",
    title: "How do we know a puzzle never needs guessing?",
    html: `<p>Before a puzzle ships, the game plays it against itself — but with a twist: the
      built-in solver is only allowed moves a careful human could make. It stares at one line
      at a time and asks, <em>"across every possible way this clue could fit, which cells come
      out the same?"</em> Those cells are <strong>forced</strong> — undeniably true — and it
      marks them and repeats.</p>
      <p>Separately, a second check tries to find <em>two different pictures</em> that satisfy
      the same clues. If it can, the puzzle is rejected: you'd eventually face a coin-flip, and
      we don't do coin-flips. Only puzzles that pass both checks — exactly one solution,
      reachable by forced moves alone — make it into the library. The hint button and
      "watch solve" replay that same chain of forced moves, which is why a hint can always
      tell you <em>why</em> a cell is certain.</p>`,
  },
  {
    icon: "🌡",
    title: "How is difficulty decided?",
    html: `<p>Not by size! A big picture can be a pushover and a small one can be brutal.
      Instead, difficulty is measured by <strong>how hard the solver has to think</strong>:</p>
      <ul>
        <li>If single-line reasoning cracks the whole puzzle in a sweep or two, it's
          <strong>Easy</strong>. A few more sweeps back and forth — clues feeding into each
          other — and it's <strong>Medium</strong> or <strong>Hard</strong>.</li>
        <li>Some puzzles stall every line. The only way forward is a <em>what-if</em>: assume a
          cell, follow the consequences, and watch the assumption collapse into contradiction —
          proving the opposite. Puzzles that demand this are <strong>Extra Hard</strong>, and the
          ones that demand it over and over, across long lines, are <strong>MAX</strong>.</li>
      </ul>
      <p>Shapes also confess their secrets: a symmetric picture hands you half the answer, a
      patterned one mostly continues itself, and a title like "Heart" tells you where it's
      going. The grader knows, and caps or discounts those puzzles accordingly.</p>`,
  },
  {
    icon: "🌿",
    title: "The Pixelogic Score",
    html: `<p>Your Pixelogic Score (0–1,600) measures mastery of the whole library. Each puzzle
      contributes its best result, weighted by tier — a MAX puzzle moves your score roughly a
      dozen Easies' worth. Per puzzle, you score out of 100: solve at the puzzle's
      <strong>par time</strong> or faster with no help and it's a perfect 100; assists subtract
      according to how much they reveal (peeking at one square is a nick, revealing the whole
      board is a wound, and auto-completing the puzzle scores zero).</p>
      <p>Badges fine-tune the weighting: easier-badged puzzles (symmetric, patterned,
      tell-tale names) count a little less; a future harder badge would count more. And one
      matter of honour: if you ever reset your progress, your shared score says so.</p>`,
  },
  {
    icon: "🔗",
    title: "How do shared puzzles travel without a server?",
    html: `<p>There's no backend at all. When you share a custom puzzle, the picture itself is
      compressed and encoded <em>into the link</em> — the URL is the puzzle. Anyone opening it
      has the game rebuild the clues from the data in their own browser. Your progress, scores
      and creations live in your browser's local storage and never leave your device.</p>`,
  },
  {
    icon: "🤖",
    title: "Built entirely with AI",
    html: `<p>Every line of Pixelogic — the logic engine and its uniqueness prover, the
      difficulty grader, the scoring model, the puzzle art, the test suites, this very page —
      was designed and written by AI (Anthropic's Claude), steered by a human with opinions
      about how a logic game should feel. The collaboration worked like a studio: the human
      played, critiqued ("Hard is too easy", "the cat doesn't look like a cat"), and the AI
      measured, redesigned, and shipped. Even the puzzles were audited by the engine the AI
      wrote for it.</p>`,
  },
];

export function renderAbout(host: HTMLElement): void {
  const view = el("div", { class: "view about" }, [
    el("header", { class: "play-header" }, [
      el("button", { class: "btn ghost back-btn", text: "‹ Menu", on: { click: () => navigate("/") } }),
      el("div", { class: "play-title" }, [
        el("h1", { text: "About Pixelogic" }),
        el("div", { class: "play-sub" }, [el("span", { class: "chip muted", text: "How it all works" })]),
      ]),
      el("div", { class: "header-spacer" }),
    ]),
    ...SECTIONS.map((s, i) =>
      el("section", { class: "about-section", style: { ["--i" as string]: String(i) } }, [
        el("div", { class: "about-head" }, [
          el("span", { class: "about-icon", text: s.icon }),
          el("h2", { text: s.title }),
        ]),
        el("div", { class: "about-body", html: s.html }),
      ]),
    ),
    el("footer", { class: "menu-footer" }, [
      el("button", { class: "btn primary", text: "Play ▦", on: { click: () => navigate("/") } }),
    ]),
  ]);
  mount(host, view);
}
