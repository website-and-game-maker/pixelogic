// The whole ladder at a glance: Clueweave Score, and every tier as its own
// tappable row. Medium and large only — five rows with five separate tap
// targets need the space, and a small widget can only ever link to one place.

import WidgetKit
import SwiftUI
import ClueweaveKit

struct ProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClueweaveProgress", provider: SnapshotProvider()) { entry in
            ProgressWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Progress")
        .description("Your Clueweave Score and every difficulty — tap a tier to jump to it.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot? { entry.snapshot }

    var body: some View {
        if let snap = snapshot, !snap.tiers.isEmpty {
            VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
                header(snap)
                ForEach(snap.tiers, id: \.tier) { tier in
                    Link(destination: tier.link.url) {
                        TierRow(stats: tier, isWorkingTier: tier.tier == snap.workingTier,
                                showSuggestion: family == .systemLarge)
                    }
                }
            }
        } else {
            // No snapshot yet (first launch, or the App Group is unavailable).
            WidgetEmptyState(message: "Open Clueweave once to fill this in.")
                .widgetURL(ClueweaveLink.home.url)
        }
    }

    @ViewBuilder
    private func header(_ snap: WidgetSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let score = snap.score {
                Text("\(score)")
                    .font(.system(.title2, design: .rounded, weight: .heavy).monospacedDigit())
                    .foregroundStyle(WidgetPalette.fillDeep)
                Text("/ 1600")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("Clueweave")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
            }
            Spacer(minLength: 0)
            Text("\(snap.solved)/\(snap.total) solved")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// One tier: a tinted bar, the count, and (with room) what to play next in it.
struct TierRow: View {
    let stats: TierSnapshot
    let isWorkingTier: Bool
    let showSuggestion: Bool

    private var accent: Color { WidgetPalette.accent(stats.tier) }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                // The working tier is where the progression model currently has
                // you; a ring around its dot is the cheapest way to say so.
                .overlay(
                    Circle()
                        .stroke(accent.opacity(isWorkingTier ? 0.85 : 0), lineWidth: 2)
                        .padding(-3)
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stats.tier.displayName)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                    if stats.isComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(accent)
                    }
                    Spacer(minLength: 0)
                    Text("\(stats.solved)/\(stats.total)")
                        .font(.system(.caption2, design: .rounded, weight: .bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: stats.fraction)
                    .progressViewStyle(.linear)
                    .tint(accent)
                if showSuggestion, let title = stats.suggestionTitle {
                    Text(stats.isComplete ? "Replay: \(title)" : "Next: \(title)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
