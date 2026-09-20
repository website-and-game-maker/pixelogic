// Where widgets get their data.
//
// A widget process cannot see the app's own UserDefaults, and must not decode
// `SaveData` (it carries every player-created grid). It reads the small
// snapshot the apps publish into the App Group instead — see
// `ClueweaveKit/WidgetSnapshot.swift`.
//
// Refresh policy: the apps call `WidgetCenter.reloadAllTimelines()` whenever
// they publish, so the timeline here is a single entry plus a slow safety net.
// Asking WidgetKit to wake us more often would only spend the system's refresh
// budget re-reading a file that has not changed.

import WidgetKit
import SwiftUI
import ClueweaveKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// How long until we ask the system for another look, in case a publish was
/// missed (the app was force-quit mid-write, or the reload budget was spent).
private let safetyNet: TimeInterval = 60 * 60

func currentSnapshotEntry(_ date: Date = Date()) -> SnapshotEntry {
    SnapshotEntry(date: date, snapshot: SnapshotStore.read())
}

func snapshotTimeline(_ date: Date = Date()) -> Timeline<SnapshotEntry> {
    Timeline(
        entries: [currentSnapshotEntry(date)],
        policy: .after(date.addingTimeInterval(safetyNet))
    )
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        // The gallery preview must never show an empty state — nobody adds a
        // widget that looks broken. Fall back to the sample.
        completion(context.isPreview
            ? SnapshotEntry(date: Date(), snapshot: .placeholder)
            : currentSnapshotEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        completion(snapshotTimeline())
    }
}

extension WidgetSnapshot {
    /// The widget gallery sample: a believable half-solved board, never a real
    /// player's data (the gallery renders before any App Group read is sensible).
    static let placeholder: WidgetSnapshot = {
        let sample = puzzle(withID: "plus") ?? library.first!
        var marks: EngineGrid = Array(
            repeating: Array(repeating: Cell.unknown, count: sample.width),
            count: sample.height)
        // Fill roughly the first half of the picture so the ring reads ~50%.
        var placed = 0
        let target = max(1, sample.solution.flatMap { $0 }.filter { $0 }.count / 2)
        for (r, row) in sample.solution.enumerated() {
            for (c, filled) in row.enumerated() where filled && placed < target {
                marks[r][c] = .filled
                placed += 1
            }
        }
        return makeWidgetSnapshot(
            library: library,
            completed: Set(library.prefix(4).map(\.id)),
            bestScores: [:],
            continueFrom: ContinueSource(puzzle: sample, marks: marks, elapsedMs: 96_000),
            score: 420
        )
    }()
}
