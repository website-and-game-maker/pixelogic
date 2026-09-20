// Colors for the widget and complication bundles.
//
// Compiled into the widget extensions ONLY — never into an app target. Both
// apps already declare their own `Color(hex:)` (`Theme.swift`, `WatchPalette.swift`),
// and two copies of the same extension in one module will not compile. The hex
// values are the same brand tokens, restated here so an extension does not have
// to import a UIKit-flavoured app file.

import SwiftUI
import ClueweaveKit

/// SwiftUI also ships a `Grid` layout view; spell the engine's out.
typealias EngineGrid = ClueweaveKit.Grid

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

enum WidgetPalette {
    // Brand turquoise — the same filled-cell color the boards use everywhere,
    // so a widget's mini board reads as the same game.
    static let fill = Color(hex: 0x23C2B1)
    static let fillDeep = Color(hex: 0x109386)
    static let cross = Color(hex: 0x9BB9BF)
    static let track = Color.primary.opacity(0.12)

    /// One accent per tier. Drawn from the app's difficulty chips (their *text*
    /// color, which is the saturated half of each pill) so the tier language
    /// carries over to a widget that has no room for a full chip.
    static func accent(_ tier: Difficulty) -> Color {
        switch tier {
        case .easy: Color(hex: 0x0C8F6C)
        case .medium: Color(hex: 0x1A73A8)
        case .hard: Color(hex: 0x7A4FC0)
        case .expert: Color(hex: 0xC0492F)
        case .max: Color(hex: 0x4A2D5E)
        }
    }
}

/// Short tier label for places a full "Extra Hard" will not fit.
func shortTierName(_ tier: Difficulty) -> String {
    switch tier {
    case .easy: "Easy"
    case .medium: "Med"
    case .hard: "Hard"
    case .expert: "X-Hard"
    case .max: "MAX"
    }
}

func shortTime(ms: Int) -> String {
    let total = max(0, ms / 1000)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%d:%02d", m, s)
}
