// Player persistence (mirrors src/ui/persistence.ts semantics): best times,
// best scores, completion, settings, in-progress assist ledgers, and the
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

public struct SaveData: Codable, Sendable {
    public var completed: Set<String> = []
    /// Fastest solve time (ms) per puzzle id.
    public var bestTimes: [String: Int] = [:]
    /// Best per-puzzle score (0–100) per puzzle id.
    public var bestScores: [String: Int] = [:]
    /// Assists used in the current (in-progress) attempt, per puzzle id.
    public var assists: [String: AssistTally] = [:]
    public var settings = GameSettings()
    public var tutorialSeen = false
    /// True once progress has ever been wiped — disclosed when sharing a score.
    public var progressReset = false
    public init() {}
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
        if let raw = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
            cache = decoded
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

    // MARK: - Assist ledger (persists per-attempt penalties for library puzzles)

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
        d.progressReset = true
        data = d
    }
}
