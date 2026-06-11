// Pure play-session model (UI-free): marks, paint/cross modes, undo/redo,
// timer, assists with budgets and penalties, auto-cross, win detection and
// scoring. The SwiftUI apps wrap this in a thin observable shell. Mirrors the
// semantics of the web's gameState.ts + scoreState.ts + play.ts behaviour.

import Foundation

public final class GameSession {
    public enum Mode: Sendable { case paint, cross }

    public let puzzle: Puzzle
    public private(set) var marks: Grid
    public var mode: Mode = .paint
    public private(set) var assists = AssistTally()
    /// Fill-out was used this attempt (no score, popup says "Filled out").
    public private(set) var filledOut = false

    private var undoStack: [Grid] = []
    private var redoStack: [Grid] = []

    private var elapsedBase: TimeInterval = 0
    private var runningSince: Date?
    private let now: () -> Date

    /// `now` is injectable for tests.
    public init(puzzle: Puzzle, now: @escaping () -> Date = { Date() }) {
        self.puzzle = puzzle
        self.marks = makeGrid(puzzle.height, puzzle.width)
        self.now = now
    }

    // MARK: - Timer

    public func start() {
        if runningSince == nil { runningSince = now() }
    }

    public func pause() {
        if let since = runningSince {
            elapsedBase += now().timeIntervalSince(since)
            runningSince = nil
        }
    }

    public var elapsedMs: Int {
        var total = elapsedBase
        if let since = runningSince { total += now().timeIntervalSince(since) }
        return Int(total * 1000)
    }

    // MARK: - Marks / undo

    private func snapshot() { undoStack.append(marks); redoStack = [] }

    public func setCell(_ r: Int, _ c: Int, _ value: Cell, recordHistory: Bool = true) {
        guard r >= 0, c >= 0, r < puzzle.height, c < puzzle.width, marks[r][c] != value else { return }
        if recordHistory { snapshot() }
        marks[r][c] = value
    }

    /// Tap behaviour: toggle through the mode's value and unknown.
    public func toggle(_ r: Int, _ c: Int) {
        let current = marks[r][c]
        let target: Cell
        switch mode {
        case .paint: target = current == .filled ? .unknown : .filled
        case .cross: target = current == .empty ? .unknown : .empty
        }
        setCell(r, c, target)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(marks)
        marks = prev
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(marks)
        marks = next
    }

    // MARK: - State queries

    /// Solved when filled cells exactly match the solution (crosses ignored).
    public var isSolved: Bool {
        for r in 0..<puzzle.height {
            for c in 0..<puzzle.width where (marks[r][c] == .filled) != puzzle.solution[r][c] {
                return false
            }
        }
        return true
    }

    public func isLineSatisfied(row r: Int) -> Bool {
        cluesForLine(marks[r].map { $0 == .filled }) == puzzle.rowClues[r]
    }

    public func isLineSatisfied(column c: Int) -> Bool {
        cluesForLine(marks.map { $0[c] == .filled }) == puzzle.colClues[c]
    }

    /// Cross the leftover cells of every satisfied line. Returns how many cells
    /// were crossed (0 = nothing to do).
    @discardableResult
    public func applyAutoCross() -> Int {
        var targets: [(Int, Int)] = []
        for r in 0..<puzzle.height where isLineSatisfied(row: r) {
            for c in 0..<puzzle.width where marks[r][c] == .unknown { targets.append((r, c)) }
        }
        for c in 0..<puzzle.width where isLineSatisfied(column: c) {
            for r in 0..<puzzle.height where marks[r][c] == .unknown { targets.append((r, c)) }
        }
        for (r, c) in targets { marks[r][c] = .empty }
        return targets.count
    }

    // MARK: - Assists

    private func truth(_ r: Int, _ c: Int) -> Cell {
        puzzle.solution[r][c] ? .filled : .empty
    }

    public var checkSquaresLeft: Int? {
        guard let budget = puzzle.difficulty.checkBudget else { return nil }
        return max(0, budget - assists.checkSquare)
    }

    /// Reveal one square's truth (−5, budget-limited). False if out of budget.
    @discardableResult
    public func checkSquare(_ r: Int, _ c: Int) -> Bool {
        if let left = checkSquaresLeft, left <= 0 { return false }
        assists.checkSquare += 1
        setCell(r, c, truth(r, c))
        return true
    }

    /// Reveal a full row + column (−15).
    public func checkLine(_ r: Int, _ c: Int) {
        assists.checkLine += 1
        snapshot()
        for cc in 0..<puzzle.width { marks[r][cc] = truth(r, cc) }
        for rr in 0..<puzzle.height { marks[rr][c] = truth(rr, c) }
    }

    /// Clear every mistaken fill (−40). Returns how many were cleared.
    @discardableResult
    public func checkBoard() -> Int {
        assists.checkBoard += 1
        var wrong: [(Int, Int)] = []
        for r in 0..<puzzle.height {
            for c in 0..<puzzle.width where marks[r][c] == .filled && !puzzle.solution[r][c] {
                wrong.append((r, c))
            }
        }
        if !wrong.isEmpty {
            snapshot()
            for (r, c) in wrong { marks[r][c] = .unknown }
        }
        return wrong.count
    }

    /// Next forced cell with a reason (−20). Nil if already solved.
    public func hint() -> Hint? {
        guard let h = nextHint(puzzle, marks: marks) else { return nil }
        assists.hint += 1
        return h
    }

    /// Auto-complete the puzzle. The attempt is voided (scores 0).
    public func fillOut() {
        filledOut = true
        assists.voided = true
        pause()
        snapshot()
        for r in 0..<puzzle.height {
            for c in 0..<puzzle.width { marks[r][c] = truth(r, c) }
        }
    }

    /// Watching the step-by-step solution voids the attempt, like fill-out.
    public func voidForWatchSolve() {
        assists.voided = true
    }

    public func restart() {
        filledOut = false
        assists = AssistTally()
        marks = makeGrid(puzzle.height, puzzle.width)
        undoStack = []
        redoStack = []
        elapsedBase = 0
        runningSince = now()
    }

    // MARK: - Scoring

    /// The score this attempt would earn if it ended now.
    public var currentScore: Int {
        puzzleScore(
            difficulty: puzzle.difficulty,
            area: puzzle.area,
            bestTimeMs: max(1, elapsedMs),
            assists: assists
        )
    }
}
