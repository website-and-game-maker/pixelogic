// What the widgets and complications actually read.
//
// A widget process must not decode `SaveData`: that blob carries every
// player-created and generated puzzle (full grids), and a complication
// refreshes on the system's schedule, not ours. So the apps distil their state
// into this small, self-sufficient snapshot and write it to the App Group; a
// widget then renders without touching the engine's library at all, which is
// also what lets a Continue widget draw a *custom* puzzle the extension has
// never heard of.
//
// The type is pure data and every builder here is a pure function, so all of it
// is covered by the verifier (no Xcode required).

import Foundation

// MARK: - Board preview

/// A board small enough to ship in a snapshot: one character per cell,
/// row-major. `#` filled, `x` crossed, `.` untouched.
public struct BoardPreview: Codable, Sendable, Equatable {
    public var width: Int
    public var height: Int
    public var cells: String

    public init(width: Int, height: Int, cells: String) {
        self.width = width
        self.height = height
        self.cells = cells
    }

    public init(marks: Grid) {
        self.height = marks.count
        self.width = marks.first?.count ?? 0
        self.cells = String(marks.flatMap { row in
            row.map { cell -> Character in
                switch cell {
                case .filled: return "#"
                case .empty: return "x"
                case .unknown: return "."
                }
            }
        })
    }

    /// The mark at `[r][c]`, or `.unknown` if the string is short/corrupt —
    /// a widget must never crash on a snapshot written by another app version.
    public func cell(_ r: Int, _ c: Int) -> Cell {
        guard r >= 0, c >= 0, r < height, c < width else { return .unknown }
        let i = r * width + c
        guard i >= 0, i < cells.count else { return .unknown }
        switch cells[cells.index(cells.startIndex, offsetBy: i)] {
        case "#": return .filled
        case "x": return .empty
        default: return .unknown
        }
    }

    /// Row-major marks, rebuilt. Cheaper for a widget than `cell(_:_:)` in a loop.
    public var grid: Grid {
        let chars = Array(cells)
        return (0..<height).map { r in
            (0..<width).map { c in
                let i = r * width + c
                guard i < chars.count else { return Cell.unknown }
                switch chars[i] {
                case "#": return .filled
                case "x": return .empty
                default: return .unknown
                }
            }
        }
    }
}

// MARK: - Progress

/// How far along an attempt is, measured as *correctly filled cells over the
/// cells the finished picture fills*.
///
/// The obvious metric — cells marked either way — is wrong here: crossing is
/// optional, so a player who never crosses would sit at 40% on a solved board.
/// Counting filled-and-correct reaches exactly 1.0 the moment the puzzle is
/// solved, and a wrong fill simply doesn't count toward it.
public func solveProgress(marks: Grid, solution: [[Bool]]) -> (correct: Int, total: Int) {
    var correct = 0
    var total = 0
    for (r, row) in solution.enumerated() {
        for (c, filled) in row.enumerated() where filled {
            total += 1
            if r < marks.count, c < marks[r].count, marks[r][c] == .filled { correct += 1 }
        }
    }
    return (correct, total)
}

// MARK: - Snapshot pieces

public struct ContinueSnapshot: Codable, Sendable, Equatable {
    public var puzzleID: String
    public var title: String
    public var difficulty: Difficulty
    /// Correctly filled cells, and how many the finished picture has.
    public var correct: Int
    public var totalFilled: Int
    public var elapsedMs: Int
    public var board: BoardPreview

    public init(
        puzzleID: String, title: String, difficulty: Difficulty,
        correct: Int, totalFilled: Int, elapsedMs: Int, board: BoardPreview
    ) {
        self.puzzleID = puzzleID
        self.title = title
        self.difficulty = difficulty
        self.correct = correct
        self.totalFilled = totalFilled
        self.elapsedMs = elapsedMs
        self.board = board
    }

    /// 0…1, for a progress ring. Always finite, never > 1.
    public var fraction: Double {
        guard totalFilled > 0 else { return 0 }
        return min(1, Double(correct) / Double(totalFilled))
    }

    public var link: ClueweaveLink { .resume(puzzleID) }
}

