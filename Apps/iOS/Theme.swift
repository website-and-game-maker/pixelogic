// Pixelogic design system, translated 1:1 from the web app's CSS custom
// properties (src/style.css :root). Baby-blue / turquoise, round corners,
// generous whitespace, SF Rounded in place of Nunito.

import SwiftUI
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
}

enum Theme {
    static let bg = Color(hex: 0xE9F7F7)
    static let surface = Color.white
    static let surface2 = Color(hex: 0xEEF8F8)
    static let ink = Color(hex: 0x173A40)
    static let inkSoft = Color(hex: 0x5F8087)
    static let primary = Color(hex: 0x1AB9A9)
    static let primaryDeep = Color(hex: 0x0E9184)
    static let accent = Color(hex: 0x6CC8EC)
    static let accentSoft = Color(hex: 0xD6EEFB)
    static let filledA = Color(hex: 0x23C2B1)
    static let filledB = Color(hex: 0x109386)
    static let cross = Color(hex: 0x9BB9BF)
    static let line = Color(hex: 0xD2E9E9)
    static let lineMajor = Color(hex: 0xA4D4D2)
    static let mistake = Color(hex: 0xEF6F6F)
    static let symmetry = Color(hex: 0x0FB5C4)
    static let symmetrySoft = Color(hex: 0xD4F4F7)
    static let gold = Color(hex: 0xE3B23C)

    static let fillGradient = LinearGradient(
        colors: [filledA, filledB], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandGradient = LinearGradient(
        colors: [primary, primaryDeep], startPoint: .topLeading, endPoint: .bottomTrailing
    )

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
        case .symmetric: (symmetrySoft, Color(hex: 0x0B7E89))
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
        Chip(text: difficulty.displayName, bg: colors.bg, fg: colors.fg)
    }
}

/// A tappable badge chip that opens the badge's filter screen.
struct BadgeChipView: View {
    let badge: Badge
    var body: some View {
        let colors = Theme.badgeColors(badge.key)
        NavigationLink(value: Route.badge(badge.key)) {
            Chip(text: badge.label, bg: colors.bg, fg: colors.fg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("See all \(badge.key.name) puzzles")
    }
}

/// Navigation destinations for the home stack.
enum Route: Hashable {
    case play(String)            // library puzzle id
    case playCustom(String)      // custom puzzle id
    case badge(BadgeKey)
    case editor(String?)         // custom id to edit, nil = new
    case about
    case explainer(String)       // watch-solve for a library puzzle id
}
