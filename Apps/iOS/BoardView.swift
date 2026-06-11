// The nonogram board: clue rails + cell grid, rendered with Canvas for crisp
// performance up to 15×15, with tap & line-locked drag painting (the same
// input model as the web app).

import SwiftUI
import PixelogicKit

struct BoardView: View {
    let puzzle: Puzzle
    let marks: Grid
    let clueStyle: ClueStyle
    let mistakeCheck: Bool
    var interactive = true
    /// (row, col, isDrag) — the view model decides paint vs cross.
    var onTouch: ((Int, Int, Bool) -> Void)?

    @State private var dragAxis: Axis?
    @State private var dragStart: (r: Int, c: Int)?

    private enum Axis { case row, col }

    private var maxRowClue: Int { max(1, puzzle.rowClues.map(\.count).max() ?? 1) }
    private var maxColClue: Int { max(1, puzzle.colClues.map(\.count).max() ?? 1) }

    var body: some View {
        GeometryReader { geo in
            let layout = boardLayout(in: geo.size)
            Canvas { ctx, _ in
                drawColClues(ctx, layout)
                drawRowClues(ctx, layout)
                drawCells(ctx, layout)
            }
            .gesture(interactive ? touchGesture(layout) : nil)
            .accessibilityLabel("\(puzzle.title), \(puzzle.height) by \(puzzle.width) puzzle grid")
        }
        .aspectRatio(aspect, contentMode: .fit)
    }

    private var aspect: CGFloat {
        let cluesW = 0.62 * CGFloat(maxRowClue)
        let cluesH = 0.62 * CGFloat(maxColClue)
        return (CGFloat(puzzle.width) + cluesW) / (CGFloat(puzzle.height) + cluesH)
    }

    private struct Layout {
        let cell: CGFloat
        let originX: CGFloat
        let originY: CGFloat
    }

    private func boardLayout(in size: CGSize) -> Layout {
        let cluesW = 0.62 * CGFloat(maxRowClue)
        let cluesH = 0.62 * CGFloat(maxColClue)
        let cell = min(
            size.width / (CGFloat(puzzle.width) + cluesW),
            size.height / (CGFloat(puzzle.height) + cluesH)
        )
        return Layout(cell: cell, originX: cluesW * cell, originY: cluesH * cell)
    }

    // MARK: - Drawing

    private func clueColor(done: Bool) -> Color {
        guard done else { return Theme.ink }
        switch clueStyle {
        case .grey, .strike: return Theme.inkSoft
        case .hide: return .clear
        case .none: return Theme.ink
        }
    }

    private func rowDone(_ r: Int) -> Bool {
        clueStyle != .none && cluesForLine(marks[r].map { $0 == .filled }) == puzzle.rowClues[r]
    }

    private func colDone(_ c: Int) -> Bool {
        clueStyle != .none && cluesForLine(marks.map { $0[c] == .filled }) == puzzle.colClues[c]
    }

    private func drawColClues(_ ctx: GraphicsContext, _ l: Layout) {
        for c in 0..<puzzle.width {
            let clue = puzzle.colClues[c]
            let done = colDone(c)
            let nums = clue.isEmpty ? [0] : clue
            for (i, n) in nums.enumerated() {
                let y = l.originY - CGFloat(nums.count - i) * l.cell * 0.58 + l.cell * 0.06
                let x = l.originX + CGFloat(c) * l.cell + l.cell / 2
                draw(ctx, "\(n)", at: CGPoint(x: x, y: y + l.cell * 0.26), size: l.cell * 0.42, color: clueColor(done: done), strike: done && clueStyle == .strike)
            }
        }
    }

    private func drawRowClues(_ ctx: GraphicsContext, _ l: Layout) {
        for r in 0..<puzzle.height {
            let clue = puzzle.rowClues[r]
            let done = rowDone(r)
            let nums = clue.isEmpty ? [0] : clue
            for (i, n) in nums.enumerated() {
                let x = l.originX - CGFloat(nums.count - i) * l.cell * 0.58 + l.cell * 0.12
                let y = l.originY + CGFloat(r) * l.cell + l.cell / 2
                draw(ctx, "\(n)", at: CGPoint(x: x + l.cell * 0.2, y: y), size: l.cell * 0.42, color: clueColor(done: done), strike: done && clueStyle == .strike)
            }
        }
    }

