// The one place the app tells its widgets that something changed.
//
// `publishWidgetSnapshot` writes the small shared blob; `reloadAllTimelines`
// asks WidgetKit to re-read it. Both have to happen, and in that order —
// reloading without publishing just re-renders stale data.
//
// Called at the same checkpoints the save itself is written at (a solve, a
// board being put down, the app backgrounding), never per touch: publishing
// encodes a JSON blob, and a drag across a 15×15 board is hundreds of touches.

import Foundation
import WidgetKit
import ClueweaveKit

extension PlayerStore {
    /// Resolve any saved puzzle id — library, player-created, or generated —
    /// so a Continue widget can show custom art the extension has never seen.
    var widgetPuzzleResolver: (String) -> Puzzle? {
        { [weak self] id in
            if let p = ClueweaveKit.puzzle(withID: id) { return p }
            guard let self else { return nil }
            return self.userPuzzles.first(where: { $0.id == id })?.asPuzzle
                ?? self.generatedPuzzles.first(where: { $0.id == id })?.asPuzzle
        }
    }

    /// Republish everything the widgets and complications read, then nudge
    /// WidgetKit. Safe to call when no widget is installed — it is a defaults
    /// write and a no-op reload.
    func refreshWidgets() {
        publishWidgetSnapshot(resolve: widgetPuzzleResolver)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
