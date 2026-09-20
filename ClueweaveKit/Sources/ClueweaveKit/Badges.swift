// Puzzle badges (port of src/engine/badges.ts): self-descriptive traits that
// shift a puzzle's weight in the overall Clueweave Score. <1 = easier.

public enum BadgeKey: String, CaseIterable, Sendable {
    case symmetric, named, patterned

    public var name: String {
        switch self {
        case .symmetric: "Symmetric"
        case .named: "Name-hint"
        case .patterned: "Patterned"
        }
    }

    public var icon: String {
        switch self {
        case .symmetric: "◈"
        case .named: "🏷"
        case .patterned: "▤"
        }
    }

    /// A small geometric SF Symbol for the badge — used where a compact,
    /// non-clickable indicator is wanted (puzzle tiles, the watch, legends).
    public var glyph: String {
        switch self {
        case .symmetric: "rhombus.fill"
        case .named: "tag.fill"
        case .patterned: "square.grid.3x3.fill"
        }
    }

    public var multiplier: Double {
        switch self {
        case .symmetric: 0.85
        case .named: 0.9
        case .patterned: 0.8
        }
    }

    public var blurb: String {
        switch self {
        case .symmetric:
            "The picture mirrors itself, so every deduction on one side gives you the other side for free."
        case .named:
            "The title tells you what you're drawing, so you can often guess where the picture is headed."
        case .patterned:
            "Every row and column is one solid run — once the shape starts, you mostly continue the pattern."
        }
    }
}

public struct Badge: Sendable, Equatable {
    public let key: BadgeKey
    /// Chip text, e.g. "◈ Symmetric · H+V".
    public let label: String
    public var multiplier: Double { key.multiplier }
}

/// True when every row AND every column contains at most one run of filled cells.
public func detectPatterned(_ grid: [[Bool]]) -> Bool {
    func runs(_ line: [Bool]) -> Int {
        var n = 0
        var inRun = false
        for v in line {
            if v && !inRun {
                n += 1
                inRun = true
            } else if !v {
                inRun = false
            }
        }
        return n
    }
    guard !grid.isEmpty else { return false }
    if grid.contains(where: { runs($0) > 1 }) { return false }
    for c in 0..<grid[0].count {
        if runs(grid.map { $0[c] }) > 1 { return false }
    }
    return true
}

/// Plain-English meaning of every code the Symmetric chip can show. The chip is
/// terse by necessity ("◈ Symmetric · H"), so this is the single source of truth
/// the help surfaces read from — keep it in sync with `symmetryDetail` below.
public struct SymmetryCode: Sendable, Equatable {
    public let code: String
    public let meaning: String
}

public let symmetryLegend: [SymmetryCode] = [
    SymmetryCode(
        code: "H",
        meaning: "Mirrors left ↔ right. Fold it down the middle and the two halves match."),
    SymmetryCode(
        code: "V",
        meaning: "Mirrors top ↔ bottom. Fold it across the middle and the two halves match."),
    SymmetryCode(
        code: "H+V",
        meaning: "Mirrors both ways at once — left ↔ right and top ↔ bottom."),
    SymmetryCode(
        code: "180°",
        meaning: "No mirror, but turn the picture upside-down and you get the same picture."),
]

/// Human detail for the symmetric badge: which way the picture mirrors.
public func symmetryDetail(_ grid: [[Bool]]) -> String? {
    let s = detectSymmetry(grid)
    if s.horizontal && s.vertical { return "H+V" }
    if s.horizontal { return "H" }
    if s.vertical { return "V" }
    if s.rotational { return "180°" }
    return nil
}

/// All badges that apply to a puzzle (auto-detected + the curated name flag).
public func puzzleBadges(solution: [[Bool]], named: Bool) -> [Badge] {
    var badges: [Badge] = []
    if let detail = symmetryDetail(solution) {
        badges.append(Badge(key: .symmetric, label: "◈ Symmetric · \(detail)"))
    }
    if named {
        badges.append(Badge(key: .named, label: "🏷 Name-hint"))
    }
    if detectPatterned(solution) {
        badges.append(Badge(key: .patterned, label: "▤ Patterned"))
    }
    return badges
}

public func puzzleBadges(_ puzzle: Puzzle) -> [Badge] {
    puzzleBadges(solution: puzzle.solution, named: puzzle.named)
}

/// Combined Clueweave-Score weight multiplier for a puzzle's badges.
public func badgeWeightMultiplier(_ badges: [Badge]) -> Double {
    badges.reduce(1) { $0 * $1.multiplier }
}
