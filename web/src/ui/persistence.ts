import type { Cell, Difficulty, Puzzle } from "../engine/types";
import { LIBRARY, DIFFICULTY_ORDER } from "../engine/puzzles";
import { clueweaveScore, type AssistTally } from "../engine/scoring";
import { puzzleBadges, badgeWeightMultiplier } from "../engine/badges";
import {
  defaultProgressionSettings,
  defaultProgressionState,
  FAST_TUNING,
  STRUGGLE_TUNING,
  type FastSensitivity,
  type ProgressionSettings,
  type ProgressionState,
  type StruggleSensitivity,
} from "../engine/progression";

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface Progress {
  puzzleId: string;
  marks: Cell[][];
  elapsedMs: number;
}

/** How a clue is drawn once its line is complete. */
export type ClueStyle = "grey" | "strike" | "hide" | "none";

/** Game settings. Extends the progression tunables so they live in one place. */
export interface Settings extends ProgressionSettings {
  mistakeCheck: boolean;
  showTimer: boolean;
  /** Appearance of a clue whose line is satisfied (replaces the old on/off dim). */
  clueStyle: ClueStyle;
  /** Auto-cross the leftover cells of a line once its clue is met. */
  autoCross: boolean;
}

export interface SaveData {
  version: 1;
  progress: Record<string, Progress>;
  completed: string[];
  /** Fastest solve time (ms) per puzzle id. */
  bestTimes: Record<string, number>;
  /** Best per-puzzle score (0–100) per puzzle id. */
  bestScores: Record<string, number>;
  /** Assists used in the current (in-progress) attempt, per puzzle id. */
  assists: Record<string, AssistTally>;
  userPuzzles: Puzzle[];
  settings: Settings;
  tutorialSeen: boolean;
  /** True once progress has ever been wiped — disclosed when sharing a score. */
  progressReset: boolean;
  /** Working tier + boredom/struggle streaks. See docs/progression-model.md. */
  progression: ProgressionState;
}

const KEY = "clueweave.save.v1";

/** The pre-rebrand key. Read once, on first load under the new name, so players
 *  who saved under the old brand keep their progress. Never written to again. */
const LEGACY_KEY = "pixelogic.save.v1";

/** The save blob, preferring the current key and adopting a legacy one if that's
 *  all there is. Adoption copies the blob across so the old key stops mattering. */
function readRaw(storage: StorageLike): string | null {
  const current = storage.getItem(KEY);
  if (current !== null) return current;
  const legacy = storage.getItem(LEGACY_KEY);
  if (legacy === null) return null;
  try {
    storage.setItem(KEY, legacy);
    storage.removeItem(LEGACY_KEY);
  } catch {
    /* a full or read-only store still lets us play from the legacy blob */
  }
  return legacy;
}

export function defaultSaveData(): SaveData {
  return {
    version: 1,
    progress: {},
    completed: [],
    bestTimes: {},
    bestScores: {},
    assists: {},
    userPuzzles: [],
    settings: {
      mistakeCheck: false,
      showTimer: true,
      clueStyle: "grey",
      autoCross: false,
      ...defaultProgressionSettings(),
    },
    tutorialSeen: false,
    progressReset: false,
    progression: defaultProgressionState(),
  };
}

/** An in-memory fallback used when localStorage is unavailable (e.g. tests, SSR). */
class MemoryStorage implements StorageLike {
  private map = new Map<string, string>();
  getItem(key: string): string | null {
    return this.map.has(key) ? this.map.get(key)! : null;
  }
  setItem(key: string, value: string): void {
    this.map.set(key, value);
  }
  removeItem(key: string): void {
    this.map.delete(key);
  }
}

let fallback: StorageLike | null = null;

export function getStorage(): StorageLike {
  try {
    if (typeof localStorage !== "undefined") return localStorage;
  } catch {
    /* access can throw in sandboxed iframes */
  }
  if (!fallback) fallback = new MemoryStorage();
  return fallback;
}

