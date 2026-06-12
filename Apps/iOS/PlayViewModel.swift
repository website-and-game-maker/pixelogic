// Observable wrapper around PixelogicKit's pure GameSession — the bridge
// between engine semantics and SwiftUI. Mirrors the web play view's behaviour:
// assists with live penalty meter, auto-cross, scoring on win, post-solve mode.
// Unfinished attempts persist (board + clock + assists) so quitting never
// loses progress.

import SwiftUI
import Combine
import PixelogicKit

@MainActor
final class PlayViewModel: ObservableObject {
    let puzzle: Puzzle
    let isLibrary: Bool
    private let store: PlayerStore
    private let session: GameSession
    /// Save key for resumable attempts: library puzzles and saved customs.
    /// Editor test-drives (id "draft") play ephemerally.
    private let persistKey: String?

    @Published private(set) var marks: Grid
    @Published var mode: GameSession.Mode = .paint {
        didSet { session.mode = mode }
    }
    @Published private(set) var solved = false
    @Published private(set) var filledOut = false
    @Published private(set) var penalty = 0
    @Published private(set) var voided = false
    @Published private(set) var checkSquaresLeft: Int?
    @Published private(set) var elapsedMs = 0
    @Published var banner: String?
    @Published var showWinSheet = false
    @Published private(set) var finalScore: Int?
    @Published private(set) var isNewBestScore = false
    @Published private(set) var bestTimeMs: Int?
    @Published private(set) var isNewBestTime = false
    @Published var armedCheck: ArmedCheck?
    /// After the win sheet is dismissed: solving tools hide, Next/Share show.
    @Published var postSolve = false

    enum ArmedCheck { case square, line }

    /// The value the current drag stroke is painting (set by its first cell).
    private var strokeValue: Cell?

    let badges: [Badge]
    var symmetricBadge: Badge? { badges.first { $0.key == .symmetric } }

    private var ticker: AnyCancellable?

