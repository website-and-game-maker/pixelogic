// One difficulty, on its own screen. Where `clueweave://tier/<tier>` lands.
//
// A widget tap could have scrolled the menu to the right section instead, but a
// scroll offset is a guess that goes wrong the moment the library grows. A
// dedicated screen is unambiguous, and it has room to lead with the one thing a
// tier complication was already telling you: which puzzle to play next.

import SwiftUI
import ClueweaveKit

struct TierView: View {
    @EnvironmentObject private var app: AppModel
    let tier: Difficulty

    private let columns = [GridItem(.adaptive(minimum: 165), spacing: 14)]

    private var tierPuzzles: [Puzzle] { puzzles(in: tier) }

    /// The same suggestion the widget showed, recomputed here so the screen
    /// cannot disagree with the complication that opened it.
    private var suggestion: Puzzle? {
        tierSuggestion(tier, library, app.store.data.completed, app.store.data.bestScores)
    }

    private var solvedCount: Int {
        tierPuzzles.filter { app.store.isCompleted($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if let pick = suggestion {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(solvedCount == tierPuzzles.count
                             ? "Most score left to win" : "Next up")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.inkSoft)
                        NavigationLink(value: Route.play(pick.id)) {
                            PuzzleCard(puzzle: pick, store: app.store)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: 240)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(tierPuzzles) { p in
                        NavigationLink(value: Route.play(p.id)) {
                            PuzzleCard(puzzle: p, store: app.store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if tierPuzzles.isEmpty {
                    Text("No puzzles at this difficulty yet.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding()
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(tier.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        let colors = Theme.difficultyColors(tier)
        let fraction = tierPuzzles.isEmpty
            ? 0 : Double(solvedCount) / Double(tierPuzzles.count)
        return VStack(spacing: 10) {
            Text(tier.displayName)
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(colors.fg)
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(colors.fg)
            Text("\(solvedCount) of \(tierPuzzles.count) solved")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(colors.bg))
    }
}
