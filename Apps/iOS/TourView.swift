// The in-app TOUR: a paged, full-screen walkthrough shown AFTER the tutorial.
// Unlike anchored coach-marks, these are self-contained cards — robust on every
// device size. Each card pairs an SF Symbol / small illustration with a short,
// rounded-Theme explanation of one feature: the toolbar, puzzle tiles, badges,
// the Clueweave Score, creating/importing puzzles, and My Puzzles. Finishing or
// skipping sets store.tourSeen = true so it never reappears uninvited.

import SwiftUI
import ClueweaveKit

struct TourView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0

    private let cards = TourCard.all

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: title + Skip (always available — the tour is never a trap).
            HStack {
                Text("Quick tour")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Skip") { finish() }
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            TabView(selection: $index) {
                ForEach(Array(cards.enumerated()), id: \.offset) { pair in
                    CardView(card: pair.element)
                        .padding(.horizontal, 20)
                        .tag(pair.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: index)

            // Progress dots.
            HStack(spacing: 8) {
                ForEach(cards.indices, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Theme.primaryDeep : Theme.lineMajor)
                        .frame(width: i == index ? 9 : 7, height: i == index ? 9 : 7)
                        .animation(.easeInOut, value: index)
                }
            }
            .padding(.vertical, 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(index + 1) of \(cards.count)")

            // Bottom controls: Back / Next (Done on the last card).
            HStack(spacing: 12) {
                Button {
                    withAnimation { if index > 0 { index -= 1 } }
                } label: {
                    Text("Back")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.surface))
                        .foregroundStyle(Theme.ink)
                }
                .opacity(index == 0 ? 0.4 : 1)
                .disabled(index == 0)

                Button {
                    if index == cards.count - 1 {
                        finish()
                    } else {
                        withAnimation { index += 1 }
                    }
                } label: {
                    Text(index == cards.count - 1 ? "Done" : "Next")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.brandGradient))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(false)
    }

    private func finish() {
        app.store.tourSeen = true
        app.showTour = false
        dismiss()
    }
}

// MARK: - Card model

/// One tour page. `illustration` draws the card's visual; `title` and `body`
/// carry the wording. Kept value-typed so the deck is a simple static array.
private struct TourCard: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let illustration: AnyView

    init(title: String, body: String, @ViewBuilder illustration: () -> some View) {
        self.title = title
        self.body = body
        self.illustration = AnyView(illustration())
    }

    @MainActor static let all: [TourCard] = [
        // 0 — Welcome
        TourCard(
            title: "Welcome aboard",
            body: "You've learned how to solve a grid — now here's a 30-second tour of everything else Clueweave can do. Swipe or tap Next to begin."
        ) {
            TourGlyph(systemName: "map.fill", tint: Theme.primaryDeep)
        },

        // 1 — Toolbar
        TourCard(
            title: "The top toolbar",
            body: "Three buttons live in the top-right of the menu. The graduation cap replays this tutorial, the info circle opens About, and the gear opens Settings."
        ) {
            HStack(spacing: 18) {
                ToolbarTourIcon(systemName: "graduationcap", caption: "Tutorial")
                ToolbarTourIcon(systemName: "info.circle", caption: "About")
                ToolbarTourIcon(systemName: "gearshape", caption: "Settings")
            }
        },

        // 2 — Puzzle tiles
        TourCard(
            title: "Reading a puzzle tile",
            body: "Each tile shows your best score out of 100 (top-left), your best time (top-right, beside a stopwatch), a difficulty chip, and any badges. Tap a tile to play it."
        ) {
            TourTileMock()
        },

        // 3 — Badges intro + the three keys
        TourCard(
            title: "What badges mean",
            body: "Badges flag a picture's helpful traits — and each one gently weights your Clueweave Score, because some make a puzzle a little easier."
        ) {
            VStack(spacing: 12) {
                ForEach(BadgeKey.allCases, id: \.self) { key in
                    BadgeTourRow(key: key)
                }
            }
        },

        // 4 — Clueweave Score
        TourCard(
            title: "Your Clueweave Score",
            body: "The laurel at the top of the menu is your Clueweave Score, from 0 to 1600. It sums your best result on every puzzle, weighted by difficulty and badges — your one number for mastery of the whole library."
        ) {
            ScoreLaurelMock()
        },

        // 5 — Create / Surprise / Import
        TourCard(
            title: "Make & find puzzles",
            body: "Create your own draws a brand-new puzzle (we check it's solvable by logic). Surprise me jumps to a fresh challenge at your level. Import a puzzle adds one from a shared link — no account, no download."
        ) {
            VStack(spacing: 12) {
                TourActionRow(systemName: "pencil", title: "Create your own", subtitle: "Draw a new puzzle")
                TourActionRow(systemName: "die.face.5", title: "Surprise me", subtitle: "A fresh pick for you")
                TourActionRow(systemName: "square.and.arrow.down", title: "Import a puzzle", subtitle: "Paste a shared link")
            }
        },

        // 6 — My Puzzles / Manage
        TourCard(
            title: "My Puzzles",
            body: "Anything you create or import lands in My Puzzles. Tap Manage there to select and delete puzzles, or long-press one to edit it. Everything stays on this device."
        ) {
            TourGlyph(systemName: "square.grid.2x2.fill", tint: Theme.primary)
        },

        // 7 — Done
        TourCard(
            title: "That's the tour!",
            body: "You're all set. Every puzzle is solvable by pure logic — no guessing required. Have fun deducing the hidden pictures."
        ) {
            TourGlyph(systemName: "checkmark.seal.fill", tint: Theme.primaryDeep)
        },
    ]
}

