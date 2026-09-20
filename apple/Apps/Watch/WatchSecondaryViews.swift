// Wrist-sized About, Settings, and the badge/difficulty Legend. The About text
// is a scaled-down version of the iOS About content (short paragraphs), keeping
// the rule that EVERYTHING — even the idea — was conceived and written by Claude
// (Anthropic AI) in Claude Code, with no human author, plus the referral link.
// Settings is watch-local (AppStorage) and minimal.

import SwiftUI
import ClueweaveKit

// MARK: - More (menu hub)

/// The "ellipsis" hub reachable from the home toolbar: a small list that pushes
/// each secondary screen. A pushed list reads better on the wrist than a popover
/// Menu and avoids the NavigationLink-in-Menu quirks on watchOS.
struct WatchMoreView: View {
    var body: some View {
        List {
            NavigationLink {
                WatchTutorialView()
            } label: {
                Label("How to play", systemImage: "graduationcap.fill")
            }
            NavigationLink {
                WatchLegendView()
            } label: {
                Label("Legend", systemImage: "list.bullet.rectangle")
            }
            NavigationLink {
                WatchSettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
            NavigationLink {
                WatchAboutView()
            } label: {
                Label("About", systemImage: "info.circle.fill")
            }
        }
        .navigationTitle("More")
    }
}

// MARK: - About

struct WatchAboutView: View {
    private struct Para: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let paras: [Para] = [
        Para(icon: "square.grid.3x3.fill", title: "What is Clueweave?",
             body: "A nonogram game: the numbers on each row and column count the runs of filled cells, and from those clues alone you rebuild a hidden picture. Every puzzle is solvable by logic — never a guess."),
        Para(icon: "brain.head.profile", title: "Always logical, always unique",
             body: "Before a puzzle ships it's checked two ways: a solver using only human-style line reasoning must finish it, and a second check confirms no other picture fits the same clues."),
        Para(icon: "laurel.leading", title: "Scoring lives on the phone",
             body: "On the wrist, play is casual: you just track which puzzles you've completed. The full Clueweave Score (0–1,600) is a phone and web concern."),
        Para(icon: "hand.raised.fill", title: "Private & offline",
             body: "No accounts, no analytics, no network. Everything stays on this watch, and deleting the app deletes it. Clueweave runs fully standalone — no phone required."),
        Para(icon: "sparkles", title: "Built entirely by AI",
             body: "Everything in Clueweave — even the idea itself — was conceived and written by Claude (Anthropic's AI) working in Claude Code. There is no human author: the engine, the puzzles, the art, the tests and this text are all AI-made."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(paras) { p in
                    VStack(alignment: .leading, spacing: 5) {
                        Label(p.title, systemImage: p.icon)
                            .font(.system(.caption, design: .rounded, weight: .black))
                            .foregroundStyle(.teal)
                        Text(p.body)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }

                Link(destination: URL(string: "https://claude.ai/referral/8H3jezX92A")!) {
                    Label("Try Claude Code", systemImage: "arrow.up.forward.square")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.teal)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("About")
    }
}

// MARK: - Settings

struct WatchSettingsView: View {
    @AppStorage("clueweave.watch.showTimer") private var showTimer = true
    @AppStorage("clueweave.watch.haptics") private var haptics = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $showTimer) {
                    Label("Show timer", systemImage: "stopwatch")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                Toggle(isOn: $haptics) {
                    Label("Haptics", systemImage: "hand.tap")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            } footer: {
                Text("Settings are stored on this watch only.")
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Legend

struct WatchLegendView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Badge key.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Badges")
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(.secondary)
                    ForEach(BadgeKey.allCases, id: \.self) { key in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: key.glyph)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(WatchPalette.color(for: key))
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key.name)
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                Text(WatchPalette.meaning(for: key))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    // The Symmetric chip is the only one with a code suffix, so
                    // spell the codes out right under the badge key.
                    Text("Symmetric shows which way")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(symmetryLegend, id: \.code) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.code)
                                .font(.system(.caption2, design: .monospaced, weight: .black))
                                .foregroundStyle(WatchPalette.color(for: .symmetric))
                                .frame(width: 32, alignment: .leading)
                            Text(entry.meaning)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 1)
                    }
                }

                Divider()

                // Difficulty color key.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Difficulty")
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(.secondary)
                    ForEach(Difficulty.ordered, id: \.self) { tier in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(WatchPalette.color(for: tier))
                                .frame(width: 10, height: 10)
                            Text(tier.displayName)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .navigationTitle("Legend")
    }
}
