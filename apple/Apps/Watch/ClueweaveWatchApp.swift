// Clueweave for Apple Watch — the "pocket set": small puzzles rethought for
// 5-second wrist sessions. See DESIGN.md for the rationale. The app keeps its
// clean board + scrolling list, and now adds difficulty sections, non-clickable
// badge indicators, a legend, a wrist-sized Tutorial / About / Settings, and a
// scene-aware play timer driven by ClueweaveKit's GameSession.

import SwiftUI
import ClueweaveKit

#if canImport(WatchKit)
import WatchKit
#endif

// Disambiguate from SwiftUI.Grid (a layout view) across this target.
typealias Grid = ClueweaveKit.Grid

@main
struct ClueweaveWatchApp: App {
    init() { migrateLegacyBrandKeys() }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
            }
        }
    }
}

/// The watch keeps its state in wrist-local `@AppStorage`, whose keys carry the
/// app name. The rebrand renamed them, which would silently orphan a player's
/// solved list, so adopt anything still sitting under the old prefix once.
private func migrateLegacyBrandKeys() {
    let defaults = UserDefaults.standard
    for suffix in ["completed", "tourSeen", "showTimer", "haptics"] {
        let old = "pixelogic.watch.\(suffix)"
        let new = "clueweave.watch.\(suffix)"
        guard defaults.object(forKey: new) == nil,
              let value = defaults.object(forKey: old) else { continue }
        defaults.set(value, forKey: new)
        defaults.removeObject(forKey: old)
    }
}

/// Minimal wrist-local progress (completion only — no scores on the wrist).
@MainActor
final class WatchProgress: ObservableObject {
    @AppStorage("clueweave.watch.completed") private var completedRaw = ""

    var completed: Set<String> {
        Set(completedRaw.split(separator: ",").map(String.init))
    }

    func markCompleted(_ id: String) {
        var set = completed
        set.insert(id)
        completedRaw = set.sorted().joined(separator: ",")
        objectWillChange.send()
    }
}

// MARK: - Wrist-sized library

/// Larger watches (≈ ≥ 195 pt wide) can host 7×7 cells at/above the touch
/// minimum; smaller watches stay 5×5-only. Detected once at launch.
let isLargeWatch: Bool = {
    #if canImport(WatchKit)
    return WKInterfaceDevice.current().screenBounds.width >= 195
    #else
    return false
    #endif
}()

/// Maximum board dimension this watch can comfortably render.
let watchMaxDim = isLargeWatch ? 7 : 5

/// The wrist-sized library: every 5×5, plus 7×7 on larger watches.
let watchLibrary: [Puzzle] = library.filter {
    $0.width <= watchMaxDim && $0.height <= watchMaxDim
}

/// The wrist library grouped by difficulty, in ascending tier order, keeping
/// only tiers that actually have watch-sized puzzles.
let watchSections: [(tier: Difficulty, puzzles: [Puzzle])] = Difficulty.ordered.compactMap { tier in
    let ps = watchLibrary.filter { $0.difficulty == tier }
    return ps.isEmpty ? nil : (tier, ps)
}

// MARK: - Home

struct WatchHomeView: View {
    @StateObject private var progress = WatchProgress()
    @AppStorage("clueweave.watch.tourSeen") private var tourSeen = false
    @State private var showTutorial = false

    /// The same `recommend()` the phone and web use, over watch-local completion
    /// data. The wrist deliberately does NOT run the state machine — no streaks
    /// here, so the working tier stays at its default. See
    /// docs/progression-model.md §9.
    private var recommendation: Recommendation? {
        recommend(ProgressionState(), watchLibrary, progress.completed, [:])
    }

    var body: some View {
        List {
            if let rec = recommendation,
               let pick = watchLibrary.first(where: { $0.id == rec.puzzleID }) {
                Section {
                    NavigationLink {
                        WatchPlayView(puzzle: pick, progress: progress)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pick.title)
                                .font(.system(.body, design: .rounded, weight: .heavy))
                            Text(rec.reason)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                        Text("Recommended")
                    }
                }
            }
            ForEach(watchSections, id: \.tier) { section in
                Section {
                    ForEach(section.puzzles) { p in
                        NavigationLink {
                            WatchPlayView(puzzle: p, progress: progress)
                        } label: {
                            WatchPuzzleRow(puzzle: p, done: progress.completed.contains(p.id))
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(WatchPalette.color(for: section.tier))
                            .frame(width: 8, height: 8)
                        Text(section.tier.displayName)
                    }
                }
            }
        }
        .navigationTitle("Clueweave")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    WatchMoreView()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            let done = watchLibrary.filter { progress.completed.contains($0.id) }.count
            if !watchLibrary.isEmpty && done == watchLibrary.count {
                Text("Pocket set complete! 🌿")
                    .font(.footnote.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.teal.opacity(0.28))) // Material is watchOS 10+
            }
        }
        .sheet(isPresented: $showTutorial) {
            NavigationStack {
                WatchTutorialView(onFinish: { showTutorial = false })
            }
        }
        .onAppear {
            if !tourSeen {
                tourSeen = true
                showTutorial = true
            }
        }
    }
}

/// A single puzzle row: completion dot, title, and non-clickable badge indicators.
struct WatchPuzzleRow: View {
    let puzzle: Puzzle
    let done: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(done ? .teal : .secondary)
            Text(puzzle.title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            WatchBadgeStrip(badges: puzzleBadges(puzzle))
        }
    }
}

/// Compact, NON-clickable badge indicators: a colored geometric glyph each.
struct WatchBadgeStrip: View {
    let badges: [Badge]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(badges, id: \.key) { badge in
                Image(systemName: badge.key.glyph)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WatchPalette.color(for: badge.key))
                    .accessibilityHidden(true)
            }
        }
    }
}