// MARK: - Card chrome

private struct CardView: View {
    let card: TourCard

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 8)
                card.illustration
                    .frame(maxWidth: .infinity)
                VStack(spacing: 12) {
                    Text(card.title)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text(card.body)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Theme.surface)
                    .shadow(color: Theme.primaryDeep.opacity(0.10), radius: 14, y: 6)
            )
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Illustrations

/// A large rounded badge-square hosting a single SF Symbol — the tour's hero art.
private struct TourGlyph: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 52, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 108, height: 108)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.brandGradient))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(tint.opacity(0.25), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }
}

/// One toolbar button, drawn the way it appears in the menu, with a label below.
private struct ToolbarTourIcon: View {
    let systemName: String
    let caption: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.primaryDeep)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.surface2))
            Text(caption)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption) button")
    }
}

/// A miniature, non-interactive puzzle tile mirroring PuzzleCard's anatomy.
private struct TourTileMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                (Text("92").font(.system(.body, design: .rounded, weight: .black))
                 + Text("/100").font(.system(size: 10, weight: .bold)))
                    .foregroundStyle(Theme.primaryDeep)
                Spacer()
                Label("01:24", systemImage: "stopwatch")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text("Heart")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 4) {
                Chip(text: Difficulty.easy.displayName,
                     bg: Theme.difficultyColors(.easy).bg,
                     fg: Theme.difficultyColors(.easy).fg)
                Chip(text: "◈ Symmetric · H",
                     bg: Theme.badgeColors(.symmetric).bg,
                     fg: Theme.badgeColors(.symmetric).fg)
            }
            Text("5 × 5")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(14)
        .frame(maxWidth: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface2)
                .shadow(color: Theme.primaryDeep.opacity(0.08), radius: 6, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example puzzle tile: score 92 out of 100, best time 1 minute 24, Easy, Symmetric")
    }
}

/// One badge legend row: the BadgeKey.glyph in its color + a one-line meaning.
private struct BadgeTourRow: View {
    let key: BadgeKey

    private var meaning: String {
        switch key {
        case .symmetric: "The picture mirrors itself — solve one side, get the other."
        case .named: "The title hints at what you're drawing."
        case .patterned: "Each row and column is one solid run."
        }
    }

    var body: some View {
        let colors = Theme.badgeColors(key)
        HStack(spacing: 12) {
            Image(systemName: key.glyph)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(colors.fg)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(colors.bg))
            VStack(alignment: .leading, spacing: 2) {
                Text(key.name)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(meaning)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(key.name): \(meaning)")
    }
}

/// A compact stand-in for the home laurel score chip.
private struct ScoreLaurelMock: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("🌿").font(.title)
            VStack(spacing: 0) {
                Text("742")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.gold)
                Text("/ 1600").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.inkSoft)
                Text("APPRENTICE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primaryDeep)
            }
            Text("🌿").font(.title).scaleEffect(x: -1)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Theme.surface2)
                .shadow(color: Theme.primaryDeep.opacity(0.12), radius: 10, y: 4)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example Clueweave Score laurel, 742 of 1600")
    }
}

/// One menu action, drawn as an icon + title + subtitle row.
private struct TourActionRow: View {
    let systemName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.brandGradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}
