# Pixelogic

A nonogram (picross) logic-puzzle game. Players deduce a hidden pixel-art picture
from the run-length number clues on each row and column. Includes a rigorous logic
engine (line solver, full solver, uniqueness proof, difficulty grader), a generator
that only ships puzzles solvable by pure logic, a hint engine that explains *why* a
cell is forced, and a custom puzzle editor.

## Project type
- TypeScript + Vite (static single-page app, no backend)
- Vitest for unit tests (the logic engine is the heavily-tested core)
- Deployed to GitHub Pages via GitHub Actions (`.github/workflows/deploy.yml`)

## Layout
- `src/engine/` — pure, DOM-free logic. The heart of the project.
  - `types.ts` — shared types (Grid, Clue, Puzzle, CellState, …)
  - `clues.ts` — derive row/column clues from a solution grid
  - `lineSolver.ts` — given one line's clue + partial state, return forced cells
  - `solver.ts` — propagate line logic to a fixpoint; search for uniqueness
  - `grader.ts` — classify a puzzle's difficulty by the hardest technique needed
  - `generator.ts` — build/verify puzzles that are uniquely logic-solvable
  - `puzzles.ts` — curated puzzle library
- `src/ui/` — DOM rendering, input handling, game state, persistence
- `src/main.ts` — app entry point
- `tests/` — Vitest specs

## Constraints / decisions
- Pure client-side; everything must work as static files under `/pixelogic/`.
- `vite.config.ts` `base` is `/pixelogic/` (the GitHub Pages project path).
- The engine must never ship a puzzle that isn't provably uniquely solvable by logic.
- Design direction: fun-but-modern, baby-blue / turquoise-green, round corners,
  generous whitespace, crisp typography, gentle shadows. Spacing-first — no cramped
  cells or awkward click targets.

## Setup / run
```bash
npm install        # install dependencies
npm run dev        # local dev server (http://localhost:5173/pixelogic/)
npm test           # run the unit test suite
npm run build      # typecheck + production build into dist/
npm run preview    # serve the production build locally
```

## How to Continue
- The design spec lives at `docs/superpowers/specs/2026-06-03-pixelogic-design.md`.
- The implementation plan lives at `docs/superpowers/plans/` (created via writing-plans).
- Engine is built test-first. Run `npm test` before and after changes.
- Pushing to `main` triggers the Pages deploy workflow.
