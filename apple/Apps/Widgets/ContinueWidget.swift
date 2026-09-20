// "Pick up where you left off."
//
// The one widget worth the Home Screen slot: it only exists when there is an
// unfinished board, it shows which board, and one tap reopens it. Everything
// else the app can tell you is a list you could have opened yourself.

import WidgetKit
import SwiftUI
import ClueweaveKit

struct ContinueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClueweaveContinue", provider: SnapshotProvider()) { entry in
            ContinueWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Continue")
        .description("Your unfinished board, with one tap to pick it back up.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct ContinueWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot? { entry.snapshot }
    private var cont: ContinueSnapshot? { snapshot?.continueEntry }

    var body: some View {
        content
            // Accessory families get exactly ONE tap target, so it has to be the
            // most useful destination available — the board if there is one,
            // otherwise what to play next. See `WidgetSnapshot.primaryLink`.
            .widgetURL((cont?.link ?? snapshot?.primaryLink ?? .home).url)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            if let c = cont {
                Text("\(c.title) · \(Int(c.fraction * 100))%")
            } else {
                Text("Clueweave")
            }

        case .accessoryCircular:
            ProgressRing(fraction: cont?.fraction ?? 0, tint: .white, lineWidth: 4) {
                if let c = cont {
                    Text("\(Int(c.fraction * 100))")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .minimumScaleFactor(0.6)
                } else {
                    Image(systemName: "square.grid.3x3.fill").font(.caption)
                }
            }
            .widgetAccentable()

        case .accessoryRectangular:
            rectangular

        case .systemMedium:
            medium

        default:
            small
        }
    }

    // MARK: - Accessory rectangular

    @ViewBuilder
    private var rectangular: some View {
        if let c = cont {
            HStack(spacing: 8) {
                MiniBoard(preview: c.board, monochrome: true)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.title)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .lineLimit(1)
                    Text("\(c.correct)/\(c.totalFilled) · \(shortTime(ms: c.elapsedMs))")
                        .font(.system(.caption2, design: .rounded))
                    ProgressView(value: c.fraction)
                        .progressViewStyle(.linear)
                        .tint(.white)
                }
            }
            .widgetAccentable()
        } else if let r = snapshot?.recommendation {
            // Deliberately NOT a blank "open the app" — an empty rectangular
            // complication is dead pixels on a watch face. Fall through to the
            // thing the player would have opened the app to find.
            VStack(alignment: .leading, spacing: 1) {
                Text("Play next")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.secondary)
                Text(r.title)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                Text(r.difficulty.displayName)
                    .font(.system(.caption2, design: .rounded))
            }
            .widgetAccentable()
        } else {
            Text("Clueweave")
                .font(.system(.caption, design: .rounded, weight: .heavy))
        }
    }

    // MARK: - Home Screen

    @ViewBuilder
    private var small: some View {
        if let c = cont {
            VStack(spacing: 6) {
                MiniBoard(preview: c.board)
                    .frame(maxHeight: .infinity)
                VStack(spacing: 1) {
                    Text(c.title)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .lineLimit(1)
                    Text("\(Int(c.fraction * 100))% · \(shortTime(ms: c.elapsedMs))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            WidgetEmptyState(
                title: "Nothing in progress",
                message: snapshot?.recommendation.map { "Try \($0.title)." }
                    ?? "Open Clueweave to start one.")
        }
    }

    @ViewBuilder
    private var medium: some View {
        if let c = cont {
            HStack(spacing: 14) {
                MiniBoard(preview: c.board)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pick up where you left off")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Text(c.title)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(c.difficulty.displayName)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(WidgetPalette.accent(c.difficulty).opacity(0.18)))
                            .foregroundStyle(WidgetPalette.accent(c.difficulty))
                        Text(shortTime(ms: c.elapsedMs))
                            .font(.system(.caption, design: .rounded, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: c.fraction)
                        .progressViewStyle(.linear)
                        .tint(WidgetPalette.fill)
                    Text("\(c.correct) of \(c.totalFilled) squares")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            WidgetEmptyState(
                title: "Nothing in progress",
                message: snapshot?.recommendation.map { "Next up: \($0.title) (\($0.difficulty.displayName))." }
                    ?? "Open Clueweave to start a puzzle.")
        }
    }
}
