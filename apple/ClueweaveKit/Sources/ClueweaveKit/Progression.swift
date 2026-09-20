// Progression model — decides what you should play next, and notices when you're
// bored (breezing through) or struggling (stuck or giving up).
//
// Pure and UI-free: every function takes the library and the player's state as
// arguments rather than reaching for storage, so it is fully unit-testable and
// stays byte-for-byte behaviourally identical to the web implementation
// (src/engine/progression.ts).
//
// The rules and constants here are NORMATIVE and shared with the web app.
// See docs/progression-model.md — change a number here and you must change it
// there, in the TypeScript port, and in both test suites.

import Foundation

// MARK: - Tuning

/// Hints in a single attempt before it counts as struggling.
public let hintStruggleThreshold = 3

/// Consecutive smart-next presses with no solve before it degrades to plain next.
public let spamThreshold = 3

public enum FastSensitivity: String, Codable, CaseIterable, Sendable {
    case relaxed, normal, eager

    /// Fraction of par a clean solve must beat to read as "bored".
    public var factor: Double {
        switch self {
        case .relaxed: 0.5
        case .normal: 0.6
        case .eager: 0.75
        }
    }

    /// Consecutive fast solves needed before promoting a tier.
    public var streak: Int {
        switch self {
        case .relaxed: 3
        case .normal: 2
        case .eager: 2
        }
    }

    public var displayName: String {
        switch self {
        case .relaxed: "I'm well ahead (3 in a row)"
        case .normal: "I'm comfortable (2 in a row)"
        case .eager: "I'm even slightly quick (2 in a row)"
        }
    }
}

public enum StruggleSensitivity: String, Codable, CaseIterable, Sendable {
    case forgiving, normal, quick

    /// Consecutive struggles needed before demoting a tier.
    public var streak: Int {
        switch self {
        case .forgiving: 3
        case .normal: 2
        case .quick: 1
        }
    }

    public var displayName: String {
        switch self {
        case .forgiving: "I've struggled 3 times"
        case .normal: "I've struggled twice"
        case .quick: "I've struggled once"
        }
    }
}

public struct ProgressionSettings: Codable, Sendable, Equatable {
    /// Whether the top-right arrow is the sheened smart-next (off = plain next).
    public var smartNext = true
    /// Master switch for promote/demote. Off still records streaks.
    public var autoAdjustDifficulty = true
    public var fastSensitivity: FastSensitivity = .normal
    public var struggleSensitivity: StruggleSensitivity = .normal
    /// Whether heavy hint use counts as struggling.
    public var hintsCountAsStruggle = true
    public init() {}
}

// MARK: - State

public struct ProgressionState: Codable, Sendable, Equatable {
    /// The tier the recommender currently believes suits the player.
    public var workingTier: Difficulty = .easy
    public var fastStreak = 0
    public var struggleStreak = 0
    public var smartNextUses = 0
    public var smartNextPrompted = false
    public var spamCount = 0
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case workingTier, fastStreak, struggleStreak, smartNextUses, smartNextPrompted, spamCount
    }

    /// Every field decodes independently with a default, so a corrupt or partial
    /// progression block falls back gracefully instead of failing the whole save.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ type: T.Type, _ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)).flatMap { $0 } ?? fallback
        }
        workingTier = field(Difficulty.self, .workingTier, .easy)
        fastStreak = max(0, field(Int.self, .fastStreak, 0))
        struggleStreak = max(0, field(Int.self, .struggleStreak, 0))
        smartNextUses = max(0, field(Int.self, .smartNextUses, 0))
        smartNextPrompted = field(Bool.self, .smartNextPrompted, false)
        spamCount = max(0, field(Int.self, .spamCount, 0))
    }
}

// MARK: - Curriculum

/// The library in teaching order: tier-major, original order within a tier. Raw
/// library order interleaves tiers, which is exactly the "Medium → Easy" jump
/// this replaces.
public func curriculumOrder(_ library: [Puzzle]) -> [Puzzle] {
    library.enumerated()
        .sorted { a, b in
            let ta = a.element.difficulty.order
            let tb = b.element.difficulty.order
            return ta == tb ? a.offset < b.offset : ta < tb
        }
        .map(\.element)
}

/// Position of a puzzle in curriculum order, or nil if it isn't in the library.
public func curriculumIndex(_ library: [Puzzle], id: String) -> Int? {
    curriculumOrder(library).firstIndex { $0.id == id }
}