public struct TierSnapshot: Codable, Sendable, Equatable {
    public var tier: Difficulty
    public var solved: Int
    public var total: Int
    /// What `tierSuggestion` says to play in this tier right now (nil = tier empty).
    public var suggestionID: String?
    public var suggestionTitle: String?

    public init(
        tier: Difficulty, solved: Int, total: Int,
        suggestionID: String? = nil, suggestionTitle: String? = nil
    ) {
        self.tier = tier
        self.solved = solved
        self.total = total
        self.suggestionID = suggestionID
        self.suggestionTitle = suggestionTitle
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(solved) / Double(total))
    }

    public var isComplete: Bool { total > 0 && solved >= total }
    public var link: ClueweaveLink { .tier(tier) }
}

public struct RecommendationSnapshot: Codable, Sendable, Equatable {
    public var puzzleID: String
    public var title: String
    public var difficulty: Difficulty
    public var reason: String

    public init(puzzleID: String, title: String, difficulty: Difficulty, reason: String) {
        self.puzzleID = puzzleID
        self.title = title
        self.difficulty = difficulty
        self.reason = reason
    }

    public var link: ClueweaveLink { .puzzle(puzzleID) }
}

// MARK: - The snapshot

public struct WidgetSnapshot: Codable, Sendable, Equatable {
    /// Bumped only if a field's *meaning* changes; new fields decode tolerantly.
    public static let currentVersion = 1

    public var version: Int
    public var updatedAt: Date
    /// 0–1600 Clueweave Score, or nil on a surface that doesn't keep scores
    /// (the watch tracks completion only — see docs/progression-model.md §9).
    public var score: Int?
    public var solved: Int
    public var total: Int
    public var workingTier: Difficulty
    public var tiers: [TierSnapshot]
    public var continueEntry: ContinueSnapshot?
    public var recommendation: RecommendationSnapshot?

    public init(
        version: Int = WidgetSnapshot.currentVersion,
        updatedAt: Date = Date(),
        score: Int? = nil,
        solved: Int = 0,
        total: Int = 0,
        workingTier: Difficulty = .easy,
        tiers: [TierSnapshot] = [],
        continueEntry: ContinueSnapshot? = nil,
        recommendation: RecommendationSnapshot? = nil
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.score = score
        self.solved = solved
        self.total = total
        self.workingTier = workingTier
        self.tiers = tiers
        self.continueEntry = continueEntry
        self.recommendation = recommendation
    }

    private enum CodingKeys: String, CodingKey {
        case version, updatedAt, score, solved, total, workingTier, tiers,
             continueEntry, recommendation
    }

    /// Field-by-field, like `SaveData`: a snapshot written by a newer app must
    /// still render something on an older widget rather than blanking the face.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ type: T.Type, _ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)).flatMap { $0 } ?? fallback
        }
        version = field(Int.self, .version, WidgetSnapshot.currentVersion)
        updatedAt = field(Date.self, .updatedAt, Date(timeIntervalSince1970: 0))
        score = (try? c.decodeIfPresent(Int.self, forKey: .score)) ?? nil
        solved = field(Int.self, .solved, 0)
        total = field(Int.self, .total, 0)
        workingTier = field(Difficulty.self, .workingTier, .easy)
        tiers = field([TierSnapshot].self, .tiers, [])
        continueEntry = (try? c.decodeIfPresent(ContinueSnapshot.self, forKey: .continueEntry)) ?? nil
        recommendation = (try? c.decodeIfPresent(RecommendationSnapshot.self, forKey: .recommendation)) ?? nil
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(solved) / Double(total))
    }

    public func tier(_ d: Difficulty) -> TierSnapshot? { tiers.first { $0.tier == d } }

    /// Where a single-tap complication should go when it has one shot: the
    /// unfinished board if there is one, otherwise what to play next, otherwise
    /// just open the app. A blank complication is wasted face real estate.
    public var primaryLink: ClueweaveLink {
        if let c = continueEntry { return c.link }
        if let r = recommendation { return r.link }
        return .home
    }
}

// MARK: - Builders

