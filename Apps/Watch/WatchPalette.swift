// Watch-local color palette. The shared PixelogicKit BadgeKey ships a geometric
// SF Symbol per badge (`.glyph`) but no color — the apps choose their own. These
// are the watch's choices, kept in one place so the rows, the legend, and the
// section headers stay consistent. Tuned to read on the dark watch background
// while staying in the Pixelogic teal/baby-blue family.

import SwiftUI
import PixelogicKit

enum WatchPalette {
    /// Non-clickable badge indicator color, one per trait.
    static func color(for key: BadgeKey) -> Color {
        switch key {
        case .symmetric: return .teal
        case .named: return .yellow
        case .patterned: return .mint
        }
    }

    /// Difficulty-tier color key (used in section headers and the legend).
    static func color(for tier: Difficulty) -> Color {
        switch tier {
        case .easy: return .green
        case .medium: return .teal
        case .hard: return .blue
        case .expert: return .orange
        case .max: return .pink
        }
    }

    /// One-line plain-language meaning for the legend (wrist-sized; the full
    /// blurb lives in PixelogicKit for the phone/web).
    static func meaning(for key: BadgeKey) -> String {
        switch key {
        case .symmetric: return "Picture mirrors itself — solve one side, get the other."
        case .named: return "The title hints at what you're drawing."
        case .patterned: return "Every row and column is a single solid run."
        }
    }
}
