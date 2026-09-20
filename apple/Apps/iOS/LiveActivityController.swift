// Starts, updates and ends the Live Activity for the attempt on screen.
//
// Deliberately conservative about *when* it pushes:
//
//   • start only when the player has actually engaged (first mark placed), not
//     on every PlayView that appears — opening a puzzle to look at it should
//     not put a card on the Lock Screen;
//   • update on a throttle, because ActivityKit budgets updates and a nonogram
//     can take dozens of marks a minute;
//   • end as soon as the attempt is solved, abandoned or voided.
//
// Everything here no-ops when the OS is too old, the player switched Live
// Activities off, or the system refuses (budget exhausted, setting disabled).
// The game must never depend on an activity existing.
//
// Every ActivityKit call sits behind an explicitly `@available`-annotated
// method rather than a `#available` guard around a closure, so the compiler
// checks the availability rather than us reasoning about scope.

import Foundation
import SwiftUI
import ClueweaveKit

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private init() {}

    /// Player-facing switch. iOS-local, like `highVisibility` — it is a
    /// platform preference, not part of the cross-platform `GameSettings`
    /// contract, so it must not enter the shared save shape.
    static let settingKey = "clueweave.ios.liveActivity"

    static var isEnabledBySetting: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    /// Don't spend the update budget on every painted cell.
    private static let minimumUpdateInterval: TimeInterval = 2
    private var lastPush: Date = .distantPast

    /// The running activity, type-erased so the stored property itself needs no
    /// availability annotation.
    private var box: Any?

    var isRunning: Bool { box != nil }

    // MARK: - Public surface (safe on every supported OS)

    func start(puzzle: Puzzle, state: PuzzleActivityState) {
        #if canImport(ActivityKit)
        guard Self.isEnabledBySetting, !isRunning else { return }
        if #available(iOS 16.2, *) { startImpl(puzzle: puzzle, state: state) }
        #endif
    }

    /// Push a new state. `force` bypasses the throttle for moments that must
    /// land immediately — solving, pausing, giving up.
    func update(_ state: PuzzleActivityState, force: Bool = false) {
        #if canImport(ActivityKit)
        guard isRunning else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastPush) >= Self.minimumUpdateInterval else { return }
        lastPush = now
        if #available(iOS 16.2, *) { updateImpl(state) }
        #endif
    }

    /// End the activity. A solved attempt lingers briefly so the win is visible
    /// on the Lock Screen; anything else disappears at once.
    func end(_ state: PuzzleActivityState, showResult: Bool) {
        #if canImport(ActivityKit)
        guard isRunning else { return }
        if #available(iOS 16.2, *) { endImpl(state, showResult: showResult) }
        box = nil
        #endif
    }

    /// Clear anything this app left behind. Called at launch: an activity
    /// outlives a force-quit, and there is no attempt behind it any more.
    func endStrays() {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) { endStraysImpl() }
        box = nil
        #endif
    }

    // MARK: - ActivityKit

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private var activity: Activity<ClueweaveActivityAttributes>? {
        box as? Activity<ClueweaveActivityAttributes>
    }

    /// A stale card is worse than none: if the app never gets to end this one
    /// (force-quit mid-solve), the system dismisses it after an hour.
    private static let staleAfter: TimeInterval = 60 * 60

    @available(iOS 16.2, *)
    private func startImpl(puzzle: Puzzle, state: PuzzleActivityState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ClueweaveActivityAttributes(
            puzzleID: puzzle.id,
            title: puzzle.title,
            difficulty: puzzle.difficulty,
            width: puzzle.width,
            height: puzzle.height
        )
        box = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(
                state: state, staleDate: Date().addingTimeInterval(Self.staleAfter)),
            pushType: nil
        )
        lastPush = Date()
    }

    @available(iOS 16.2, *)
    private func updateImpl(_ state: PuzzleActivityState) {
        guard let activity else { return }
        let content = ActivityContent(
            state: state, staleDate: Date().addingTimeInterval(Self.staleAfter))
        Task { await activity.update(content) }
    }

    @available(iOS 16.2, *)
    private func endImpl(_ state: PuzzleActivityState, showResult: Bool) {
        guard let activity else { return }
        let content = ActivityContent<PuzzleActivityState>(state: state, staleDate: nil)
        let policy: ActivityUIDismissalPolicy =
            showResult ? .after(Date().addingTimeInterval(20)) : .immediate
        Task { await activity.end(content, dismissalPolicy: policy) }
    }

    @available(iOS 16.2, *)
    private func endStraysImpl() {
        let strays = Activity<ClueweaveActivityAttributes>.activities
        guard !strays.isEmpty else { return }
        Task {
            for stray in strays {
                await stray.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    #endif
}