/** Load save data, resetting to defaults on missing/corrupt/old-version data. */
export function loadSave(storage: StorageLike = getStorage()): SaveData {
  const raw = readRaw(storage);
  if (!raw) return defaultSaveData();
  try {
    const parsed = JSON.parse(raw) as Partial<SaveData>;
    if (!parsed || parsed.version !== 1) return defaultSaveData();
    const base = defaultSaveData();
    return {
      version: 1,
      progress: parsed.progress ?? base.progress,
      completed: Array.isArray(parsed.completed) ? parsed.completed : base.completed,
      bestTimes:
        parsed.bestTimes && typeof parsed.bestTimes === "object"
          ? (parsed.bestTimes as Record<string, number>)
          : base.bestTimes,
      bestScores:
        parsed.bestScores && typeof parsed.bestScores === "object"
          ? (parsed.bestScores as Record<string, number>)
          : base.bestScores,
      assists:
        parsed.assists && typeof parsed.assists === "object"
          ? (parsed.assists as Record<string, AssistTally>)
          : base.assists,
      userPuzzles: Array.isArray(parsed.userPuzzles) ? parsed.userPuzzles : base.userPuzzles,
      settings: migrateSettings(parsed.settings, base.settings),
      tutorialSeen: parsed.tutorialSeen === true,
      progressReset: parsed.progressReset === true,
      progression: mergeProgression(parsed.progression, base.progression),
    };
  } catch {
    return defaultSaveData();
  }
}

/** Merge stored settings over defaults, migrating the old `highlightClues`
 *  boolean to the richer `clueStyle` (true → grey, false → none). */
function migrateSettings(stored: unknown, base: Settings): Settings {
  const raw = (stored ?? {}) as Partial<Settings> & { highlightClues?: boolean };
  const settings: Settings = { ...base };
  if (typeof raw.mistakeCheck === "boolean") settings.mistakeCheck = raw.mistakeCheck;
  if (typeof raw.showTimer === "boolean") settings.showTimer = raw.showTimer;
  if (typeof raw.autoCross === "boolean") settings.autoCross = raw.autoCross;
  if (raw.clueStyle === "grey" || raw.clueStyle === "strike" || raw.clueStyle === "hide" || raw.clueStyle === "none") {
    settings.clueStyle = raw.clueStyle;
  } else if (raw.highlightClues === false) {
    settings.clueStyle = "none";
  }
  if (typeof raw.smartNext === "boolean") settings.smartNext = raw.smartNext;
  if (typeof raw.autoAdjustDifficulty === "boolean") settings.autoAdjustDifficulty = raw.autoAdjustDifficulty;
  if (typeof raw.hintsCountAsStruggle === "boolean") settings.hintsCountAsStruggle = raw.hintsCountAsStruggle;
  if (raw.fastSensitivity && raw.fastSensitivity in FAST_TUNING) {
    settings.fastSensitivity = raw.fastSensitivity as FastSensitivity;
  }
  if (raw.struggleSensitivity && raw.struggleSensitivity in STRUGGLE_TUNING) {
    settings.struggleSensitivity = raw.struggleSensitivity as StruggleSensitivity;
  }
  return settings;
}

/** Merge a stored progression block over defaults. A missing or corrupt block
 *  falls back field-by-field and must never discard the rest of the save. */
function mergeProgression(stored: unknown, base: ProgressionState): ProgressionState {
  const raw = (stored ?? {}) as Partial<ProgressionState>;
  const count = (v: unknown, fallback: number): number =>
    typeof v === "number" && Number.isFinite(v) && v >= 0 ? Math.floor(v) : fallback;
  return {
    workingTier: DIFFICULTY_ORDER.includes(raw.workingTier as Difficulty)
      ? (raw.workingTier as Difficulty)
      : base.workingTier,
    fastStreak: count(raw.fastStreak, base.fastStreak),
    struggleStreak: count(raw.struggleStreak, base.struggleStreak),
    smartNextUses: count(raw.smartNextUses, base.smartNextUses),
    smartNextPrompted: raw.smartNextPrompted === true,
    spamCount: count(raw.spamCount, base.spamCount),
  };
}

export function writeSave(data: SaveData, storage: StorageLike = getStorage()): void {
  try {
    storage.setItem(KEY, JSON.stringify(data));
  } catch {
    /* quota errors etc. are non-fatal — the game still works in-memory */
  }
}

export function recordProgress(progress: Progress, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  data.progress[progress.puzzleId] = progress;
  writeSave(data, storage);
}

export function clearProgress(puzzleId: string, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  delete data.progress[puzzleId];
  writeSave(data, storage);
}

export function markCompleted(id: string, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  if (!data.completed.includes(id)) data.completed.push(id);
  delete data.progress[id];
  delete data.assists[id];
  writeSave(data, storage);
}

/** Record a solve time, keeping only the fastest. Returns the best time and
 *  whether this solve set a new record. */
