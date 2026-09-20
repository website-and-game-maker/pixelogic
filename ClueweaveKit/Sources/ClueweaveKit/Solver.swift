// Whole-grid solver: propagation to fixpoint + bounded search
// (port of src/engine/solver.ts).

public enum SolveStatus: Sendable {
    case solved, stuck, contradiction
}

public func makeGrid(_ h: Int, _ w: Int) -> Grid {
    Array(repeating: Array(repeating: Cell.unknown, count: w), count: h)
}

func column(of grid: Grid, _ c: Int) -> [Cell] {
    grid.map { $0[c] }
}

func isComplete(_ grid: Grid) -> Bool {
    grid.allSatisfy { row in row.allSatisfy { $0 != .unknown } }
}

/// Iterated line solving across all rows and columns to a fixpoint. Pure logical
/// propagation — never guesses.
public func propagate(
    _ rowClues: [Clue], _ colClues: [Clue], start: Grid? = nil
) -> (status: SolveStatus, grid: Grid) {
    let h = rowClues.count
    let w = colClues.count
    var grid = start ?? makeGrid(h, w)

    var changed = true
    while changed {
        changed = false
        for r in 0..<h {
            guard let next = solveLine(grid[r], rowClues[r]) else {
                return (.contradiction, grid)
            }
            for c in 0..<w where next[c] != grid[r][c] {
                grid[r][c] = next[c]
                changed = true
            }
        }
        for c in 0..<w {
            guard let next = solveLine(column(of: grid, c), colClues[c]) else {
                return (.contradiction, grid)
            }
            for r in 0..<h where next[r] != grid[r][c] {
                grid[r][c] = next[r]
                changed = true
            }
        }
    }

    return (isComplete(grid) ? .solved : .stuck, grid)
}

func firstUnknown(_ grid: Grid) -> (Int, Int)? {
    for r in 0..<grid.count {
        for c in 0..<grid[r].count where grid[r][c] == .unknown {
            return (r, c)
        }
    }
    return nil
}

/// Safety cap so a pathological grid can never hang the UI.
let nodeCap = 200_000

public struct SolutionCount: Sendable {
    public let count: Int
    /// True if the node cap was hit — the count is a lower bound and
    /// uniqueness must NOT be inferred.
    public let capped: Bool
}

/// Count solutions up to `limit` via propagation interleaved with DFS on the
/// first unknown cell. Node-bounded.
public func countSolutionsDetailed(_ rowClues: [Clue], _ colClues: [Clue], limit: Int = 2) -> SolutionCount {
    var count = 0
    var nodes = 0
    var capped = false

    func dfs(_ grid: Grid) {
        if count >= limit { return }
        nodes += 1
        if nodes > nodeCap {
            capped = true
            return
        }
        let res = propagate(rowClues, colClues, start: grid)
        if res.status == .contradiction { return }
        if res.status == .solved {
            count += 1
            return
        }
        guard let (r, c) = firstUnknown(res.grid) else { return }
        for value in [Cell.filled, Cell.empty] {
            if count >= limit { return }
            var next = res.grid
            next[r][c] = value
            dfs(next)
        }
    }

    dfs(makeGrid(rowClues.count, colClues.count))
    return SolutionCount(count: count, capped: capped)
}

public func hasUniqueSolution(_ rowClues: [Clue], _ colClues: [Clue]) -> Bool {
    let result = countSolutionsDetailed(rowClues, colClues, limit: 2)
    return result.count == 1 && !result.capped
}

/// Return up to `limit` actual solution grids (booleans). Node-bounded.
public func enumerateSolutions(_ rowClues: [Clue], _ colClues: [Clue], limit: Int = 2) -> [[[Bool]]] {
    var out: [[[Bool]]] = []
    var nodes = 0
    func dfs(_ grid: Grid) {
        if out.count >= limit { return }
        nodes += 1
        if nodes > nodeCap { return }
        let res = propagate(rowClues, colClues, start: grid)
        if res.status == .contradiction { return }
        if res.status == .solved {
            out.append(toBooleans(res.grid))
            return
        }
        guard let (r, c) = firstUnknown(res.grid) else { return }
        for value in [Cell.filled, Cell.empty] {
            if out.count >= limit { return }
            var next = res.grid
            next[r][c] = value
            dfs(next)
        }
    }
    dfs(makeGrid(rowClues.count, colClues.count))
    return out
}

/// True if pure propagation (no guessing) fully solves the puzzle.
public func isLineSolvable(_ rowClues: [Clue], _ colClues: [Clue]) -> Bool {
    propagate(rowClues, colClues).status == .solved
}

func toBooleans(_ grid: Grid) -> [[Bool]] {
    grid.map { row in row.map { $0 == .filled } }
}
