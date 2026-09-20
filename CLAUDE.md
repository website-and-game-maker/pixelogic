# Clueweave — project guide

A nonogram (picross) logic-puzzle game. Players deduce a hidden picture from the
run-length number clues on each row and column. Free, offline, no ads, no accounts.

This is **one repository with two halves**:

| Half | Path | What it is |
|---|---|---|
| **Web** | `web/` | TypeScript + Vite single-page app. **This is the only half GitHub Pages builds.** |
| **Apple** | `apple/` | Swift port: `ClueweaveKit` engine + iOS/iPad and watchOS apps. |

Each half keeps its own `CLAUDE.md` with the detail — read `web/CLAUDE.md` or
`apple/CLAUDE.md` for whichever you are working in.

## GitHub Pages

`.github/workflows/deploy.yml` builds **only `web/`** (`working-directory: web`,
artifact `web/dist`) and only runs when `web/**` changes. Changes confined to
`apple/` never trigger a deploy.

The Vite `base` is set from the repository name at build time
(`BASE_PATH: /${{ github.event.repository.name }}/`), so a project site always
gets the right asset paths — including after the repo is renamed. Locally the
default in `web/vite.config.ts` applies.

## What must stay identical across the two halves

The two engines are independent implementations of the same game. These are
**product**, not implementation detail — change one, change both in the same
commit, and update both test suites:

- share-token format (`shareCodec` / `ShareCodec`) — byte-compatible
- scoring, par times, assist penalties, badge thresholds
- difficulty cutoffs and the grading model (`grader.ts` / `Grader.swift`)
- the progression model — `web/docs/progression-model.md` is normative and is
  mirrored at `apple/docs/progression-model.md`

## Never reset a player's progress

Saves live on-device and are keyed by puzzle id. When a storage key has to
change, **migrate, don't rename**: read the legacy key, adopt it, then write the
new one. The Clueweave rename did exactly this — `clueweave.save.v1` is written
while `pixelogic.save.v1` is still read on first launch. Player-created and
generated puzzles must also survive `resetProgress()`.

Re-grading puzzles is safe for progress (ids are untouched) but does shift the
0–1600 overall score, since tier weights feed into it.

## Build gates

```bash
# Web
cd web && npm ci && npm test && npm run build

# Apple engine (works with bare Command Line Tools)
cd apple/ClueweaveKit && swift run clueweave-verify   # -> VERIFY OK
swift test                                            # needs the Xcode toolchain

# Apple apps (needs full Xcode + simulator runtimes)
cd apple && xcodegen generate
xcodebuild build -project Clueweave.xcodeproj -scheme Clueweave \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

## Authorship

The entire project — concept, engine, art, tests, and docs — was created by
Claude (Anthropic's AI) in Claude Code. There is no human author. Keep the About
screens consistent with this.
