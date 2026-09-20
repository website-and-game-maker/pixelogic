// A per-difficulty widget: how far through one tier you are, and the puzzle
// that tier wants you to play next.
//
// The tier is a *configuration*, not five separate widgets, so the gallery
// stays one entry and a player can stack two of them (say Hard and Extra Hard)
// without the list turning into a menu.
//
// Tapping opens that tier's section, which is what the request asked for —
// "tap a difficulty badge, jump to that tier". The suggested puzzle is shown as
// context rather than as the tap target: on the Home Screen a medium widget has
// room for both, and the suggestion gets its own `Link`.

import WidgetKit
import SwiftUI
import AppIntents
import ClueweaveKit

// MARK: - Configuration

enum TierChoice: String, AppEnum, CaseIterable {
    case easy, medium, hard, expert, max

    var difficulty: Difficulty { Difficulty(rawValue: rawValue) ?? .easy }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Difficulty" }

    static var caseDisplayRepresentations: [TierChoice: DisplayRepresentation] {
        [
            .easy: "Easy",
            .medium: "Medium",
            .hard: "Hard",
            .expert: "Extra Hard",
            .max: "MAX",
        ]
    }
}

struct SelectTierIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose a difficulty" }
    static var description: IntentDescription {
        IntentDescription("Pick which difficulty tier this widget tracks.")
    }

    @Parameter(title: "Difficulty", default: .easy)
    var tier: TierChoice

    init() {}
}

// MARK: - Provider

struct TierEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let tier: Difficulty
}

struct TierProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TierEntry {
        TierEntry(date: Date(), snapshot: .placeholder, tier: .medium)
    }

    func snapshot(for configuration: SelectTierIntent, in context: Context) async -> TierEntry {
        TierEntry(
            date: Date(),
            snapshot: context.isPreview ? .placeholder : SnapshotStore.read(),
            tier: configuration.tier.difficulty
        )
    }

    func timeline(for configuration: SelectTierIntent, in context: Context) async -> Timeline<TierEntry> {
        let now = Date()
        let entry = TierEntry(
            date: now, snapshot: SnapshotStore.read(), tier: configuration.tier.difficulty)
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60 * 60)))
    }
}

// MARK: - Widget

struct TierWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "ClueweaveTier",
            intent: SelectTierIntent.self,
            provider: TierProvider()
        ) { entry in
            TierWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Difficulty")
        .description("How far through one tier you are, and what to play next in it.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct TierWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TierEntry

    private var tier: Difficulty { entry.tier }
    private var stats: TierSnapshot? { entry.snapshot?.tier(tier) }
    private var accent: Color { WidgetPalette.accent(tier) }

    var body: some View {
        content
            .widgetURL(ClueweaveLink.tier(tier).url)
    }

    private var countText: String {
        guard let s = stats else { return "—" }
        return "\(s.solved)/\(s.total)"
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("\(shortTierName(tier)) \(countText)")

        case .accessoryCircular:
            ProgressRing(fraction: stats?.fraction ?? 0, tint: .white, lineWidth: 4) {
                VStack(spacing: -1) {
                    Text(shortTierName(tier))
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                    Text(countText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
            }
            .widgetAccentable()

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(tier.displayName.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(stats?.suggestionTitle ?? "Nothing here yet")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    ProgressView(value: stats?.fraction ?? 0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                    Text(countText)
                        .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                }
            }
            .widgetAccentable()

        case .systemMedium:
            medium

        default:
            small
        }
    }

    @ViewBuilder
    private var small: some View {
        VStack(spacing: 8) {
            ProgressRing(fraction: stats?.fraction ?? 0, tint: accent, lineWidth: 7) {
                VStack(spacing: -2) {
                    Text(countText)
                        .font(.system(.headline, design: .rounded, weight: .heavy).monospacedDigit())
                    Text("solved")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxHeight: .infinity)
            Text(tier.displayName)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(accent)
            Text(stats?.suggestionTitle ?? "—")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var medium: some View {
        HStack(spacing: 16) {
            ProgressRing(fraction: stats?.fraction ?? 0, tint: accent, lineWidth: 8) {
                VStack(spacing: -2) {
                    Text(countText)
                        .font(.system(.title3, design: .rounded, weight: .heavy).monospacedDigit())
                    Text("solved")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 6) {
                Text(tier.displayName)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(accent)
                if let s = stats, let id = s.suggestionID, let title = s.suggestionTitle {
                    // A medium widget supports several tap targets, so the
                    // suggestion gets its own — the tier link stays the
                    // background tap (`widgetURL`).
                    Link(destination: ClueweaveLink.puzzle(id).url) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.isComplete ? "Most score left to win" : "Next up")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(title)
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .lineLimit(1)
                        }
                    }
                    if s.isComplete {
                        Label("Tier complete", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                    }
                } else {
                    Text("No puzzles at this difficulty yet.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
