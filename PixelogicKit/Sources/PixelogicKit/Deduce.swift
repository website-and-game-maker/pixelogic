// Step-by-step logical deduction with human-readable proofs
// (port of src/engine/deduce.ts).

public struct DeducedCell: Sendable, Equatable {
    public let r: Int
    public let c: Int
    public let value: Cell
}

public enum Technique: String, Sendable {
    case line, contradiction
}

public struct Deduction: Sendable {
    public let cells: [DeducedCell]
    public let caption: String
    public let technique: Technique
}

func clueText(_ clue: Clue) -> String {
    clue.isEmpty ? "0" : clue.map(String.init).joined(separator: " ")
}

private func describe(_ cells: [DeducedCell]) -> String {
    let fills = cells.filter { $0.value == .filled }.count
    let empties = cells.count - fills
    var parts: [String] = []
    if fills > 0 { parts.append("fill \(fills)") }
    if empties > 0 { parts.append("cross \(empties)") }
    return parts.joined(separator: " and ")
}

/// A plain-language, undeniably-true reason for a single-line deduction.
private func lineCaption(
    _ kind: String, _ index: Int, _ clue: Clue, _ lineLen: Int, _ cells: [DeducedCell]
) -> String {
    let label = "\(kind) \(index + 1)"
    let action = describe(cells)
    if clue.isEmpty {
        return "\(label)'s clue is 0 — nothing is filled there, so cross every cell (\(action))."
    }
    let sum = clue.reduce(0, +)
    if sum + (clue.count - 1) == lineLen {
        return "\(label)'s clue \(clueText(clue)) fits the line only one way, fixing every cell — \(action)."
    }
    return "\(label): every placement of clue \(clueText(clue)) that fits what's already known agrees on these cells, so they're forced — \(action)."
}

/// Find the next logical deduction for the current grid. Single-line deductions
/// are preferred; if none remain, a depth-1 contradiction is attempted.
public func deduceStep(_ rowClues: [Clue], _ colClues: [Clue], _ grid: Grid) -> Deduction? {
    let h = rowClues.count
    let w = colClues.count

    // 1) Single-line deductions.
    for r in 0..<h {
        guard let solved = solveLine(grid[r], rowClues[r]) else { continue }
        var cells: [DeducedCell] = []
        for c in 0..<w where grid[r][c] == .unknown && solved[c] != .unknown {
            cells.append(DeducedCell(r: r, c: c, value: solved[c]))
        }
        if !cells.isEmpty {
            return Deduction(
                cells: cells,
                caption: lineCaption("Row", r, rowClues[r], w, cells),
                technique: .line
            )
        }
    }
    for c in 0..<w {
        guard let solved = solveLine(column(of: grid, c), colClues[c]) else { continue }
        var cells: [DeducedCell] = []
        for r in 0..<h where grid[r][c] == .unknown && solved[r] != .unknown {
            cells.append(DeducedCell(r: r, c: c, value: solved[r]))
        }
        if !cells.isEmpty {
            return Deduction(
                cells: cells,
                caption: lineCaption("Column", c, colClues[c], h, cells),
                technique: .line
            )
        }
    }

    // 2) Depth-1 contradiction (hypothesis testing).
    for r in 0..<h {
        for c in 0..<w where grid[r][c] == .unknown {
            var gF = grid
            gF[r][c] = .filled
            if propagate(rowClues, colClues, start: gF).status == .contradiction {
                return Deduction(
                    cells: [DeducedCell(r: r, c: c, value: .empty)],
                    caption: "Suppose R\(r + 1)C\(c + 1) were filled: propagating the clues hits a contradiction. So it must be crossed.",
                    technique: .contradiction
                )
            }
            var gE = grid
            gE[r][c] = .empty
            if propagate(rowClues, colClues, start: gE).status == .contradiction {
                return Deduction(
                    cells: [DeducedCell(r: r, c: c, value: .filled)],
                    caption: "Suppose R\(r + 1)C\(c + 1) were crossed: propagating the clues hits a contradiction. So it must be filled.",
                    technique: .contradiction
                )
            }
        }
    }

    return nil
}

/// Solve purely by logic — line deductions plus depth-1 contradiction.
public func solveByLogic(
    _ rowClues: [Clue], _ colClues: [Clue]
) -> (solved: Bool, grid: Grid, steps: [Deduction]) {
    let h = rowClues.count
    let w = colClues.count
    var grid = makeGrid(h, w)
    var steps: [Deduction] = []
    let maxSteps = h * w * 2 + 50
    var guardCount = 0
    while !isComplete(grid) && guardCount < maxSteps {
        guardCount += 1
        guard let step = deduceStep(rowClues, colClues, grid) else { break }
        for cell in step.cells { grid[cell.r][cell.c] = cell.value }
        steps.append(step)
    }
    return (isComplete(grid), grid, steps)
}

/// True if the puzzle is fully solvable by logic alone (incl. depth-1 contradiction).
public func isLogicSolvable(_ rowClues: [Clue], _ colClues: [Clue]) -> Bool {
    solveByLogic(rowClues, colClues).solved
}
