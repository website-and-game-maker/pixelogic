// The puzzle generator: pick a size, generate a brand-new provably-solvable
// puzzle, preview it, then save it to your Generated library, share it, or send
// the good ones to the developer.

import SwiftUI
import PixelogicKit

struct GeneratorView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var size = 8
    @State private var puzzle: Puzzle?
    @State private var working = false
    @State private var failed = false

    private let sizes = [5, 7, 8, 10]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Size", selection: $size) {
                    ForEach(sizes, id: \.self) { Text("\($0) × \($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: size) { _ in puzzle = nil; failed = false }

                Text("Every generated puzzle has exactly one solution and is solvable by pure logic — its difficulty is the engine's own verdict.")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let puzzle {
                    preview(puzzle)
                } else if working {
                    ProgressView("Generating…")
                        .padding(.vertical, 40)
                } else if failed {
                    Text("Couldn't find one that size — tap Generate to try again.")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.mistake)
                }

                Button { generate() } label: {
                    Label(puzzle == nil ? "Generate" : "Regenerate", systemImage: "wand.and.stars")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.brandGradient))
                        .foregroundStyle(.white)
                }
                .disabled(working)
            }
            .padding(.vertical)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Generate a puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .task { if puzzle == nil { generate() } }
    }

    @ViewBuilder
    private func preview(_ puzzle: Puzzle) -> some View {
        let badges = puzzleBadges(puzzle)
        VStack(spacing: 12) {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                DifficultyChip(difficulty: puzzle.difficulty)
                Chip(text: "\(puzzle.width) × \(puzzle.height)", bg: Theme.surface2, fg: Theme.inkSoft)
                ForEach(badges, id: \.key) { BadgeChipView(badge: $0) }
            }
            .padding(.horizontal)

            BoardView(puzzle: puzzle, marks: makeGrid(puzzle.height, puzzle.width),
                      clueStyle: .grey, mistakeCheck: false, interactive: false)
                .padding(.horizontal, 24)

            FlowLayout(spacing: 12, lineSpacing: 10) {
                Button {
                    let id = app.saveGenerated(title: puzzle.title, solution: puzzle.solution)
                    app.replaceTop(with: .playGenerated(id))
                } label: {
                    Label("Save & play", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryDeep)

                ShareLink(item: webShareURL(forToken: encodePuzzle(puzzle.solution, title: puzzle.title))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                if isWorthSubmitting(puzzle) {
                    Link(destination: sendURL(for: puzzle)) {
                        Label("Send to developer", systemImage: "paperplane")
                    }
                    .accessibilityHint("Email this puzzle's link to the developer")
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .padding(.horizontal)

            if !isWorthSubmitting(puzzle) {
                Text("Generate a trickier one (Medium+ or with a badge) to send it in.")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func generate() {
        working = true
        failed = false
        let s = size
        Task {
            let made = await Self.make(size: s)
            working = false
            if let made { puzzle = made } else { puzzle = nil; failed = true }
        }
    }

    /// Pure generation, off the main actor (a free `nonisolated` async function
    /// runs on the cooperative pool), so the UI stays responsive.
    private nonisolated static func make(size: Int) async -> Puzzle? {
        generatePuzzle(size: size)
    }

    private func sendURL(for puzzle: Puzzle) -> URL {
        let link = webShareURL(forToken: encodePuzzle(puzzle.solution, title: puzzle.title)).absoluteString
        let subject = "Pixelogic generated puzzle"
        let body = "I generated a \(puzzle.width)×\(puzzle.height) \(puzzle.difficulty.displayName) puzzle worth sharing:\n\n\(link)"
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = "jayanthisaahir@gmail.com"
        comps.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return comps.url ?? URL(string: "mailto:jayanthisaahir@gmail.com")!
    }
}