/// The puzzle `offset` steps away in curriculum order, or nil at either end.
/// Deliberately does NOT wrap: the first puzzle has no previous and the last has
/// no next, so the arrows can grey out honestly.
public func curriculumNeighbour(_ library: [Puzzle], id: String, offset: Int) -> String? {
    let ordered = curriculumOrder(library)
    guard let idx = ordered.firstIndex(where: { $0.id == id }) else { return nil }
    let next = idx + offset
    guard next >= 0, next < ordered.count else { return nil }
    return ordered[next].id
}

// MARK: - Signals

public enum Signal: String, Sendable, Equatable {
    case fastClean, gaveUp, struggled, normal, abandoned
}

public struct AttemptOutcome: Sendable {
    public let solved: Bool
    /// Fill out or Watch solve was used — the attempt already scores 0.
    public let voided: Bool
    public let assists: AssistTally
    public let elapsedMs: Int
    public let difficulty: Difficulty
    public let area: Int

    public init(
        solved: Bool, voided: Bool, assists: AssistTally,
        elapsedMs: Int, difficulty: Difficulty, area: Int
    ) {
        self.solved = solved
        self.voided = voided
        self.assists = assists
        self.elapsedMs = elapsedMs
        self.difficulty = difficulty
        self.area = area
    }
}

/// Classify one finished attempt. Order is precedence: a player who used Fill out
/// is `gaveUp` even if they were also fast, and a board check outranks a fast time.
public func classifySignal(_ a: AttemptOutcome, _ settings: ProgressionSettings) -> Signal {
    if a.voided || a.assists.voided { return .gaveUp }
    if !a.solved { return .abandoned }
    if a.assists.checkBoard > 0 { return .struggled }
    if settings.hintsCountAsStruggle && a.assists.hint >= hintStruggleThreshold { return .struggled }
    let clean = a.assists.penaltyTotal == 0
    let parMs = Double(parSeconds(a.difficulty, area: a.area)) * 1000.0
    if clean && Double(a.elapsedMs) <= settings.fastSensitivity.factor * parMs { return .fastClean }
    return .normal
}

// MARK: - Tier moves

private func tierStep(_ tier: Difficulty, _ step: Int) -> Difficulty? {
    let i = tier.order + step
    guard i >= 0, i < Difficulty.ordered.count else { return nil }
    return Difficulty.ordered[i]
}

private func hasUnsolved(_ library: [Puzzle], _ tier: Difficulty?, _ completed: Set<String>) -> Bool {
    guard let tier else { return false }
    return library.contains { $0.difficulty == tier && !completed.contains($0.id) }
}

/// Dropping a tier only helps if there is unfinished work down there. If the
/// player has already cleared the tier below AND the one below that, demoting
/// would hand them a puzzle they've solved instead of the challenge they're
/// stuck on — so they hold position.
public func canDemote(_ tier: Difficulty, _ library: [Puzzle], _ completed: Set<String>) -> Bool {
    guard tierStep(tier, -1) != nil else { return false }
    return hasUnsolved(library, tierStep(tier, -1), completed)
        || hasUnsolved(library, tierStep(tier, -2), completed)
}

/// Fold one signal into the player's progression state. Pure — returns a new
/// state and never mutates the input.
///
/// `fastStreak` and `struggleStreak` are mutually exclusive: evidence of one
/// zeroes the other, so a fast solve followed by a grind doesn't leave the
/// player "half promoted".
public func applySignal(
    _ signal: Signal,
    _ state: ProgressionState,
    _ settings: ProgressionSettings,
    _ library: [Puzzle],
    _ completed: Set<String>
) -> ProgressionState {
    var next = state
    if signal == .abandoned { return next }

    // Any finished attempt clears the smart-next spam guard.
    next.spamCount = 0

    switch signal {
    case .gaveUp, .struggled:
        next.struggleStreak = state.struggleStreak + 1
        next.fastStreak = 0
        if settings.autoAdjustDifficulty,
           next.struggleStreak >= settings.struggleSensitivity.streak {
            if canDemote(next.workingTier, library, completed),
               let below = tierStep(next.workingTier, -1) {
                next.workingTier = below
            }
            next.struggleStreak = 0  // reset whether or not we actually moved
        }

    case .fastClean:
        next.fastStreak = state.fastStreak + 1
        next.struggleStreak = 0
        if settings.autoAdjustDifficulty, next.fastStreak >= settings.fastSensitivity.streak {
            if let above = tierStep(next.workingTier, 1) {
                next.workingTier = above
            }
            next.fastStreak = 0
        }

    case .normal:
        next.fastStreak = 0
        next.struggleStreak = 0

    case .abandoned:
        break
    }
    return next
}

