# Pixelogic

A calm, friendly **nonogram** (picross) logic-puzzle game. Deduce the hidden
pixel-art picture from the run-length number clues on each row and column — using
nothing but logic.

🎮 **Play:** https://pycoder42.github.io/pixelogic/

## Features
- A library of hand-crafted puzzles across sizes (5×5 → 15×15) and difficulties.
- A rigorous logic engine: every puzzle is **proven uniquely solvable by pure logic**.
- A **hint** that reveals the next forced cell *and explains the deduction*.
- A **"watch it solve"** mode that walks through the logical solution step by step.
- A **custom editor**: draw your own picture, auto-generate clues, prove uniqueness.
- Undo/redo, timer, mistake-check, autosave — and a satisfying reveal when you win.

## Tech
TypeScript + Vite, tested with Vitest, deployed to GitHub Pages via GitHub Actions.

```bash
npm install
npm run dev      # http://localhost:5173/pixelogic/
npm test
npm run build
```

## How it works
See [`docs/superpowers/specs/`](docs/superpowers/specs/) for the design and
[`Claude.md`](Claude.md) for the project map.
