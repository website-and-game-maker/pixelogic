// Player persistence (mirrors src/ui/persistence.ts semantics): best times,
// best scores, completion, settings, in-progress attempt snapshots, and the
// honour-system progress-reset flag. Backed by UserDefaults; everything stays
// on-device (no accounts, no network).

import Foundation

/// How a clue is drawn once its line is complete.
public enum ClueStyle: String, Codable, CaseIterable, Sendable {
    case grey, strike, hide, none

    public var displayName: String {
        switch self {
        case .grey: "Grey out"
        case .strike: "Strike through"
        case .hide: "Hide them"
        case .none: "Leave them"
        }
    }
}

public struct GameSettings: Codable, Sendable, Equatable {
    public var mistakeCheck = false
    public var showTimer = true
    public var clueStyle: ClueStyle = .grey
    public var autoCross = false
    public init() {}
}

/// A player-created puzzle (kept across progress resets, like the web app).
public struct StoredPuzzle: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var solution: [[Bool]]
    public init(id: String, title: String, solution: [[Bool]]) {
        self.id = id
        self.title = title
        self.solution = solution
    }

    public var asPuzzle: Puzzle {
        Puzzle(id: id, title: title, solution: solution, difficulty: gradeGrid(solution))
    }
}

/// A snapshot of an unfinished attempt, so quitting the app never loses a
/// board: marks, the paused clock, and any assist penalties already incurred.
public struct InProgressAttempt: Codable, Sendable, Equatable {
    /// `Cell` raw values, `[row][col]`.
    public var marks: [[UInt8]]
    public var elapsedMs: Int
    public var assists: AssistTally

    public init(marks: Grid, elapsedMs: Int, assists: AssistTally) {
        self.marks = marks.map { $0.map(\.rawValue) }
        self.elapsedMs = elapsedMs
        self.assists = assists
    }

    public var grid: Grid { marks.map { $0.map { Cell(rawValue: $0) ?? .unknown } } }
}

/// Decodes `T` but never throws: a malformed element becomes `nil` instead of
/// failing the whole container. Used so a single corrupt custom-puzzle entry
/// can't wipe a player's entire collection.
private struct Failable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

public struct SaveData: Codable, Sendable {
    public var completed: Set<String> = []
    /// Fastest solve time (ms) per puzzle id.
    public var bestTimes: [String: Int] = [:]
    /// Best per-puzzle score (0–100) per puzzle id.
    public var bestScores: [String: Int] = [:]
    /// Assists used in the current (in-progress) attempt, per puzzle id.
    /// Superseded by `inProgress` (which carries the whole board); kept so
    /// old saves round-trip.
    public var assists: [String: AssistTally] = [:]
    /// Player-created puzzles.
    public var userPuzzles: [StoredPuzzle] = []
    public var settings = GameSettings()
    public var tutorialSeen = false
    /// True once progress has ever been wiped — disclosed when sharing a score.
    public var progressReset = false
    /// Unfinished attempts, per puzzle id (board + clock + assists).
    public var inProgress: [String: InProgressAttempt] = [:]
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case completed, bestTimes, bestScores, assists, userPuzzles,
             settings, tutorialSeen, progressReset, inProgress
    }

    /// Every field decodes independently with a default, so a save written by
    /// ANY app version — older (missing keys) or newer (extra keys) — loads
    /// without wiping the player's progress.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ type: T.Type, _ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)).flatMap { $0 } ?? fallback
        }
        completed = field(Set<String>.self, .completed, [])
        bestTimes = field([String: Int].self, .bestTimes, [:])
        bestScores = field([String: Int].self, .bestScores, [:])
        assists = field([String: AssistTally].self, .assists, [:])
        // Custom puzzles are the one thing promised to survive everything, so
        // decode them element by element: a corrupt entry is dropped, the rest live.
        if let wrapped = try? c.decodeIfPresent([Failable<StoredPuzzle>].self, forKey: .userPuzzles) {
            userPuzzles = (wrapped ?? []).compactMap(\.value)
        } else {
            userPuzzles = []
        }
        settings = field(GameSettings.self, .settings, GameSettings())
        tutorialSeen = field(Bool.self, .tutorialSeen, false)
        progressReset = field(Bool.self, .progressReset, false)
        inProgress = field([String: InProgressAttempt].self, .inProgress, [:])
    }
}

/// Single source of truth for player data. `@unchecked Sendable` is safe: all
/// mutation is funneled through the main actor in the apps; the store itself is
/// a value-semantics wrapper over UserDefaults.
public final class PlayerStore: @unchecked Sendable {
    public static let storageKey = "pixelogic.save.v1"

