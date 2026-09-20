// Holds the in-progress editor puzzle across the editor → test → editor round
// trip (kept in memory; lives only for the session). Separate module to avoid a
// router ↔ editor import cycle.

export interface EditorDraft {
  solution: boolean[][];
  title: string;
  /** Set when editing an existing custom puzzle, so Save updates it in place. */
  editId?: string;
}

let draft: EditorDraft | null = null;

export function setEditorDraft(d: EditorDraft | null): void {
  draft = d;
}

export function getEditorDraft(): EditorDraft | null {
  return draft;
}

export function clearEditorDraft(): void {
  draft = null;
}
