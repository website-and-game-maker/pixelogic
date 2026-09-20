// Clue derivation (port of src/engine/clues.ts).

/// Run-length encode the filled runs of a line. `[]` for an all-empty line.
public func cluesForLine(_ line: [Bool]) -> Clue {
    var clue: [Int] = []
    var run = 0
    for filled in line {
        if filled {
            run += 1
        } else if run > 0 {
            clue.append(run)
            run = 0
        }
    }
    if run > 0 { clue.append(run) }
    return clue
}

/// Derive row and column clues from a solution grid.
public func cluesForGrid(_ solution: [[Bool]]) -> (rowClues: [Clue], colClues: [Clue]) {
    let height = solution.count
    let width = height > 0 ? solution[0].count : 0
    let rowClues = solution.map(cluesForLine)
    var colClues: [Clue] = []
    colClues.reserveCapacity(width)
    for c in 0..<width {
        var column: [Bool] = []
        column.reserveCapacity(height)
        for r in 0..<height { column.append(solution[r][c]) }
        colClues.append(cluesForLine(column))
    }
    return (rowClues, colClues)
}
