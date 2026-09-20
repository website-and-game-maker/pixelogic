// Clueweave for Apple Watch — the "pocket set": small puzzles rethought for
// 5-second wrist sessions. See DESIGN.md for the rationale. The app keeps its
// clean board + scrolling list, and now adds difficulty sections, non-clickable
// badge indicators, a legend, a wrist-sized Tutorial / About / Settings, and a
// scene-aware play timer driven by ClueweaveKit's GameSession.

import SwiftUI
import WidgetKit
import ClueweaveKit

#if canImport(WatchKit)
import WatchKit
#endif

// Disambiguate from SwiftUI.Grid (a layout view) across this target.
typealias Grid = ClueweaveKit.Grid

@main
struct ClueweaveWatchApp: App {
    @StateObject private var router = WatchRouter()
    @StateObject private var progress = WatchProgress()

    init() { migrateLegacyBrandKeys() }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                WatchHomeView(progress: progress)
                    .navigationDestination(for: WatchRoute.self) { route in
                        destination(for: route)
                    }
            }
            .environmentObject(router)
            .onAppear { progress.publishSnapshot() }
            .onOpenURL { url in
                // Complication taps. The watch has no import screen, so a
                // shared-puzzle link is not something it can honour — it lands
                // on the menu rather than failing silently.
                guard let link = parseClueweaveLink(url) else { return }
                router.open(link, progress: progress)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: WatchRoute) -> some View {
        switch route {
        case .play(let id):
            if let p = watchLibrary.first(where: { $0.id == id }) {
                WatchPlayView(puzzle: p, progress: progress)
            }
        case .tier(let tier):
            WatchTierListView(tier: tier, progress: progress)
        case .more:
            WatchMoreView()
        }
    }
}

/// Watch navigation. The wrist app used to be a plain stack with no path
/// binding, which is fine until a complication needs to push a screen — a
/// `widgetURL` can only ever arrive as a URL, so there has to be somewhere to
/// put the resulting destination.
enum WatchRoute: Hashable {
    case play(String)
    case tier(Difficulty)
    case more
}

@MainActor
final class WatchRouter: ObservableObject {
    @Published var path: [WatchRoute] = []

