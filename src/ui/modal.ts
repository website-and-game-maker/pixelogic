import { el } from "./dom";

export interface Modal {
  close(): void;
  card: HTMLElement;
  overlay: HTMLElement;
}

export interface ModalOptions {
  title?: string;
  body: HTMLElement;
  className?: string;
  /** Allow closing via backdrop click / Esc / the × button (default true). */
  dismissable?: boolean;
  /** Hide the × button (e.g. for flows with their own actions). */
  hideClose?: boolean;
  onClose?: () => void;
}

/** Open a centered, accessible modal dialog appended to <body>. */
export function openModal(opts: ModalOptions): Modal {
  const { title, dismissable = true, hideClose = false, onClose } = opts;
  let closed = false;
  // Remember what had focus so we can restore it when the dialog closes.
  const trigger = document.activeElement as HTMLElement | null;

  const closeBtn = el("button", {
    class: "modal-close",
    text: "✕",
    attrs: { type: "button", "aria-label": "Close" },
  });

  const card = el(
    "div",
    {
      class: `modal-card ${opts.className ?? ""}`,
      attrs: { role: "dialog", "aria-modal": "true", ...(title ? { "aria-label": title } : {}) },
    },
    [
      hideClose ? null : closeBtn,
      title ? el("h2", { class: "modal-title", text: title }) : null,
      opts.body,
    ],
  );

  const overlay = el("div", { class: "modal-overlay" }, [card]);

  function close(): void {
    if (closed) return;
    closed = true;
    overlay.remove();
    document.removeEventListener("keydown", onKey);
    onClose?.();
    // Return focus to whatever opened the dialog (keyboard users don't get dumped at <body>).
    trigger?.focus?.();
  }

  function focusables(): HTMLElement[] {
    return Array.from(
      card.querySelectorAll<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
      ),
    ).filter((node) => !node.hasAttribute("disabled") && node.offsetParent !== null);
  }

  function onKey(e: KeyboardEvent): void {
    if (e.key === "Escape" && dismissable) {
      close();
      return;
    }
    if (e.key !== "Tab") return;
    // Trap focus inside the dialog.
    const f = focusables();
    if (f.length === 0) {
      e.preventDefault();
      return;
    }
    const first = f[0];
    const last = f[f.length - 1];
    const active = document.activeElement as HTMLElement | null;
    if (!card.contains(active)) {
      e.preventDefault();
      first.focus();
    } else if (e.shiftKey && active === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && active === last) {
      e.preventDefault();
      first.focus();
    }
  }

  closeBtn.addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay && dismissable) close();
  });
  document.addEventListener("keydown", onKey);

  document.body.appendChild(overlay);
  (hideClose ? card : closeBtn).focus?.();

  return { close, card, overlay };
}
