// The Live Activity's type, compiled into BOTH the iOS app (which starts and
// updates it) and the widget extension (which draws it). ActivityKit matches
// the two sides by type name, so this file must stay a single source — never
// copy it.
//
// The mutable half (`PuzzleActivityState`) lives in ClueweaveKit, where the
// verifier can pin its arithmetic without Xcode. Only the ActivityKit
// conformance is here, because ActivityKit is iOS-only and app-layer.
//
// watchOS 11+ mirrors an iPhone's Live Activity to the wrist automatically —
// there is no watch-side activity to author and no code to write for it. What
// the watch shows is this same content state rendered in the `.small` activity
// family; see `ClueweaveLiveActivity` in the widget extension.

import Foundation
import ClueweaveKit

#if canImport(ActivityKit)
import ActivityKit

struct ClueweaveActivityAttributes: ActivityAttributes {
    typealias ContentState = PuzzleActivityState

    /// Fixed for the life of the attempt — the board being solved.
    let puzzleID: String
    let title: String
    let difficulty: Difficulty
    let width: Int
    let height: Int

    /// Deep link back into the board this activity is tracking.
    var resumeURL: URL { ClueweaveLink.resume(puzzleID).url }
}
#endif