    func open(_ link: ClueweaveLink, progress: WatchProgress) {
        switch link {
        case .home, .share:
            path = []
        case .tier(let tier):
            path = [.tier(tier)]
        case .puzzle(let id):
            // The wrist only ships the pocket set; a phone-sized puzzle behind
            // a mirrored complication has nowhere to go here.
            path = watchLibrary.contains(where: { $0.id == id }) ? [.play(id)] : []
        case .resume(let id):
            guard progress.attempt?.puzzleID == id,
                  watchLibrary.contains(where: { $0.id == id }) else {
                path = []
                return
            }
            path = [.play(id)]
        case .recommended:
            let pick = recommend(ProgressionState(), watchLibrary, progress.completed, [:])
            if let pick { path = [WatchRoute.play(pick.puzzleID)] } else { path = [] }
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

/// An unfinished board, wrist-local. Stored as one string because that is all
/// `@AppStorage` is good for, and because the pocket set tops out at 7×7 — 49
/// characters, not a blob worth a second store.
///
/// Format: `<id>|<elapsedMs>|<w>x<h>|<cells>` where `cells` is the same
/// row-major `#`/`x`/`.` encoding the widget snapshot uses.
struct WatchAttempt: Equatable {
    var puzzleID: String
    var elapsedMs: Int
    var board: BoardPreview

    var encoded: String {
        "\(puzzleID)|\(elapsedMs)|\(board.width)x\(board.height)|\(board.cells)"
    }

    /// Tolerant: anything malformed reads as "no attempt", never a crash or a
    /// board of the wrong size pasted onto a different puzzle.
    init?(encoded: String) {
        let parts = encoded.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let dims = parts[2].split(separator: "x")
        guard let ms = Int(parts[1]), dims.count == 2,
              let w = Int(dims[0]), let h = Int(dims[1]),
              w > 0, h > 0, parts[3].count == w * h, !parts[0].isEmpty else { return nil }
        puzzleID = String(parts[0])
        elapsedMs = ms
        board = BoardPreview(width: w, height: h, cells: String(parts[3]))
    }

    init(puzzleID: String, elapsedMs: Int, marks: Grid) {
        self.puzzleID = puzzleID
        self.elapsedMs = elapsedMs
        self.board = BoardPreview(marks: marks)
    }
}

/// Minimal wrist-local progress: completion, one unfinished board, and the
/// snapshot the complications read.
///
/// Still no scores and still no sync — the watch is a standalone app by design
/// (contract §9). The complications read a snapshot built from *this* data, not
/// the phone's, so a watch with no paired iPhone shows the truth about itself.
@MainActor
final class WatchProgress: ObservableObject {
    @AppStorage("clueweave.watch.completed") private var completedRaw = ""
    @AppStorage("clueweave.watch.attempt") private var attemptRaw = ""

    var completed: Set<String> {
        Set(completedRaw.split(separator: ",").map(String.init))
    }

    /// The board to offer on the face, if there is one.
    var attempt: WatchAttempt? { WatchAttempt(encoded: attemptRaw) }

    func markCompleted(_ id: String) {
        var set = completed
        set.insert(id)
        completedRaw = set.sorted().joined(separator: ",")
        if attempt?.puzzleID == id { attemptRaw = "" }
        objectWillChange.send()
        publishSnapshot()
    }

    /// Save an unfinished board. A pristine one is cleared instead — a Continue
    /// complication offering a board with nothing on it is worse than an empty
    /// one, because it looks like the app lost your work.
    func saveAttempt(puzzleID: String, marks: Grid, elapsedMs: Int) {
        let touched = marks.contains { row in row.contains { $0 != .unknown } }
        attemptRaw = touched
            ? WatchAttempt(puzzleID: puzzleID, elapsedMs: elapsedMs, marks: marks).encoded
            : ""
        objectWillChange.send()
        publishSnapshot()
    }

    func clearAttempt(puzzleID: String) {
        guard attempt?.puzzleID == puzzleID else { return }
        attemptRaw = ""
        objectWillChange.send()
        publishSnapshot()
    }

    /// Restore a saved board for this puzzle, if the saved one *is* this puzzle
    /// and still has the right shape.
    func savedMarks(for puzzle: Puzzle) -> (marks: Grid, elapsedMs: Int)? {
        guard let a = attempt, a.puzzleID == puzzle.id,
              a.board.width == puzzle.width, a.board.height == puzzle.height else { return nil }
        return (a.board.grid, a.elapsedMs)
    }

    // MARK: - Complications

    /// Rebuild what the watch face reads, then ask WidgetKit to re-render.
    func publishSnapshot() {
        let source: ContinueSource? = attempt.flatMap { a in
            guard let p = watchLibrary.first(where: { $0.id == a.puzzleID }),
                  a.board.width == p.width, a.board.height == p.height else { return nil }
            return ContinueSource(puzzle: p, marks: a.board.grid, elapsedMs: a.elapsedMs)
        }
        SnapshotStore.write(makeWidgetSnapshot(
            library: watchLibrary,
            completed: completed,
            // No scores on the wrist, so no Clueweave Score and no
            // best-improvement branch — `recommend` falls back to curriculum
            // order, which is exactly what the home screen already shows.
            bestScores: [:],
            progression: ProgressionState(),
            continueFrom: source,
            score: nil
        ))
        WidgetCenter.shared.reloadAllTimelines()
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
    @ObservedObject var progress: WatchProgress
    @AppStorage("clueweave.watch.tourSeen") private var tourSeen = false
    @State private var showTutorial = false

    /// The same `recommend()` the phone and web use, over watch-local completion
    /// data. The wrist deliberately does NOT run the state machine — no streaks
    /// here, so the working tier stays at its default. See
    /// docs/progression-model.md §9.
    private var recommendation: Recommendation? {
        recommend(ProgressionState(), watchLibrary, progress.completed, [:])
    }

    /// The unfinished board, if it still matches a puzzle this watch ships.
    private var resumable: (puzzle: Puzzle, attempt: WatchAttempt)? {
        guard let a = progress.attempt,
              let p = watchLibrary.first(where: { $0.id == a.puzzleID }),
              a.board.width == p.width, a.board.height == p.height else { return nil }
        return (p, a)
    }

    var body: some View {
        List {
            if let (puzzle, attempt) = resumable {
                Section {
                    NavigationLink(value: WatchRoute.play(puzzle.id)) {
                        let done = solveProgress(marks: attempt.board.grid, solution: puzzle.solution)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(puzzle.title)
                                .font(.system(.body, design: .rounded, weight: .heavy))
                            Text("\(done.correct)/\(done.total) squares")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle")
                        Text("Continue")
                    }
                }
            }
            if let rec = recommendation,
               let pick = watchLibrary.first(where: { $0.id == rec.puzzleID }) {
                Section {
                    NavigationLink(value: WatchRoute.play(pick.id)) {
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
                        NavigationLink(value: WatchRoute.play(p.id)) {
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
                NavigationLink(value: WatchRoute.more) {
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

/// One difficulty, where a tier complication lands. The wrist list is short
/// enough that the phone's "pin the suggestion at the top" treatment would be
/// noise — the first unsolved row is already near the top.
struct WatchTierListView: View {
    let tier: Difficulty
    @ObservedObject var progress: WatchProgress

    private var puzzles: [Puzzle] { watchLibrary.filter { $0.difficulty == tier } }

    var body: some View {
        List {
            if puzzles.isEmpty {
                Text("No \(tier.displayName) puzzles fit this watch.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(puzzles) { p in
                        NavigationLink(value: WatchRoute.play(p.id)) {
                            WatchPuzzleRow(puzzle: p, done: progress.completed.contains(p.id))
                        }
                    }
                } header: {
                    let done = puzzles.filter { progress.completed.contains($0.id) }.count
                    Text("\(done) of \(puzzles.count) solved")
                }
            }
        }
        .navigationTitle(tier.displayName)
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
