// Dedicated privacy policy (#5, web side) — mirrors the iOS PrivacyView so the
// phone and the web tell the same story. Self-contained: no network, resolves
// offline, never depends on an external URL. Reached from the menu footer link
// and the #/privacy route.

import { el, mount } from "../dom";
import { navigate } from "../router";

/** The project's human manager — a deliberately disposable mailbox (the game is
 *  AI-authored; see About). Single source of the address on the web side. */
const MANAGER_EMAIL = "pats-sire-06@icloud.com";

interface Section {
  icon: string;
  title: string;
  html: string;
}

const SECTIONS: Section[] = [
  {
    icon: "🔒",
    title: "The short version",
    html: `<p>Clueweave collects nothing about you. There are no accounts, no analytics,
      no advertising, no trackers, and no network connections. Everything you do stays in
      your browser, on your device.</p>`,
  },
  {
    icon: "💾",
    title: "What's stored, and where",
    html: `<p>Your solved puzzles, scores, best times, settings, and any puzzles you create
      or generate are saved only in this browser's local storage on your device. They are
      never uploaded anywhere, and clearing your browser data for this site removes all of
      it.</p>`,
  },
  {
    icon: "🔗",
    title: "Sharing a puzzle",
    html: `<p>When you share a puzzle, the picture is encoded directly into the link itself —
      nothing is sent to a server, because there is no server. Opening a shared link simply
      decodes the puzzle in the recipient's browser.</p>`,
  },
  {
    icon: "🧒",
    title: "Children",
    html: `<p>Clueweave is suitable for all ages. Because it collects no data and contains no
      ads, accounts, or outbound links to user-generated content, it is safe for children to
      use.</p>`,
  },
  {
    icon: "✉️",
    title: "Contact",
    html: `<p>Clueweave is AI-authored (see About). A human manager publishes it and reads
      feedback at a disposable email address:
      <a href="mailto:${MANAGER_EMAIL}?subject=Clueweave%20privacy%20question">${MANAGER_EMAIL}</a>.
      Questions about privacy can be sent there.</p>`,
  },
];

export function renderPrivacy(host: HTMLElement): void {
  const view = el("div", { class: "view about privacy" }, [
    el("header", { class: "play-header" }, [
      el("button", { class: "btn ghost back-btn", text: "‹ Menu", on: { click: () => navigate("/") } }),
      el("div", { class: "play-title" }, [
        el("h1", { text: "Privacy Policy" }),
        el("div", { class: "play-sub" }, [el("span", { class: "chip muted", text: "What we collect: nothing" })]),
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
    el("p", { class: "privacy-updated", text: "Last updated June 2026" }),
    el("footer", { class: "menu-footer" }, [
      el("button", { class: "btn primary", text: "Play ▦", on: { click: () => navigate("/") } }),
    ]),
  ]);
  mount(host, view);
}