    init(puzzle: Puzzle, isLibrary: Bool, store: PlayerStore) {
        self.puzzle = puzzle
        self.isLibrary = isLibrary
        self.store = store
        self.session = GameSession(puzzle: puzzle)
        self.persistKey = (isLibrary || puzzle.id.hasPrefix("u-")) ? puzzle.id : nil
        if let key = persistKey, let saved = store.inProgress(for: key) {
            session.restore(marks: saved.grid, elapsedMs: saved.elapsedMs, assists: saved.assists)
        }
        self.marks = session.marks
        self.badges = puzzleBadges(solution: puzzle.solution, named: puzzle.named)
        self.checkSquaresLeft = session.checkSquaresLeft
        self.penalty = session.assists.penaltyTotal
        self.voided = session.assists.voided
        self.elapsedMs = session.elapsedMs
        session.start()
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.solved else { return }
                self.elapsedMs = self.session.elapsedMs
            }
    }

    var settings: GameSettings { store.settings }

    // MARK: - Input

    func touch(_ r: Int, _ c: Int, isDrag: Bool) {
        guard !solved else { return }
        if let armed = armedCheck {
            guard !isDrag else { return } // an armed check consumes a tap, not a stroke
            armedCheck = nil
            switch armed {
            case .square:
                if session.checkSquare(r, c) { banner = nil } else { banner = "No square checks left at this difficulty." }
            case .line:
                session.checkLine(r, c)
                banner = nil
            }
            sync()
            return
        }
        if isDrag {
            // Continue the stroke with the value set by its first cell.
            session.setCell(r, c, strokeValue ?? (mode == .paint ? .filled : .empty), recordHistory: false)
        } else {
            session.toggle(r, c)
            strokeValue = session.marks[r][c] // unknown = erasing stroke
        }
        sync()
    }

    // MARK: - Assists

    func armCheckSquare() {
        guard session.checkSquaresLeft.map({ $0 > 0 }) ?? true else {
            banner = "No square checks left at this difficulty."
            return
        }
        armedCheck = .square
        banner = "Tap a square to reveal it (−\(AssistTally.penaltyCheckSquare))."
    }

    func armCheckLine() {
        armedCheck = .line
        banner = "Tap a cell to reveal its row & column (−\(AssistTally.penaltyCheckLine))."
    }

    func checkBoard() {
        let cleared = session.checkBoard()
        banner = cleared == 0 ? "No mistakes so far. ✓" : "Cleared \(cleared) mistaken \(cleared == 1 ? "cell" : "cells")."
        sync()
    }

    func hint() {
        guard let h = session.hint() else {
            banner = solved ? "Already solved! 🎉" : "No further logical step found."
            return
        }
        banner = "💡 \(h.reason)"
        sync()
    }

    func fillOut() {
        session.fillOut()
        sync()
    }

    func voidForWatchSolve() {
        session.voidForWatchSolve()
        sync()
    }

    func undo() { session.undo(); sync() }
    func redo() { session.redo(); sync() }
    var canUndo: Bool { session.canUndo }
    var canRedo: Bool { session.canRedo }

    func restart() {
        session.restart()
        solved = false
        filledOut = false
        postSolve = false
        finalScore = nil
        banner = nil
        armedCheck = nil
        if let key = persistKey { store.clearInProgress(for: key) }
        sync()
    }

    /// Scene-phase / navigation hook: pause the clock (and snapshot progress)
    /// when play leaves the screen or the app leaves the foreground.
    func setActive(_ active: Bool) {
        guard !solved else { return }
        if active {
            session.start()
        } else {
            session.pause()
            persistProgress()
        }
        elapsedMs = session.elapsedMs
    }

    // MARK: - Sync + win

    private func sync() {
        if store.settings.autoCross && !session.filledOut {
            session.applyAutoCross()
        }
        marks = session.marks
        penalty = session.assists.penaltyTotal
        voided = session.assists.voided
        filledOut = session.filledOut
        checkSquaresLeft = session.checkSquaresLeft
        elapsedMs = session.elapsedMs
        if !solved && session.isSolved { handleWin() }
        persistProgress()
    }

    private func persistProgress() {
        guard let key = persistKey else { return }
        if solved || filledOut {
            store.clearInProgress(for: key)
            return
        }
        let untouched = session.marks.allSatisfy { row in row.allSatisfy { $0 == .unknown } }
        if untouched && session.assists == AssistTally() {
            store.clearInProgress(for: key) // pristine board — nothing worth resuming
            return
        }
        store.saveInProgress(
            InProgressAttempt(marks: session.marks, elapsedMs: session.elapsedMs, assists: session.assists),
            for: key
        )
    }

    private func handleWin() {
        solved = true
        session.pause()
        let elapsed = session.elapsedMs

        if !filledOut && isLibrary {
            store.markCompleted(puzzle.id)
            let score = session.currentScore
            let rec = store.recordScore(puzzle.id, score: score)
            finalScore = score
            isNewBestScore = rec.isNew && score > 0
            let time = store.recordBestTime(puzzle.id, elapsedMs: elapsed)
            bestTimeMs = time.best
            isNewBestTime = time.isNew
        }
        if let key = persistKey { store.clearInProgress(for: key) }
        showWinSheet = true
    }

    /// Share text for the result (mirrors the web copy).
    var shareText: String {
        let time = TimeFormat.string(ms: elapsedMs)
        let scoreBit = finalScore.map { " (scored \($0)/100)" } ?? ""
        return "I solved “\(puzzle.title)” on Pixelogic in \(time)\(scoreBit)! ▦"
    }

    /// Library puzzles share their web page; custom puzzles share the encoded
    /// token URL (the link IS the puzzle), so the receiver can actually open it.
    var shareURL: URL {
        isLibrary
            ? webShareURL(forLibraryID: puzzle.id)
            : webShareURL(forToken: encodePuzzle(puzzle.solution, title: puzzle.title))
    }
}

enum TimeFormat {
    static func string(ms: Int) -> String {
        let total = max(0, ms / 1000)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
