// Puzzle generator: produces brand-new, provably-solvable puzzles. The trick is
// to keep only grids that pure line propagation solves to completion — a
// complete propagation result is necessarily THE unique solution and needed no
// guessing, so every generated puzzle upholds the app's core promise for free.

import Foundation

/// Deterministic RNG (SplitMix64) so generation is reproducible in tests.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private let genAdjectives = ["Quiet", "Curious", "Bright", "Hidden", "Clever", "Bold", "Gentle", "Wandering", "Brisk", "Stray", "Lucid", "Sly"]
private let genNouns = ["Spark", "Maze", "Cinder", "Lattice", "Echo", "Drift", "Glyph", "Ember", "Vertex", "Riddle", "Thicket", "Cascade"]

/// Generate a brand-new `size`x`size` puzzle that is provably unique and solvable
/// by pure line logic. Returns nil only if no valid grid turns up in `maxAttempts`
/// (effectively never for sizes <= 12 — random grids are line-solvable ~60% of the time).
public func generatePuzzle(size: Int,
                           using rng: inout some RandomNumberGenerator,
                           maxAttempts: Int = 2000) -> Puzzle? {
    guard size >= 5, size <= 15 else { return nil }
    for _ in 0..<maxAttempts {
        let p = Double.random(in: 0.42...0.62, using: &rng)
        var grid: [[Bool]] = []
        grid.reserveCapacity(size)
        var filled = 0
        for _ in 0..<size {
            var row: [Bool] = []
            row.reserveCapacity(size)
            for _ in 0..<size {
                let on = Double.random(in: 0..<1, using: &rng) < p
                if on { filled += 1 }
                row.append(on)
            }
            grid.append(row)
        }
        guard filled >= size, filled <= size * size - size else { continue } // skip degenerate
        let clues = cluesForGrid(grid)
        guard isLineSolvable(clues.rowClues, clues.colClues) else { continue } // => unique + logic-solvable
        let adj = genAdjectives.randomElement(using: &rng) ?? "Quiet"
        let noun = genNouns.randomElement(using: &rng) ?? "Maze"
        let id = "g-" + String(UInt32.random(in: 0..<UInt32.max, using: &rng), radix: 36)
        return Puzzle(id: id, title: "\(adj) \(noun)", solution: grid,
                      difficulty: gradeGrid(grid), named: false)
    }
    return nil
}

/// Convenience using the system RNG (production).
public func generatePuzzle(size: Int) -> Puzzle? {
    var rng = SystemRandomNumberGenerator()
    return generatePuzzle(size: size, using: &rng)
}

/// "Good enough to send to the developer." Every generated puzzle is already
/// unique + logic-solvable; this gates only on interestingness — a medium-or-harder
/// puzzle, or one carrying a structural badge.
public func isWorthSubmitting(_ puzzle: Puzzle) -> Bool {
    if puzzle.difficulty != .easy { return true }
    return !puzzleBadges(puzzle).isEmpty
}
