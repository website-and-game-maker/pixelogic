// Pure scoring model (port of src/engine/scoring.ts).
//
// Per-puzzle score (0–100):  round(100 × min(1, par/bestTime)) − assist penalties.
// Pixelogic Score (0–1600):  difficulty- and badge-weighted average of best
//                            per-puzzle scores across the whole library.

import Foundation

extension Difficulty {
    /// How much a tier contributes to the overall rating. Harder ⇒ worth far more.
    public var weight: Double {
        switch self {
        case .easy: 1
        case .medium: 2
        case .hard: 4
        case .expert: 7
        case .max: 12
        }
    }

    /// Target ("par") seconds-per-cell by tier.
    var secondsPerCell: Double {
        switch self {
        case .easy: 1.0
        case .medium: 1.5
        case .hard: 2.2
        case .expert: 3.2
        case .max: 4.5
        }
    }

    /// How many "Check square" reveals a tier allows per attempt (nil = unlimited).
    public var checkBudget: Int? {
        switch self {
        case .easy, .medium: nil
        case .hard: 3
        case .expert: 2
        case .max: 1
        }
    }
}

/// Par time for a puzzle, in whole seconds.
public func parSeconds(_ difficulty: Difficulty, area: Int) -> Int {
    Int((Double(area) * difficulty.secondsPerCell).rounded())
}

/// Assist usage during a single solve attempt.
public struct AssistTally: Codable, Sendable, Equatable {
    public var checkSquare: Int = 0
    public var checkLine: Int = 0
    public var checkBoard: Int = 0
    public var hint: Int = 0
    /// Fill-out or Watch-solve was used — the attempt scores 0.
    public var voided: Bool = false

    public init() {}

    public static let penaltyCheckSquare = 5
    public static let penaltyCheckLine = 15
    public static let penaltyCheckBoard = 40
    public static let penaltyHint = 20

    public var penaltyTotal: Int {
        checkSquare * Self.penaltyCheckSquare
            + checkLine * Self.penaltyCheckLine
            + checkBoard * Self.penaltyCheckBoard
            + hint * Self.penaltyHint
    }
}

/// Per-puzzle score in [0,100]. Hitting par (or faster) gives full speed credit.
public func puzzleScore(
    difficulty: Difficulty, area: Int, bestTimeMs: Int, assists: AssistTally
) -> Int {
    if assists.voided || bestTimeMs <= 0 { return 0 }
    let par = Double(parSeconds(difficulty, area: area))
    let speed = min(1.0, par / (Double(bestTimeMs) / 1000.0))
    let raw = (100.0 * speed).rounded() - Double(assists.penaltyTotal)
    return max(0, min(100, Int(raw)))
}

public struct PuzzleMeta: Sendable {
    public let id: String
    public let difficulty: Difficulty
    /// Badge weight multiplier (<1 for easier-badge puzzles, >1 for harder ones).
    public let weightMult: Double

    public init(id: String, difficulty: Difficulty, weightMult: Double = 1) {
        self.id = id
        self.difficulty = difficulty
        self.weightMult = weightMult
    }
}

/// Overall Pixelogic Score in [0,1600]. Unsolved puzzles count as 0; badge
/// multipliers shift each puzzle's share (a perfect run is 1600 regardless).
public func pixelogicScore(bestScores: [String: Int], library: [PuzzleMeta]) -> Int {
    var earned = 0.0
    var possible = 0.0
    for p in library {
        let w = p.difficulty.weight * p.weightMult
        possible += w
        earned += w * (Double(bestScores[p.id] ?? 0) / 100.0)
    }
    return possible > 0 ? Int((1600.0 * earned / possible).rounded()) : 0
}

/// A flavour title for a Pixelogic Score, shown beneath the laurel.
public func scoreTitle(_ score: Int) -> String {
    switch score {
    case 1500...: "Grandmaster"
    case 1350...: "Master"
    case 1100...: "Expert"
    case 850...: "Sharp"
    case 550...: "Solver"
    case 250...: "Apprentice"
    default: "Novice"
    }
}
