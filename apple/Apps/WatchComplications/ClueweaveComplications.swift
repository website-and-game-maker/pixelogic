// Watch face complications.
//
// Three, because they answer three different questions:
//
//   • Launcher  — "open Clueweave". The smallest possible tap target, for
//                 people who just want the app on the face.
//   • Continue  — "what was I in the middle of?" with a progress ring.
//   • Tier      — "how am I doing at <difficulty>?", configurable.
//
// One hard constraint shapes all of them: an accessory family has exactly ONE
// tap target. `Link` does nothing on a watch face — only `widgetURL` is
// honoured — so a complication may *show* three things but can only *go* one
// place. Each one below therefore picks a single, defensible destination
// rather than pretending to be a menu.
//
// Deployment target is watchOS 11, above the watch app's own watchOS 9: it is
// what `AppIntentConfiguration` and the modern container background want, and
// it is also the floor for mirrored Live Activities.

import WidgetKit
import SwiftUI
import AppIntents
import ClueweaveKit

@main
struct ClueweaveComplicationBundle: WidgetBundle {
    var body: some Widget {
        LauncherComplication()
        ContinueComplication()
        TierComplication()
    }
}

// MARK: - Launcher

struct LauncherComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClueweaveLauncher", provider: SnapshotProvider()) { entry in
            LauncherView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Clueweave")
        .description("Open Clueweave from your watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

struct LauncherView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot? { entry.snapshot }

    var body: some View {
        content
            // Not always `.home`: if there is an unfinished board, opening the
            // menu just makes the player find it again. See `primaryLink`.
            .widgetURL((snapshot?.primaryLink ?? .home).url)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            if let snap = snapshot {
                Text("Clueweave \(snap.solved)/\(snap.total)")
            } else {
                Text("Clueweave")
            }

        case .accessoryCorner:
            Image(systemName: "square.grid.3x3.fill")
                .font(.title2)
                .widgetAccentable()
                .widgetLabel {
                    if let snap = snapshot {
                        // The curved label around a corner complication is the
                        // one free extra line a watch face offers — spend it on
                        // the number, not on repeating the app name.
                        Gauge(value: snap.fraction) {
                            Text("\(snap.solved)/\(snap.total)")
                        }
                        .gaugeStyle(.accessoryLinearCapacity)
                    } else {
                        Text("Clueweave")
                    }
                }

        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 15, weight: .bold))
                    if let snap = snapshot {
                        Text("\(snap.solved)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .widgetAccentable()
        }
    }
}

// MARK: - Continue

struct ContinueComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClueweaveWatchContinue", provider: SnapshotProvider()) { entry in
            WatchContinueView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Continue")
        .description("The board you left unfinished, with one tap to resume.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct WatchContinueView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot? { entry.snapshot }
    private var cont: ContinueSnapshot? { snapshot?.continueEntry }

    var body: some View {
        content
            .widgetURL((cont?.link ?? snapshot?.primaryLink ?? .home).url)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            if let c = cont {
                Text("\(c.title) \(Int(c.fraction * 100))%")
            } else if let r = snapshot?.recommendation {
                Text("Play \(r.title)")
            } else {
                Text("Clueweave")
            }

        case .accessoryCorner:
            Image(systemName: cont == nil ? "square.grid.3x3.fill" : "play.fill")
                .font(.title2)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: cont?.fraction ?? 0) {
                        Text(cont?.title ?? "Clueweave")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                }

        case .accessoryRectangular:
            rectangular

        default:
            ZStack {
                AccessoryWidgetBackground()
                ProgressRing(fraction: cont?.fraction ?? 0, tint: .white, lineWidth: 4) {
                    if let c = cont {
                        Text("\(Int(c.fraction * 100))")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.6)
                    } else {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
            }
            .widgetAccentable()
        }
    }

    /// The rectangular family is the only one with room for real content, so it
    /// is the one that must never be blank. Order of preference: the unfinished
    /// board, then what to play next, then the app's name. "Else home" would
    /// leave a wide, empty slot on the face doing nothing.
    @ViewBuilder
    private var rectangular: some View {
        if let c = cont {
            HStack(spacing: 6) {
                MiniBoard(preview: c.board, monochrome: true)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.title)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .lineLimit(1)
                    Text(shortTime(ms: c.elapsedMs))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    Gauge(value: c.fraction) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
            }
            .widgetAccentable()
        } else if let r = snapshot?.recommendation {
            VStack(alignment: .leading, spacing: 1) {
                Text("PLAY NEXT")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                Text(r.title)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                Text(r.difficulty.displayName)
                    .font(.system(size: 11, design: .rounded))
            }
            .widgetAccentable()
        } else {
            Label("Clueweave", systemImage: "square.grid.3x3.fill")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .widgetAccentable()
        }
    }
}

// MARK: - Per-difficulty

enum WatchTierChoice: String, AppEnum, CaseIterable {
    case easy, medium, hard, expert, max

    var difficulty: Difficulty { Difficulty(rawValue: rawValue) ?? .easy }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Difficulty" }

    static var caseDisplayRepresentations: [WatchTierChoice: DisplayRepresentation] {
        [
            .easy: "Easy",
            .medium: "Medium",
            .hard: "Hard",
            .expert: "Extra Hard",
            .max: "MAX",
        ]
    }
}

struct SelectWatchTierIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose a difficulty" }
    static var description: IntentDescription {
        IntentDescription("Pick which difficulty tier this complication tracks.")
    }

    @Parameter(title: "Difficulty", default: .easy)
    var tier: WatchTierChoice

    init() {}
}

struct WatchTierEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let tier: Difficulty
}

struct WatchTierProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchTierEntry {
        WatchTierEntry(date: Date(), snapshot: .placeholder, tier: .easy)
    }

    func snapshot(for configuration: SelectWatchTierIntent, in context: Context) async -> WatchTierEntry {
        WatchTierEntry(
            date: Date(),
            snapshot: context.isPreview ? .placeholder : SnapshotStore.read(),
            tier: configuration.tier.difficulty
        )
    }

    func timeline(
        for configuration: SelectWatchTierIntent, in context: Context
    ) async -> Timeline<WatchTierEntry> {
        let now = Date()
        return Timeline(
            entries: [WatchTierEntry(
                date: now, snapshot: SnapshotStore.read(), tier: configuration.tier.difficulty)],
            policy: .after(now.addingTimeInterval(60 * 60))
        )
    }
}

struct TierComplication: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "ClueweaveWatchTier",
            intent: SelectWatchTierIntent.self,
            provider: WatchTierProvider()
        ) { entry in
            WatchTierView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Difficulty")
        .description("Progress through one difficulty — tap to jump straight to it.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct WatchTierView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchTierEntry

    private var tier: Difficulty { entry.tier }
    private var stats: TierSnapshot? { entry.snapshot?.tier(tier) }

    /// The tap goes to the tier, as asked — "tap a difficulty badge, jump to
    /// that tier". The suggested puzzle is shown, not linked: with one tap
    /// available, the section is the more forgiving destination, because it
    /// still contains the suggestion.
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

        case .accessoryCorner:
            Text(shortTierName(tier))
                .font(.system(.body, design: .rounded, weight: .heavy))
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: stats?.fraction ?? 0) { Text(countText) }
                        .gaugeStyle(.accessoryLinearCapacity)
                }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(tier.displayName.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                Text(stats?.suggestionTitle ?? "Nothing here yet")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                Gauge(value: stats?.fraction ?? 0) { Text(countText) }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
            .widgetAccentable()

        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text(shortTierName(tier))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                    Text(countText)
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.6)
                }
            }
            .widgetAccentable()
        }
    }
}
