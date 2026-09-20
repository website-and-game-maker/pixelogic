// Hint engine (port of src/ui/hints.ts): the next logically-forced cell given
// the player's current correct marks, with a human-readable reason.

public struct Hint: Sendable {
    public let r: Int
    public let c: Int
    public let value: Cell
    public let reason: String
}

private func isSolved(_ puzzle: Puzzle, _ marks: Grid) -> Bool {
    for r in 0..<puzzle.height {
        for c in 0..<puzzle.width where (marks[r][c] == .filled) != puzzle.solution[r][c] {
            return false
        }
    }
    return true
}

/// Build a solver grid keeping only the player's *correct* marks, so a hint is
/// always a valid logical deduction toward the real solution.
private func cleanState(_ puzzle: Puzzle, _ marks: Grid) -> Grid {
    var clean = marks
    for r in 0..<puzzle.height {
        for c in 0..<puzzle.width {
            let shouldFill = puzzle.solution[r][c]
            switch marks[r][c] {
            case .filled where shouldFill: break
            case .empty where !shouldFill: break
            default: clean[r][c] = .unknown
            }
        }
    }
    return clean
}

/// The next forced cell with a reason — or nil if the board is already solved.
public func nextHint(_ puzzle: Puzzle, marks: Grid) -> Hint? {
    if isSolved(puzzle, marks) { return nil }

    let clean = cleanState(puzzle, marks)
    if let step = deduceStep(puzzle.rowClues, puzzle.colClues, clean), let first = step.cells.first {
        return Hint(r: first.r, c: first.c, value: first.value, reason: step.caption)
    }

    // Fallback: point at the next cell from the known unique solution.
    for r in 0..<puzzle.height {
        for c in 0..<puzzle.width where clean[r][c] == .unknown {
            let value: Cell = puzzle.solution[r][c] ? .filled : .empty
            return Hint(r: r, c: c, value: value, reason: "This cell is fixed by the puzzle's only solution.")
        }
    }
    return nil
}
