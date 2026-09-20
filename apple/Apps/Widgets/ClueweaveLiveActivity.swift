// The Live Activity: a running attempt on the Lock Screen, in the Dynamic
// Island, and — on watchOS 11+ — mirrored to the wrist.
//
// The watch mirror is NOT a second activity. iOS pushes this same content state
// to the paired watch and renders it in the `.small` activity family; there is
// no watch-authored ActivityKit code, and watchOS cannot start one. All the
// wrist needs from us is a layout that survives being 40 mm wide, which is the
// `smallWatch` branch below.
//
// The clock is driven by `Text(timerInterval:)` rather than a pushed number, so
// it keeps counting while the app is suspended. A *paused* attempt has no
// `timerStart` and shows a frozen figure instead — a Live Activity cannot tick a
// paused clock, and a clock that keeps running while the game is paused is
// worse than one that stops.

import WidgetKit
import SwiftUI
import ClueweaveKit

#if canImport(ActivityKit)
import ActivityKit

struct ClueweaveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClueweaveActivityAttributes.self) { context in
            LiveActivityLockScreen(
                attributes: context.attributes, state: context.state
            )
            // Opt into the dedicated wrist layout. Without this the watch still
            // mirrors the activity, but by shrinking the Lock Screen design.
            .supplementalActivityFamily([.small])
        } dynamicIsland: { context in
            let state = context.state
            let attributes = context.attributes
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(attributes.title, systemImage: "square.grid.3x3.fill")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(WidgetPalette.fill)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityClock(state: state)
                        .font(.system(.caption, design: .rounded, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ProgressView(value: state.fraction)
                            .progressViewStyle(.linear)
                            .tint(WidgetPalette.fill)
                        HStack {
                            Text("\(state.correct) of \(state.totalFilled) squares")
                            Spacer()
                            Text(state.headline.isEmpty
                                 ? attributes.difficulty.displayName : state.headline)
                                .lineLimit(1)
                        }
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: state.isSolved ? "checkmark.seal.fill" : "square.grid.3x3.fill")
                    .foregroundStyle(WidgetPalette.fill)
            } compactTrailing: {
                Text("\(Int(state.fraction * 100))%")
                    .font(.system(.caption2, design: .rounded, weight: .heavy).monospacedDigit())
            } minimal: {
                ProgressRing(fraction: state.fraction, tint: WidgetPalette.fill, lineWidth: 3)
            }
            .widgetURL(attributes.resumeURL)
            .keylineTint(WidgetPalette.fill)
        }
    }
}

// MARK: - Lock Screen / watch mirror

struct LiveActivityLockScreen: View {
    /// `.small` means this render is the watch mirror, not the Lock Screen.
    @Environment(\.activityFamily) private var activityFamily

    let attributes: ClueweaveActivityAttributes
    let state: PuzzleActivityState

    var body: some View {
        if activityFamily == .small {
            smallWatch
        } else {
            lockScreen
        }
    }

    private var lockScreen: some View {
        HStack(spacing: 12) {
            ProgressRing(fraction: state.fraction, tint: WidgetPalette.fill, lineWidth: 6) {
                Text("\(Int(state.fraction * 100))")
                    .font(.system(.caption, design: .rounded, weight: .heavy).monospacedDigit())
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                Text(state.headline.isEmpty ? attributes.difficulty.displayName : state.headline)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressView(value: state.fraction)
                    .progressViewStyle(.linear)
                    .tint(WidgetPalette.fill)
            }

            VStack(alignment: .trailing, spacing: 2) {
                ActivityClock(state: state)
                    .font(.system(.title3, design: .rounded, weight: .heavy).monospacedDigit())
                if state.penalty > 0 {
                    Text("−\(state.penalty)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    /// The wrist mirror: one glance, no chrome. 40 mm is not the Lock Screen.
    private var smallWatch: some View {
        VStack(spacing: 2) {
            Text(attributes.title)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .lineLimit(1)
            ActivityClock(state: state)
                .font(.system(.title3, design: .rounded, weight: .heavy).monospacedDigit())
                .foregroundStyle(WidgetPalette.fill)
            ProgressView(value: state.fraction)
                .progressViewStyle(.linear)
                .tint(WidgetPalette.fill)
            Text("\(state.correct)/\(state.totalFilled)")
                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }
}

/// The elapsed clock. A running attempt gets a system-driven timer (it keeps
/// counting with the app suspended); a paused or solved one gets a fixed number.
struct ActivityClock: View {
    let state: PuzzleActivityState

    var body: some View {
        if let start = state.timerStart {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
        } else {
            Text(shortTime(ms: state.elapsedMs))
        }
    }
}

#endif
