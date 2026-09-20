// The unfinished board, shrunk to widget size.
//
// No clue rails: at widget scale the numbers are unreadable, and the point of
// the thumbnail is recognition ("that's the one I was halfway through"), not
// play. Crosses become faint dots rather than ✕ glyphs, which at 3 pt is the
// difference between texture and mud.

import SwiftUI
import WidgetKit
import ClueweaveKit

struct MiniBoard: View {
    let preview: BoardPreview
    /// Accessory (watch face / Lock Screen) families are stencilled to one
    /// color, so the board has to carry itself on shape alone.
    var monochrome = false

    var body: some View {
        GeometryReader { geo in
            let cols = max(1, preview.width)
            let rows = max(1, preview.height)
            let side = min(geo.size.width / CGFloat(cols), geo.size.height / CGFloat(rows))
            let inset = max(0.5, side * 0.08)
            let grid = preview.grid

            ZStack(alignment: .topLeading) {
                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<cols, id: \.self) { c in
                        cell(grid.indices.contains(r) && grid[r].indices.contains(c)
                             ? grid[r][c] : .unknown,
                             side: side, inset: inset)
                            .offset(x: CGFloat(c) * side, y: CGFloat(r) * side)
                    }
                }
            }
            .frame(width: CGFloat(cols) * side, height: CGFloat(rows) * side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(max(1, preview.width)) / CGFloat(max(1, preview.height)),
                     contentMode: .fit)
        .accessibilityHidden(true)   // the surrounding label already says it
    }

    @ViewBuilder
    private func cell(_ mark: Cell, side: CGFloat, inset: CGFloat) -> some View {
        let size = max(1, side - inset)
        // Accessory families stencil everything to one color, so the
        // monochrome variants differ only in opacity, not hue.
        let filled: Color = monochrome ? .primary : WidgetPalette.fill
        let crossed: Color = monochrome
            ? Color.primary.opacity(0.35) : WidgetPalette.cross.opacity(0.7)
        let blank: Color = monochrome ? Color.primary.opacity(0.12) : WidgetPalette.track

        switch mark {
        case .filled:
            RoundedRectangle(cornerRadius: max(0.5, side * 0.18))
                .fill(filled)
                .frame(width: size, height: size)
        case .empty:
            Circle()
                .fill(crossed)
                .frame(width: max(1, size * 0.3), height: max(1, size * 0.3))
                .frame(width: size, height: size)
        case .unknown:
            RoundedRectangle(cornerRadius: max(0.5, side * 0.18))
                .fill(blank)
                .frame(width: size, height: size)
        }
    }
}

/// A progress ring. Used for "how far into this board" and "how much of this
/// tier is solved" — the same visual for both, because they answer the same
/// shape of question.
struct ProgressRing<Label: View>: View {
    let fraction: Double
    var tint: Color = WidgetPalette.fill
    var lineWidth: CGFloat = 5
    @ViewBuilder var label: () -> Label

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetPalette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label()
        }
    }
}

extension ProgressRing where Label == EmptyView {
    init(fraction: Double, tint: Color = WidgetPalette.fill, lineWidth: CGFloat = 5) {
        self.init(fraction: fraction, tint: tint, lineWidth: lineWidth) { EmptyView() }
    }
}

/// Every widget's "there is nothing here yet" state. A blank widget looks
/// broken; this one explains itself and is still a tap target.
struct WidgetEmptyState: View {
    var title = "Clueweave"
    var message = "Open the app to start a puzzle."
    var symbol = "square.grid.3x3"

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(WidgetPalette.fill)
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .heavy))
            Text(message)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .padding(6)
    }
}
