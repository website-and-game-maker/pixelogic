// Core types for the Clueweave logic engine. Pure data — no UI, no side effects.
// A faithful Swift port of the web engine (src/engine/types.ts).

/// Tri-state cell used by the solver.
public enum Cell: UInt8, Sendable, Equatable {
    case unknown
    case filled
    case empty
}

/// Run lengths of consecutive filled cells in a line. `[]` means no filled cells.
public typealias Clue = [Int]

/// A solver working grid, indexed `[row][col]`.
public typealias Grid = [[Cell]]

/// `expert` is shown as "Extra Hard"; `max` is the curated, brutal top tier.
public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy, medium, hard, expert, max

    /// Tiers in ascending order of difficulty.
    public static let ordered: [Difficulty] = [.easy, .medium, .hard, .expert, .max]

    public var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .expert: "Extra Hard"
        case .max: "MAX"
        }
    }

    var order: Int { Difficulty.ordered.firstIndex(of: self)! }
}

public struct Puzzle: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let width: Int
    public let height: Int
    /// The intended solution, indexed `[row][col]`.
    public let solution: [[Bool]]
    public let rowClues: [Clue]
    public let colClues: [Clue]
    public let difficulty: Difficulty
    /// Optional flavour note explaining the title (shown after solving).
    public let note: String?
    /// True when the title plainly describes the picture (Name-hint badge).
    public let named: Bool

    public var area: Int { width * height }

    public init(
        id: String,
        title: String,
        solution: [[Bool]],
        difficulty: Difficulty,
        note: String? = nil,
        named: Bool = false
    ) {
        self.id = id
        self.title = title
        self.height = solution.count
        self.width = solution.first?.count ?? 0
        self.solution = solution
        let clues = cluesForGrid(solution)
        self.rowClues = clues.rowClues
        self.colClues = clues.colClues
        self.difficulty = difficulty
        self.note = note
        self.named = named
    }
}

/// Parse a `#`/`.` bitmap (any non-`#` char is empty) into a boolean grid.
public func bitmapToGrid(_ rows: [String]) -> [[Bool]] {
    rows.map { row in row.map { $0 == "#" } }
}