export function recordBestTime(
  id: string,
  elapsedMs: number,
  storage: StorageLike = getStorage(),
): { best: number; isNew: boolean } {
  const data = loadSave(storage);
  const prev = data.bestTimes[id];
  const isNew = prev === undefined || elapsedMs < prev;
  if (isNew) {
    data.bestTimes[id] = elapsedMs;
    writeSave(data, storage);
    return { best: elapsedMs, isNew: true };
  }
  return { best: prev, isNew: false };
}

export function getBestTime(id: string, storage: StorageLike = getStorage()): number | undefined {
  return loadSave(storage).bestTimes[id];
}

/** Record a per-puzzle score (0–100), keeping the best. Returns the kept best
 *  and whether this beat the previous record. */
export function recordPuzzleScore(
  id: string,
  score: number,
  storage: StorageLike = getStorage(),
): { best: number; isNew: boolean } {
  const data = loadSave(storage);
  const prev = data.bestScores[id];
  const isNew = prev === undefined || score > prev;
  if (isNew) {
    data.bestScores[id] = score;
    writeSave(data, storage);
    return { best: score, isNew: true };
  }
  return { best: prev, isNew: false };
}

export function getPuzzleScore(id: string, storage: StorageLike = getStorage()): number | undefined {
  return loadSave(storage).bestScores[id];
}

/** The overall Clueweave Score (0–1600) across the built-in library. */
export function getClueweaveScore(storage: StorageLike = getStorage()): number {
  const best = loadSave(storage).bestScores;
  return clueweaveScore(
    best,
    LIBRARY.map((p) => ({
      id: p.id,
      difficulty: p.difficulty,
      weightMult: badgeWeightMultiplier(puzzleBadges(p)),
    })),
  );
}

export function wasProgressReset(storage: StorageLike = getStorage()): boolean {
  return loadSave(storage).progressReset;
}

export function getAssists(id: string, storage: StorageLike = getStorage()): AssistTally | undefined {
  return loadSave(storage).assists[id];
}

export function setAssists(id: string, tally: AssistTally, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  data.assists[id] = tally;
  writeSave(data, storage);
}

export function clearAssists(id: string, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  if (data.assists[id]) {
    delete data.assists[id];
    writeSave(data, storage);
  }
}

export function saveUserPuzzle(puzzle: Puzzle, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  const idx = data.userPuzzles.findIndex((p) => p.id === puzzle.id);
  if (idx >= 0) data.userPuzzles[idx] = puzzle;
  else data.userPuzzles.push(puzzle);
  writeSave(data, storage);
}

export function deleteUserPuzzle(id: string, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  data.userPuzzles = data.userPuzzles.filter((p) => p.id !== id);
  writeSave(data, storage);
}

export function setSettings(patch: Partial<Settings>, storage: StorageLike = getStorage()): Settings {
  const data = loadSave(storage);
  data.settings = { ...data.settings, ...patch };
  writeSave(data, storage);
  return data.settings;
}

export function getSettings(storage: StorageLike = getStorage()): Settings {
  return loadSave(storage).settings;
}

export function getProgression(storage: StorageLike = getStorage()): ProgressionState {
  return loadSave(storage).progression;
}

export function setProgression(next: ProgressionState, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  data.progression = next;
  writeSave(data, storage);
}

/** Apply a partial update to the progression block (read-modify-write). */
export function patchProgression(
  patch: Partial<ProgressionState>,
  storage: StorageLike = getStorage(),
): ProgressionState {
  const data = loadSave(storage);
  data.progression = { ...data.progression, ...patch };
  writeSave(data, storage);
  return data.progression;
}

export function isTutorialSeen(storage: StorageLike = getStorage()): boolean {
  return loadSave(storage).tutorialSeen;
}

export function setTutorialSeen(seen: boolean, storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  data.tutorialSeen = seen;
  writeSave(data, storage);
}

/** Danger zone: wipe solved/in-progress state and records. Keeps custom puzzles and
 *  settings. Sets a permanent flag so a shared Clueweave Score can disclose the reset. */
export function resetProgress(storage: StorageLike = getStorage()): void {
  const data = loadSave(storage);
  data.progress = {};
  data.completed = [];
  data.bestTimes = {};
  data.bestScores = {};
  data.assists = {};
  data.progressReset = true;
  // Progression state IS progress — the working tier and streaks go back to
  // defaults. Settings (including the progression tunables) survive a reset.
  data.progression = defaultProgressionState();
  writeSave(data, storage);
}
