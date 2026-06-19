// Pixelogic design system, translated 1:1 from the web app's CSS custom
// properties (src/style.css :root). Baby-blue / turquoise, round corners,
// generous whitespace, SF Rounded in place of Nunito.
//
// Colors are now LIGHT/DARK adaptive (see Color(lightHex:darkHex:)). The brand
// reads the same way in both modes: turquoise marks, soft tinted chips, calm
// surfaces — just inverted for night. The app no longer forces light mode.

import SwiftUI
import UIKit
import PixelogicKit

// SwiftUI also defines a `Grid` (a layout view); a module-level alias makes
// every unqualified `Grid` in this target mean the engine's cell grid.
typealias Grid = PixelogicKit.Grid

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A light/dark adaptive color resolved per trait collection, so a single
    /// `Theme` token paints correctly in both appearances.
    init(lightHex: UInt32, darkHex: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum Theme {
    // Surfaces & ink — adaptive. Dark variants are deep teal-charcoals so the
    // brand turquoise still sings against them.
    static let bg = Color(lightHex: 0xE9F7F7, darkHex: 0x0C2024)
    static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x14292E)
    static let surface2 = Color(lightHex: 0xEEF8F8, darkHex: 0x1C3338)
    static let ink = Color(lightHex: 0x173A40, darkHex: 0xE8F4F4)
    static let inkSoft = Color(lightHex: 0x5F8087, darkHex: 0x9DBAC0)

    // Brand accents. `primaryDeep` doubles as the link/tint color, so its dark
    // variant is brightened to stay legible on dark surfaces.
    static let primary = Color(lightHex: 0x1AB9A9, darkHex: 0x29CDBC)
    static let primaryDeep = Color(lightHex: 0x0E9184, darkHex: 0x49D8C6)
    static let accent = Color(lightHex: 0x6CC8EC, darkHex: 0x6CC8EC)
    static let accentSoft = Color(lightHex: 0xD6EEFB, darkHex: 0x173A4B)

    // Board.
    static let filledA = Color(lightHex: 0x23C2B1, darkHex: 0x2BD0BE)
    static let filledB = Color(lightHex: 0x109386, darkHex: 0x15A899)
    static let cross = Color(lightHex: 0x9BB9BF, darkHex: 0x6E9197)
    static let line = Color(lightHex: 0xD2E9E9, darkHex: 0x223C41)
    static let lineMajor = Color(lightHex: 0xA4D4D2, darkHex: 0x375A60)
    static let mistake = Color(lightHex: 0xEF6F6F, darkHex: 0xF38A8A)

    // Symmetry strip.
    static let symmetry = Color(lightHex: 0x0FB5C4, darkHex: 0x2DD2E0)
    static let symmetrySoft = Color(lightHex: 0xD4F4F7, darkHex: 0x123A41)
    /// Text color used on top of `symmetrySoft` (was a hard-coded hex in PlayView).
    static let symmetryInk = Color(lightHex: 0x0B7E89, darkHex: 0x6FE2EC)

    static let gold = Color(lightHex: 0xE3B23C, darkHex: 0xEAC257)

    /// "Too many filled squares in this line" warning. A calm plum — clearly
    /// distinct from the red mistake cue and the teal brand, visible without
    /// being alarming.
    static let overfill = Color(lightHex: 0x9A3D86, darkHex: 0xE49BCF)

    static let fillGradient = LinearGradient(
        colors: [filledA, filledB], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandGradient = LinearGradient(
        colors: [primary, primaryDeep], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// MAX tier chip — a gradient, matching the web app's `.diff-max`.
    static let maxChipGradient = LinearGradient(
        colors: [Color(hex: 0x2B2140), Color(hex: 0x4A2D5E)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Difficulty & badge chips stay fixed pastels: they are self-contained
    // pills (light tint + dark text) that read clearly on either appearance,
    // and keeping them constant preserves the tier color language exactly.
    static func difficultyColors(_ d: Difficulty) -> (bg: Color, fg: Color) {
        switch d {
        case .easy: (Color(hex: 0xD7F5EA), Color(hex: 0x0C8F6C))
        case .medium: (Color(hex: 0xD8EEFB), Color(hex: 0x1A73A8))
        case .hard: (Color(hex: 0xECE0FB), Color(hex: 0x7A4FC0))
        case .expert: (Color(hex: 0xFFE2DD), Color(hex: 0xC0492F))
        case .max: (Color(hex: 0x2B2140), .white)
        }
    }

    static func badgeColors(_ key: BadgeKey) -> (bg: Color, fg: Color) {
        switch key {
        case .symmetric: (Color(hex: 0xD4F4F7), Color(hex: 0x0B7E89))
        case .named: (Color(hex: 0xFDE3EF), Color(hex: 0xB13D7E))
        case .patterned: (Color(hex: 0xFDEED3), Color(hex: 0xA06B12))
        }
    }
}

/// A rounded pill chip, matching the web's `.chip`.
struct Chip: View {
    let text: String
    let bg: Color
    let fg: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }
}

struct DifficultyChip: View {
    let difficulty: Difficulty
    var body: some View {
        let colors = Theme.difficultyColors(difficulty)
        Text(difficulty.displayName)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                // MAX gets the brand gradient (web parity); all other tiers
                // keep their flat pastel pill.
                if difficulty == .max {
                    Capsule().fill(Theme.maxChipGradient)
                } else {
                    Capsule().fill(colors.bg)
                }
            }
            .foregroundStyle(colors.fg)
    }
}

/// A non-clickable badge indicator: tinted pill with the badge's geometric
/// SF Symbol and a short label. Badge filtering stays reachable elsewhere
/// (the About legend, the symmetry strip), so the chip itself is purely a
/// visual trait marker and never steals a tap from the puzzle card.
struct BadgeChipView: View {
    let badge: Badge

    var body: some View {
        let colors = Theme.badgeColors(badge.key)
        HStack(spacing: 4) {
            Image(systemName: badge.key.glyph)
                .font(.system(size: 9, weight: .black))
            Text(shortLabel)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(colors.bg))
        .foregroundStyle(colors.fg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.key.name)
    }

    /// The stored label carries a leading unicode glyph (e.g. "◈ Symmetric ·
    /// H+V"); the SF Symbol replaces it, so strip that prefix to avoid a
    /// double icon.
    private var shortLabel: String {
        var s = badge.label
        if let first = s.first, first == badge.key.icon.first {
            s.removeFirst()
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

/// A wrapping row layout (SwiftUI `Layout`, iOS 16+): lays children left to
/// right, wrapping to a new line when the next child would overflow the
/// proposed width. Used for chip rows so badges never clip on narrow screens.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let width: CGFloat = rows.map { row in
            row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1))
        }.max() ?? 0
        let height: CGFloat = rows.reduce(0) { partial, row in
            partial + (row.map(\.size.height).max() ?? 0)
        } + lineSpacing * CGFloat(max(0, rows.count - 1))
        // When unconstrained, report the natural single-line width.
        let reportedWidth = proposal.width == nil ? width : min(width, maxWidth)
        return CGSize(width: reportedWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map(\.size.height).max() ?? 0
            for item in row {
                item.subview.place(
                    at: CGPoint(x: x, y: y + (rowHeight - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [[Item]] {
        var rows: [[Item]] = []
        var row: [Item] = []
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = (row.isEmpty ? 0 : spacing) + size.width
            if !row.isEmpty, x + needed > maxWidth {
                rows.append(row)
                row = []
                x = 0
            }
            row.append(Item(subview: subview, size: size))
            x += (row.count == 1 ? 0 : spacing) + size.width
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }
}

/// Navigation destinations for the home stack.
enum Route: Hashable {
    case play(String)            // library puzzle id
    case playCustom(String)      // custom puzzle id
    case badge(BadgeKey)
    case editor(String?)         // custom id to edit, nil = new
    case about
    case privacy                 // the dedicated privacy policy page
    case explainer(String)       // watch-solve for a library puzzle id
    case generator               // the puzzle generator screen
    case playGenerated(String)   // a saved generated puzzle id
}