    private let defaults: UserDefaults
    private var cache: SaveData

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.data(forKey: Self.storageKey) {
            if let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
                cache = decoded
            } else {
                // Never silently destroy a corrupt save — stash it for recovery.
                defaults.set(raw, forKey: Self.storageKey + ".corrupt")
                cache = SaveData()
            }
        } else {
            cache = SaveData()
        }
    }

    public private(set) var data: SaveData {
        get { cache }
        set {
            cache = newValue
            if let raw = try? JSONEncoder().encode(newValue) {
                defaults.set(raw, forKey: Self.storageKey)
            }
        }
    }

    // MARK: - Settings

    public var settings: GameSettings {
        get { data.settings }
        set { data.settings = newValue }
    }

    public var tutorialSeen: Bool {
        get { data.tutorialSeen }
        set { data.tutorialSeen = newValue }
    }

    // MARK: - Completion / times / scores

    public func isCompleted(_ id: String) -> Bool { data.completed.contains(id) }

    public func markCompleted(_ id: String) {
        var d = data
        d.completed.insert(id)
        d.assists.removeValue(forKey: id)
        d.inProgress.removeValue(forKey: id)
        data = d
    }

    public func bestTime(for id: String) -> Int? { data.bestTimes[id] }

    /// Record a solve time, keeping only the fastest. Returns (best, isNew).
    @discardableResult
    public func recordBestTime(_ id: String, elapsedMs: Int) -> (best: Int, isNew: Bool) {
        var d = data
        if let prev = d.bestTimes[id], prev <= elapsedMs {
            return (prev, false)
        }
        d.bestTimes[id] = elapsedMs
        data = d
        return (elapsedMs, true)
    }

    public func bestScore(for id: String) -> Int? { data.bestScores[id] }

    /// Record a per-puzzle score (0–100), keeping the best. Returns (best, isNew).
    @discardableResult
    public func recordScore(_ id: String, score: Int) -> (best: Int, isNew: Bool) {
        var d = data
        if let prev = d.bestScores[id], prev >= score {
            return (prev, false)
        }
        d.bestScores[id] = score
        data = d
        return (score, true)
    }

    // MARK: - In-progress attempts (quit the app, keep the board)

    public func inProgress(for id: String) -> InProgressAttempt? { data.inProgress[id] }

    public func saveInProgress(_ attempt: InProgressAttempt, for id: String) {
        var d = data
        d.inProgress[id] = attempt
        data = d
    }

    public func clearInProgress(for id: String) {
        guard data.inProgress[id] != nil else { return }
        var d = data
        d.inProgress.removeValue(forKey: id)
        data = d
    }

    // MARK: - Assist ledger (superseded by in-progress attempts; kept for old saves)

    public func assists(for id: String) -> AssistTally { data.assists[id] ?? AssistTally() }

    public func setAssists(_ tally: AssistTally, for id: String) {
        var d = data
        d.assists[id] = tally
        data = d
    }

    public func clearAssists(for id: String) {
        var d = data
        d.assists.removeValue(forKey: id)
        data = d
    }

    // MARK: - Custom puzzles

    public var userPuzzles: [StoredPuzzle] { data.userPuzzles }

    /// Insert or update (same id replaces — no accidental duplicates).
    public func saveUserPuzzle(_ puzzle: StoredPuzzle) {
        var d = data
        if let idx = d.userPuzzles.firstIndex(where: { $0.id == puzzle.id }) {
            d.userPuzzles[idx] = puzzle
        } else {
            d.userPuzzles.append(puzzle)
        }
        data = d
    }

    /// Import a shared puzzle. An identical picture that's already in the
    /// collection is reused (no duplicate cards from re-tapping a link).
    @discardableResult
    public func importUserPuzzle(title: String, solution: [[Bool]]) -> String {
        if let existing = userPuzzles.first(where: { $0.solution == solution }) {
            return existing.id
        }
        let id = "u-\(UUID().uuidString.prefix(8))"
        saveUserPuzzle(StoredPuzzle(id: id, title: title, solution: solution))
        return id
    }

    public func deleteUserPuzzles(ids: Set<String>) {
        var d = data
        d.userPuzzles.removeAll { ids.contains($0.id) }
        for id in ids { d.inProgress.removeValue(forKey: id) }
        data = d
    }

    // MARK: - Pixelogic Score

    public var pixelogicScore: Int {
        PixelogicKit.pixelogicScore(
            bestScores: data.bestScores,
            library: library.map {
                PuzzleMeta(
                    id: $0.id,
                    difficulty: $0.difficulty,
                    weightMult: badgeWeightMultiplier(puzzleBadges($0))
                )
            }
        )
    }

    public var wasProgressReset: Bool { data.progressReset }

    /// Danger zone: wipe solved/in-progress state and records. Keeps settings.
    /// Sets a permanent flag so a shared Pixelogic Score can disclose the reset.
    public func resetProgress() {
        var d = data
        d.completed = []
        d.bestTimes = [:]
        d.bestScores = [:]
        d.assists = [:]
        d.inProgress = [:]
        d.progressReset = true
        data = d
    }
}
