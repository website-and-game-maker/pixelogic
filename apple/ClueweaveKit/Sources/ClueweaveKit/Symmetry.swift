// Symmetry detection (port of src/engine/symmetry.ts).

public struct Symmetry: Sendable, Equatable {
    /// Mirror across the vertical centre axis (left ↔ right).
    public let horizontal: Bool
    /// Mirror across the horizontal centre axis (top ↔ bottom).
    public let vertical: Bool
    /// 180° rotation maps the picture onto itself.
    public let rotational: Bool
}

public func detectSymmetry(_ grid: [[Bool]]) -> Symmetry {
    let h = grid.count
    let w = h > 0 ? grid[0].count : 0
    var horizontal = true
    var vertical = true
    var rotational = true
    for r in 0..<h {
        for c in 0..<w {
            if grid[r][c] != grid[r][w - 1 - c] { horizontal = false }
            if grid[r][c] != grid[h - 1 - r][c] { vertical = false }
            if grid[r][c] != grid[h - 1 - r][w - 1 - c] { rotational = false }
        }
    }
    return Symmetry(horizontal: horizontal, vertical: vertical, rotational: rotational)
}

/// True if the picture has any mirror or 180° rotational symmetry.
public func isSymmetric(_ grid: [[Bool]]) -> Bool {
    let s = detectSymmetry(grid)
    return s.horizontal || s.vertical || s.rotational
}