// MARK: - Recommendation

public struct Recommendation: Sendable, Equatable {
    public let puzzleID: String
    public let tier: Difficulty
    /// Player-facing copy explaining which branch fired.
    public let reason: String
}

private func firstUnsolvedIn(
    _ ordered: [Puzzle], _ tier: Difficulty, _ completed: Set<String>
) -> Puzzle? {
    ordered.first { $0.difficulty == tier && !completed.contains($0.id) }
}

/// What to play next. Walks the working tier, then upward, then downward, and
/// once the whole library is solved switches to "best improvement" — the puzzle
/// where raising the per-puzzle score would move the 0–1600 Clueweave Score most.
///
/// `excludeID` drops one puzzle from every branch. Callers acting as a "next"
/// affordance pass the puzzle currently on screen, because recommending the
/// puzzle you are already sitting on is never a useful answer to "what next?".
public func recommend(
    _ state: ProgressionState,
    _ library: [Puzzle],
    _ completed: Set<String>,
    _ bestScores: [String: Int],
    excludeID: String? = nil
) -> Recommendation? {
    let pool = excludeID.map { ex in library.filter { $0.id != ex } } ?? library
    guard !pool.isEmpty else { return nil }
    let ordered = curriculumOrder(pool)
    let at = state.workingTier.order

    // 1. the working tier itself
    if let here = firstUnsolvedIn(ordered, state.workingTier, completed) {
        return Recommendation(puzzleID: here.id, tier: here.difficulty,
                              reason: "Next up at your level.")
    }

    // 2. upward
    if at + 1 < Difficulty.ordered.count {
        for i in (at + 1)..<Difficulty.ordered.count {
            if let hit = firstUnsolvedIn(ordered, Difficulty.ordered[i], completed) {
                return Recommendation(
                    puzzleID: hit.id, tier: hit.difficulty,
                    reason: "You're breezing through — moving you up to \(hit.difficulty.displayName).")
            }
        }
    }

    // 3. downward
    if at > 0 {
        for i in stride(from: at - 1, through: 0, by: -1) {
            if let hit = firstUnsolvedIn(ordered, Difficulty.ordered[i], completed) {
                return Recommendation(
                    puzzleID: hit.id, tier: hit.difficulty,
                    reason: "Backing off to \(hit.difficulty.displayName) for a bit.")
            }
        }
    }

    // 4. everything solved — most score left to win
    var best: (puzzle: Puzzle, gain: Double)?
    for p in ordered {
        let gain = Double(100 - (bestScores[p.id] ?? 0))
            * p.difficulty.weight
            * badgeWeightMultiplier(puzzleBadges(p))
        if best == nil || gain > best!.gain {  // ties keep the earlier (lower) index
            best = (p, gain)
        }
    }
    guard let best else { return nil }
    return Recommendation(
        puzzleID: best.puzzle.id, tier: best.puzzle.difficulty,
        reason: "Everything's solved — this one has the most score left to win.")
}

/// Where the top-right arrow should go. Falls back to plain curriculum order when
/// smart next is switched off, or when the player is mashing it (the spam guard),
/// so a spammer gets a sane ordered walk instead of being flung around the library.
public func smartNextTarget(
    _ state: ProgressionState,
    currentPuzzleID: String,
    _ settings: ProgressionSettings,
    _ library: [Puzzle],
    _ completed: Set<String>,
    _ bestScores: [String: Int]
) -> Recommendation? {
    func plain() -> Recommendation? {
        guard let id = curriculumNeighbour(library, id: currentPuzzleID, offset: 1),
              let p = library.first(where: { $0.id == id }) else { return nil }
        return Recommendation(puzzleID: id, tier: p.difficulty, reason: "Next puzzle in order.")
    }
    if !settings.smartNext { return plain() }
    if state.spamCount >= spamThreshold { return plain() }
    return recommend(state, library, completed, bestScores, excludeID: currentPuzzleID)
}

/// Whether the first-use opt-out prompt should be shown for this press.
public func shouldPromptSmartNext(
    _ state: ProgressionState, _ settings: ProgressionSettings
) -> Bool {
    settings.smartNext && !state.smartNextPrompted && state.smartNextUses <= 3
}
