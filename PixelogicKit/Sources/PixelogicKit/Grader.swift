// Difficulty grading by reasoning effort (port of src/engine/grader.ts).

private func capAt(_ d: Difficulty, _ cap: Difficulty) -> Difficulty {
    d.order > cap.order ? cap : d
}

/// Grade by reasoning effort, judged from the clues alone:
/// line-solvable → by propagation sweeps; otherwise starts at `expert`.
public func grade(_ rowClues: [Clue], _ colClues: [Clue]) -> Difficulty {
    guard isLineSolvable(rowClues, colClues) else { return .expert }
    let rounds = countPropagationRounds(rowClues, colClues)
    if rounds <= 2 { return .easy }
    if rounds <= 4 { return .medium }
    return .hard
}

/// Grade a full solution grid:
/// - contradiction puzzles split into Extra Hard vs Max by total reasoning effort;
/// - symmetric pictures are capped at Hard; patterned at Medium.
public func gradeGrid(_ solution: [[Bool]]) -> Difficulty {
    let clues = cluesForGrid(solution)
    let area = solution.count * (solution.first?.count ?? 0)

    var d: Difficulty
    if isLineSolvable(clues.rowClues, clues.colClues) {
        d = grade(clues.rowClues, clues.colClues)
    } else {
        let result = solveByLogic(clues.rowClues, clues.colClues)
        let contradictions = result.steps.filter { $0.technique == .contradiction }.count
        // Effort blends the number of what-if proofs (weighted heavily), the
        // sheer number of forced steps, and the line size.
        let effort = Double(result.steps.count) + 15.0 * Double(contradictions) + Double(area) / 2.0
        d = effort >= 200 ? .max : .expert
    }

    if isSymmetric(solution) { d = capAt(d, .hard) }
    if detectPatterned(solution) { d = capAt(d, .medium) }
    return d
}

/// Number of full row+column sweeps propagation needs to reach its fixpoint.
func countPropagationRounds(_ rowClues: [Clue], _ colClues: [Clue]) -> Int {
    let h = rowClues.count
    let w = colClues.count
    var grid = makeGrid(h, w)

    var rounds = 0
    var changed = true
    while changed {
        changed = false
        rounds += 1
        for r in 0..<h {
            guard let next = solveLine(grid[r], rowClues[r]) else { return rounds }
            for c in 0..<w where next[c] != grid[r][c] {
                grid[r][c] = next[c]
                changed = true
            }
        }
        for c in 0..<w {
            guard let next = solveLine(column(of: grid, c), colClues[c]) else { return rounds }
            for r in 0..<h where next[r] != grid[r][c] {
                grid[r][c] = next[r]
                changed = true
            }
        }
    }
    return rounds
}