/// What the app hands the builder for the "continue" slot: the resolved puzzle
/// (library, custom or generated) plus the saved board.
public struct ContinueSource: Sendable {
    public var puzzle: Puzzle
    public var marks: Grid
    public var elapsedMs: Int

    public init(puzzle: Puzzle, marks: Grid, elapsedMs: Int) {
        self.puzzle = puzzle
        self.marks = marks
        self.elapsedMs = elapsedMs
    }
}

/// What a per-difficulty widget/complication offers for one tier.
///
/// First unsolved puzzle in curriculum order, so the tier badge is always a
/// live "here's your next one" rather than a static label. Once the tier is
/// finished it switches to the puzzle with the most score left to win — the
/// same gain formula `recommend()` uses when the whole library is solved, so
/// the two can never disagree about what "worth replaying" means.
public func tierSuggestion(
    _ tier: Difficulty,
    _ library: [Puzzle],
    _ completed: Set<String>,
    _ bestScores: [String: Int]
) -> Puzzle? {
    let ordered = curriculumOrder(library).filter { $0.difficulty == tier }
    guard !ordered.isEmpty else { return nil }
    if let next = ordered.first(where: { !completed.contains($0.id) }) { return next }

    var best: (puzzle: Puzzle, gain: Double)?
    for p in ordered {
        let gain = Double(100 - (bestScores[p.id] ?? 0))
            * p.difficulty.weight
            * badgeWeightMultiplier(puzzleBadges(p))
        if best == nil || gain > best!.gain {  // ties keep the earlier (lower) index
            best = (p, gain)
        }
    }
    return best?.puzzle
}

public func makeWidgetSnapshot(
    library: [Puzzle],
    completed: Set<String>,
    bestScores: [String: Int] = [:],
    progression: ProgressionState = ProgressionState(),
    continueFrom: ContinueSource? = nil,
    score: Int? = nil,
    now: Date = Date()
) -> WidgetSnapshot {
    let tiers: [TierSnapshot] = Difficulty.ordered.compactMap { tier in
        let inTier = library.filter { $0.difficulty == tier }
        guard !inTier.isEmpty else { return nil }
        let suggestion = tierSuggestion(tier, library, completed, bestScores)
        return TierSnapshot(
            tier: tier,
            solved: inTier.filter { completed.contains($0.id) }.count,
            total: inTier.count,
            suggestionID: suggestion?.id,
            suggestionTitle: suggestion?.title
        )
    }

    let cont: ContinueSnapshot? = continueFrom.map { src in
        let p = solveProgress(marks: src.marks, solution: src.puzzle.solution)
        return ContinueSnapshot(
            puzzleID: src.puzzle.id,
            title: src.puzzle.title,
            difficulty: src.puzzle.difficulty,
            correct: p.correct,
            totalFilled: p.total,
            elapsedMs: src.elapsedMs,
            board: BoardPreview(marks: src.marks)
        )
    }

    // Never point "what next" at the board the player is already mid-way through.
    let rec: RecommendationSnapshot? = recommend(
        progression, library, completed, bestScores, excludeID: continueFrom?.puzzle.id
    ).map { r in
        RecommendationSnapshot(
            puzzleID: r.puzzleID,
            title: library.first(where: { $0.id == r.puzzleID })?.title ?? r.puzzleID,
            difficulty: r.tier,
            reason: r.reason
        )
    }

    return WidgetSnapshot(
        updatedAt: now,
        score: score,
        solved: library.filter { completed.contains($0.id) }.count,
        total: library.count,
        workingTier: progression.workingTier,
        tiers: tiers,
        continueEntry: cont,
        recommendation: rec
    )
}

// MARK: - Storage

/// Reads and writes the snapshot in the App Group. Both apps write; both widget
/// bundles read. Deliberately tolerant on read — a widget with a missing or
/// unreadable snapshot shows its empty state, it does not crash the face.
public enum SnapshotStore {
    public static let key = "clueweave.widget.v1"

    public static func write(_ snapshot: WidgetSnapshot, to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public static func read(from defaults: UserDefaults = AppGroup.defaults) -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public static func clear(from defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: key)
    }
}
