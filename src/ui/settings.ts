import { el } from "./dom";
import { openModal } from "./modal";
import { SYMMETRY_LEGEND } from "../engine/badges";
import {
  defaultProgressionState,
  HINT_STRUGGLE_THRESHOLD,
  type FastSensitivity,
  type StruggleSensitivity,
} from "../engine/progression";
import {
  getSettings,
  setSettings,
  setProgression,
  getProgression,
  resetProgress,
  type Settings,
  type ClueStyle,
} from "./persistence";

type SettingKey = keyof Settings;

function toggleRow(
  label: string,
  desc: string,
  key: SettingKey,
  current: boolean,
  onToggle: (value: boolean) => void,
): HTMLElement {
  let value = current;
  const sw = el("button", {
    class: `switch ${value ? "on" : ""}`,
    attrs: { type: "button", role: "switch", "aria-checked": String(value), "aria-label": label },
  });
  const knob = el("span", { class: "switch-knob" });
  sw.append(knob);
  sw.addEventListener("click", () => {
    value = !value;
    sw.classList.toggle("on", value);
    sw.setAttribute("aria-checked", String(value));
    setSettings({ [key]: value } as Partial<Settings>);
    onToggle(value);
  });
  return el("div", { class: "setting-row" }, [
    el("div", { class: "setting-text" }, [
      el("span", { class: "setting-label", text: label }),
      el("span", { class: "setting-desc", text: desc }),
    ]),
    sw,
  ]);
}

/** A labelled <select> settings row. */
function selectRow(
  label: string,
  desc: string,
  options: Array<{ value: string; label: string }>,
  current: string,
  onPick: (value: string) => void,
): HTMLElement {
  const select = el("select", { class: "setting-select", attrs: { "aria-label": label } }) as HTMLSelectElement;
  for (const o of options) {
    const opt = el("option", { text: o.label, attrs: { value: o.value } });
    if (o.value === current) opt.setAttribute("selected", "");
    select.append(opt);
  }
  select.addEventListener("change", () => onPick(select.value));
  return el("div", { class: "setting-row" }, [
    el("div", { class: "setting-text" }, [
      el("span", { class: "setting-label", text: label }),
      el("span", { class: "setting-desc", text: desc }),
    ]),
    select,
  ]);
}

const TIER_LABEL: Record<string, string> = {
  easy: "Easy",
  medium: "Medium",
  hard: "Hard",
  expert: "Extra Hard",
  max: "Max",
};

/** Shows what the model currently thinks, and lets the player wipe just that. */
function progressionStatusRow(onChange?: () => void): HTMLElement {
  const p = getProgression();
  const label = el("span", {
    class: "setting-desc",
    text: `Currently aiming you at ${TIER_LABEL[p.workingTier] ?? p.workingTier}.`,
  });
  const reset = el("button", {
    class: "btn small",
    text: "Reset",
    attrs: { type: "button" },
    on: {
      click: () => {
        setProgression(defaultProgressionState());
        label.textContent = `Currently aiming you at ${TIER_LABEL.easy}.`;
        onChange?.();
      },
    },
  });
  return el("div", { class: "setting-row" }, [
    el("div", { class: "setting-text" }, [el("span", { class: "setting-label", text: "Your level" }), label]),
    reset,
  ]);
}

export type SettingsScope = "home" | "game";

