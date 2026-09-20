// The data half of the Live Activity.
//
// ActivityKit itself is app-layer (and iOS-only), so the `ActivityAttributes`
// conformance lives in `Apps/Shared/ClueweaveActivity.swift`, compiled into
// both the app and the widget extension. What lives here is the *content
// state* — the payload that gets encoded, pushed across the process boundary
// and, on watchOS 11+, mirrored to the wrist untouched. Keeping it pure means
// the verifier can pin its shape without Xcode, and means the watch mirror and
// the Dynamic Island are rendering literally the same numbers.

import Foundation

/// A running attempt, as the Lock Screen / Dynamic Island / watch mirror see it.
public struct PuzzleActivityState: Codable, Hashable, Sendable {
    /// Correctly filled cells, and how many the finished picture has. Same
    /// metric as the Continue widget's ring — see `solveProgress`.
    public var correct: Int
    public var totalFilled: Int
    /// Wall-clock start of the *current* running stretch, so the Live Activity
    /// can drive a `Text(timerInterval:)` that keeps counting with the app shut.
    /// `nil` while the attempt is paused, in which case `elapsedMs` is the whole
    /// truth. (A Live Activity cannot tick a paused clock, so a paused attempt
    /// shows a frozen number rather than a lying one.)
    public var runningSince: Date?
    /// Time banked before `runningSince`. Total elapsed = this + now − runningSince.
    public var elapsedMs: Int
    public var isSolved: Bool
    /// Assist penalty accrued so far (0–100 scale, mirrors `AssistTally`).
    public var penalty: Int
    /// One short line: the hint banner, "Solved!", or the tier name.
    public var headline: String

    public init(
        correct: Int,
        totalFilled: Int,
        runningSince: Date? = nil,
        elapsedMs: Int,
        isSolved: Bool = false,
        penalty: Int = 0,
        headline: String = ""
    ) {
        self.correct = correct
        self.totalFilled = totalFilled
        self.runningSince = runningSince
        self.elapsedMs = elapsedMs
        self.isSolved = isSolved
        self.penalty = penalty
        self.headline = headline
    }

    /// 0…1, for the progress bar. Always finite, never > 1.
    public var fraction: Double {
        guard totalFilled > 0 else { return 0 }
        return min(1, Double(correct) / Double(totalFilled))
    }

    /// Total elapsed time at `now`, folding in the running stretch.
    public func totalElapsedMs(at now: Date) -> Int {
        guard let since = runningSince, !isSolved else { return elapsedMs }
        return elapsedMs + max(0, Int(now.timeIntervalSince(since) * 1000))
    }

    /// The range to hand `Text(timerInterval:)` so the system animates the clock
    /// for us. Anchored in the past by the banked time, which is how a resumed
    /// attempt shows its true total rather than restarting from zero.
    public var timerStart: Date? {
        guard let since = runningSince, !isSolved else { return nil }
        return since.addingTimeInterval(-Double(elapsedMs) / 1000)
    }
}
