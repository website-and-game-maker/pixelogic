# Clueweave

A nonogram (picross) logic-puzzle game — deduce a hidden picture from the
run-length number clues on each row and column. Free, offline, no ads, no
accounts, nothing collected.

**Play it:** https://website-and-game-maker.github.io/clueweave/

Every puzzle that ships is *proved* to have exactly one solution and to be
solvable by pure logic — no guessing is ever required.

## Repository layout

| Path | What it is |
|---|---|
| `web/` | The web app — TypeScript + Vite. Published to GitHub Pages. |
| `apple/` | The native port — `ClueweaveKit` engine plus iOS/iPad and watchOS apps. |

Both halves implement the same engine and must agree exactly on share tokens,
scoring, and difficulty. See `CLAUDE.md` for the rules that keep them in sync.

## Running it

```bash
cd web
npm install
npm run dev      # http://localhost:5173/clueweave/
npm test
npm run build
```

For the Apple side see [`apple/README.md`](apple/README.md).

## Authorship

Concept, engine, art, tests and docs were all created by Claude (Anthropic's AI)
in Claude Code. There is no human author.