    private func draw(_ ctx: GraphicsContext, _ s: String, at point: CGPoint, size: CGFloat, color: Color, strike: Bool) {
        var text = AttributedString(s)
        text.font = .system(size: size, weight: .heavy, design: .rounded)
        text.foregroundColor = color
        if strike { text.strikethroughStyle = .single }
        ctx.draw(Text(text), at: point)
    }

    private func drawCells(_ ctx: GraphicsContext, _ l: Layout) {
        let w = puzzle.width
        let h = puzzle.height
        // Surface + outer border
        let boardRect = CGRect(x: l.originX, y: l.originY, width: CGFloat(w) * l.cell, height: CGFloat(h) * l.cell)
        ctx.fill(Path(roundedRect: boardRect, cornerRadius: 4), with: .color(Theme.surface))

        for r in 0..<h {
            for c in 0..<w {
                let rect = CGRect(
                    x: l.originX + CGFloat(c) * l.cell,
                    y: l.originY + CGFloat(r) * l.cell,
                    width: l.cell, height: l.cell
                ).insetBy(dx: 0.5, dy: 0.5)
                switch marks[r][c] {
                case .filled:
                    let wrong = mistakeCheck && !puzzle.solution[r][c]
                    ctx.fill(Path(rect), with: wrong ? .color(Theme.mistake) : .linearGradient(
                        Gradient(colors: [Theme.filledA, Theme.filledB]),
                        startPoint: rect.origin,
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    ))
                case .empty:
                    let inset = rect.insetBy(dx: l.cell * 0.3, dy: l.cell * 0.3)
                    var path = Path()
                    path.move(to: CGPoint(x: inset.minX, y: inset.minY))
                    path.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
                    path.move(to: CGPoint(x: inset.maxX, y: inset.minY))
                    path.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
                    ctx.stroke(path, with: .color(Theme.cross), lineWidth: 2)
                case .unknown:
                    break
                }
            }
        }

        // Grid lines (major every 5)
        for c in 0...w {
            let major = c % 5 == 0
            let x = l.originX + CGFloat(c) * l.cell
            var p = Path()
            p.move(to: CGPoint(x: x, y: l.originY))
            p.addLine(to: CGPoint(x: x, y: l.originY + CGFloat(h) * l.cell))
            ctx.stroke(p, with: .color(major ? Theme.lineMajor : Theme.line), lineWidth: major ? 1.6 : 0.8)
        }
        for r in 0...h {
            let major = r % 5 == 0
            let y = l.originY + CGFloat(r) * l.cell
            var p = Path()
            p.move(to: CGPoint(x: l.originX, y: y))
            p.addLine(to: CGPoint(x: l.originX + CGFloat(w) * l.cell, y: y))
            ctx.stroke(p, with: .color(major ? Theme.lineMajor : Theme.line), lineWidth: major ? 1.6 : 0.8)
        }
    }

    // MARK: - Input

    private func cellAt(_ point: CGPoint, _ l: Layout) -> (Int, Int)? {
        let c = Int(floor((point.x - l.originX) / l.cell))
        let r = Int(floor((point.y - l.originY) / l.cell))
        guard r >= 0, c >= 0, r < puzzle.height, c < puzzle.width else { return nil }
        return (r, c)
    }

    private func touchGesture(_ l: Layout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let (r, c) = cellAt(value.location, l) else { return }
                if dragStart == nil {
                    dragStart = (r, c)
                    onTouch?(r, c, false)
                    return
                }
                guard let start = dragStart else { return }
                // Lock the stroke to its first axis of movement (web behaviour).
                if dragAxis == nil && (r != start.r || c != start.c) {
                    dragAxis = abs(c - start.c) >= abs(r - start.r) ? .row : .col
                }
                switch dragAxis {
                case .row where r == start.r:
                    onTouch?(start.r, c, true)
                case .col where c == start.c:
                    onTouch?(r, start.c, true)
                default:
                    break
                }
            }
            .onEnded { _ in
                dragStart = nil
                dragAxis = nil
            }
    }
}