/** Open the settings modal. `onChange` fires when any setting changes or progress is reset. */
export function openSettings(scope: SettingsScope, onChange?: () => void): void {
  const settings = getSettings();
  const rows: HTMLElement[] = [
    toggleRow("Auto-check mistakes", "Highlight filled cells that don't belong.", "mistakeCheck", settings.mistakeCheck, () => onChange?.()),
    toggleRow("Show timer", "Display the puzzle timer while you play.", "showTimer", settings.showTimer, () => onChange?.()),
    toggleRow(
      "Auto-cross finished lines",
      "When a line's clue is met, cross out its leftover cells for you.",
      "autoCross",
      settings.autoCross,
      () => onChange?.(),
    ),
    selectRow(
      "Completed clues",
      "How a clue looks once its line is finished.",
      [
        { value: "grey", label: "Grey out" },
        { value: "strike", label: "Strike through" },
        { value: "hide", label: "Hide them" },
        { value: "none", label: "Leave them" },
      ],
      settings.clueStyle,
      (value) => {
        setSettings({ clueStyle: value as ClueStyle });
        onChange?.();
      },
    ),
  ];

  const body = el("div", { class: "settings-body" }, rows);

  // ---- Progression: how the game picks what you play next ----
  body.append(
    el("div", { class: "settings-group" }, [
      el("h3", { text: "Picking your next puzzle" }),
      el("p", {
        class: "group-desc",
        text: "The → button at the top right can choose for you, watching whether you're breezing through or getting stuck.",
      }),
      toggleRow(
        "Smart next puzzle",
        "The glowing → picks what suits you. Off makes it a plain next-in-order arrow.",
        "smartNext",
        settings.smartNext,
        () => onChange?.(),
      ),
      toggleRow(
        "Auto-adjust difficulty",
        "Move up a level when you solve fast, and back down when you keep getting stuck.",
        "autoAdjustDifficulty",
        settings.autoAdjustDifficulty,
        () => onChange?.(),
      ),
      selectRow(
        "Move me up when",
        "How quickly a run of fast, unassisted solves bumps you to the next level.",
        [
          { value: "relaxed", label: "I'm well ahead (3 in a row)" },
          { value: "normal", label: "I'm comfortable (2 in a row)" },
          { value: "eager", label: "I'm even slightly quick (2 in a row)" },
        ],
        settings.fastSensitivity,
        (value) => {
          setSettings({ fastSensitivity: value as FastSensitivity });
          onChange?.();
        },
      ),
      selectRow(
        "Move me down when",
        "How quickly giving up or leaning on help drops you back a level.",
        [
          { value: "forgiving", label: "I've struggled 3 times" },
          { value: "normal", label: "I've struggled twice" },
          { value: "quick", label: "I've struggled once" },
        ],
        settings.struggleSensitivity,
        (value) => {
          setSettings({ struggleSensitivity: value as StruggleSensitivity });
          onChange?.();
        },
      ),
      toggleRow(
        "Count heavy hints as struggling",
        `Using Check board, or ${HINT_STRUGGLE_THRESHOLD}+ hints on one puzzle, counts as a struggle.`,
        "hintsCountAsStruggle",
        settings.hintsCountAsStruggle,
        () => onChange?.(),
      ),
      progressionStatusRow(onChange),
    ]),
  );

  if (scope === "home") {
    const dangerActions = el("div", { class: "danger-actions" });
    const resetBtn = el("button", {
      class: "btn danger",
      text: "Reset progress",
      on: {
        click: () => {
          dangerActions.replaceChildren(
            el("span", { class: "confirm-text", text: "Erase all progress?" }),
            el("button", {
              class: "btn danger",
              text: "Yes, reset",
              on: {
                click: () => {
                  resetProgress();
                  onChange?.();
                  modal.close();
                },
              },
            }),
            el("button", {
              class: "btn ghost",
              text: "Cancel",
              on: { click: () => dangerActions.replaceChildren(resetBtn) },
            }),
          );
        },
      },
    });
    dangerActions.append(resetBtn);
    body.append(
      el("div", { class: "danger-zone" }, [
        el("h3", { text: "⚠ Danger Zone" }),
        el("p", { class: "danger-desc", text: "Clears solved puzzles and saved progress. Your custom puzzles are kept." }),
        dangerActions,
      ]),
    );
  }

  const modal = openModal({
    title: scope === "home" ? "Settings" : "Game settings",
    body,
    className: "settings-modal",
  });
}

/** Open the "How to play" rules modal. */
export function openRules(): void {
  const body = el("div", { class: "rules-body" });
  const symmetryRows = SYMMETRY_LEGEND.map((s) => `<li><code>${s.code}</code> — ${s.meaning}</li>`).join("");
  body.innerHTML = `
    <p>Each puzzle hides a picture. The numbers along every row and column tell you
    the lengths of the <strong>runs of filled cells</strong> in that line, in order.</p>
    <ul>
      <li><strong>Fill</strong> a cell you're sure belongs to the picture.</li>
      <li><strong>Cross</strong> (✕) a cell you're sure is empty — right-click, or switch to Cross mode.</li>
      <li>A clue like <code>3&nbsp;1</code> means a run of 3, then a gap, then a run of 1.</li>
      <li>A clue greys out once that line's filled cells match it (change the style in Settings).</li>
    </ul>
    <p>Every Clueweave puzzle has exactly one solution and can be reached by logic alone —
    no guessing. Stuck? Use <strong>Hint</strong> for the next deduction, or
    <strong>Watch solve</strong> to see it worked out step by step.</p>
    <h3>Reading the badges</h3>
    <p>Chips under the title tell you how a puzzle will feel. <strong>◈ Symmetric</strong>
    always carries a letter for <em>which way</em> the picture mirrors — that's the
    <code>H</code> in <strong>◈ Symmetric · H</strong>:</p>
    <ul>${symmetryRows}</ul>
    <p><strong>🏷 Name-hint</strong> means the title gives the picture away;
    <strong>▤ Patterned</strong> means every line is one solid run.</p>
  `;
  openModal({ title: "How to play", body, className: "rules-modal" });
}
