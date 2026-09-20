// Observable wrapper around ClueweaveKit's pure GameSession — the bridge
// between engine semantics and SwiftUI. Mirrors the web play view's behaviour:
// assists with live penalty meter, auto-cross, scoring on win, post-solve mode.
// Unfinished attempts persist (board + clock + assists) so quitting never
// loses progress.

import SwiftUI
import Combine
import ClueweaveKit

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

    // MARK: - Live Activity clock
    //
    // The Live Activity draws its timer with `Text(timerInterval:)`, which needs
    // a wall-clock anchor rather than a number — that is how it keeps counting
    // while the app is suspended. So the running stretch is tracked separately
    // from `GameSession`'s own total: `bankedMs` is everything before
    // `runningSince`, and total = banked + (now − runningSince). Both are
    // re-stamped together, from the session's own clock, so they can't drift.
    private var runningSince: Date?
    private var bankedMs = 0
    /// True once the player has actually marked something. Opening a puzzle to
    /// look at it should not put a card on someone's Lock Screen.
    private var activityStarted = false

    init(puzzle: Puzzle, isLibrary: Bool, store: PlayerStore) {
        self.puzzle = puzzle
        self.isLibrary = isLibrary
        self.store = store
        self.session = GameSession(puzzle: puzzle)
        self.persistKey = (isLibrary || puzzle.id.hasPrefix("u-") || puzzle.id.hasPrefix("g-")) ? puzzle.id : nil
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
        markClockRunning()
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
        // Asking to be shown the answer is the clearest give-up signal there is.
        recordAttemptSignal(solved: false)
        sync()
    }

    /// Fold this attempt's outcome into the progression model. Only built-in
    /// library puzzles teach it anything — custom, generated, shared and
    /// test-play puzzles must not. See docs/progression-model.md §2.
    private func recordAttemptSignal(solved didSolve: Bool) {
        guard isLibrary else { return }
        let outcome = AttemptOutcome(
            solved: didSolve,
            voided: session.filledOut || session.assists.voided,
            assists: session.assists,
            elapsedMs: session.elapsedMs,
            difficulty: puzzle.difficulty,
            area: puzzle.area
        )
        let signal = classifySignal(outcome, store.settings.progression)
        store.recordSignal(signal, library: library)
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
        // A wiped board is not the attempt the Lock Screen card was tracking.
        stopLiveActivity()
        markClockRunning()
        sync()
        store.refreshWidgets()
    }

    /// Scene-phase / navigation hook: pause or resume the clock when play leaves
    /// or returns to the foreground. Cheap — does NOT persist (see `persistNow`).
    func setActive(_ active: Bool) {
        guard !solved else { return }
        if active { session.start() } else { session.pause() }
        elapsedMs = session.elapsedMs
        if active { markClockRunning() } else { markClockPaused() }
        // Forced: a paused clock that keeps ticking on the Lock Screen is a lie,
        // and it is exactly the moment a player looks at the Lock Screen.
        LiveActivityController.shared.update(activityState(), force: true)
    }

    /// Snapshot the unfinished attempt. Called only at real checkpoints
    /// (navigating away, app backgrounding) — never per touch — so a full
    /// SaveData encode can't run dozens of times mid-drag.
    func persistNow() {
        persistProgress()
        store.refreshWidgets()
    }

    /// Leaving the board for good: the attempt is saved, so the Live Activity
    /// has nothing left to track. (Backgrounding is `setActive(false)`, which
    /// keeps it — that is the case the Lock Screen exists for.)
    func stopLiveActivity() {
        guard activityStarted else { return }
        activityStarted = false
        LiveActivityController.shared.end(activityState(), showResult: solved)
    }

    // MARK: - Live Activity

    private func markClockRunning() {
        bankedMs = session.elapsedMs
        runningSince = Date()
    }

    private func markClockPaused() {
        bankedMs = session.elapsedMs
        runningSince = nil
    }

    private func activityState(headline: String? = nil) -> PuzzleActivityState {
        let progress = solveProgress(marks: session.marks, solution: puzzle.solution)
        return PuzzleActivityState(
            correct: progress.correct,
            totalFilled: progress.total,
            runningSince: solved ? nil : runningSince,
            elapsedMs: solved ? session.elapsedMs : bankedMs,
            isSolved: solved,
            penalty: session.assists.penaltyTotal,
            headline: headline ?? (solved ? "Solved! 🎉" : puzzle.difficulty.displayName)
        )
    }

    /// Start the activity on the first real mark, then keep it fed. The
    /// controller throttles the pushes; this just tells it the truth.
    ///
    /// Runs at the tail of every `sync()`, including the one that detected the
    /// win — so the finished states have to be checked first, or ending the
    /// activity on a solve would immediately start a fresh one.
    private func syncLiveActivity() {
        if solved || filledOut || voided {
            if activityStarted {
                activityStarted = false
                LiveActivityController.shared.end(activityState(), showResult: solved)
            }
            return
        }
        if !activityStarted {
            let touched = session.marks.contains { row in row.contains { $0 != .unknown } }
            guard touched else { return }
            activityStarted = true
            LiveActivityController.shared.start(puzzle: puzzle, state: activityState())
            return
        }
        LiveActivityController.shared.update(activityState())
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
        syncLiveActivity()
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

        if !session.assists.voided && isLibrary {
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
        // After the score is settled, so the assist tally is final.
        recordAttemptSignal(solved: true)
        showWinSheet = true
        // The Live Activity is closed out by `syncLiveActivity()`, which runs
        // at the tail of the same `sync()` that got us here — and leaves the
        // win on the Lock Screen for a beat.
        store.refreshWidgets()
    }

    /// Share text for the result (mirrors the web copy).
    var shareText: String {
        let time = TimeFormat.string(ms: elapsedMs)
        let scoreBit = finalScore.map { " (scored \($0)/100)" } ?? ""
        return "I solved “\(puzzle.title)” on Clueweave in \(time)\(scoreBit)! ▦"
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
