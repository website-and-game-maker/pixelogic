// A stepped, interactive mini-lesson scaled for the wrist. The illustration /
// interactive grid sits at the TOP, a single Next button at the BOTTOM. Three to
// four short steps: clues describe runs → tap to fill → toggle to cross → it's
// solvable by logic, ending with "Start playing". Auto-shown on first launch via
// a watch-local AppStorage flag (see WatchHomeView).

import SwiftUI
import PixelogicKit

#if canImport(WatchKit)
import WatchKit
#endif

struct WatchTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called when the lesson finishes from the auto-shown first-launch sheet.
    var onFinish: (() -> Void)? = nil

    private let puzzle = PixelogicKit.puzzle(withID: "plus")!
    @State private var session: GameSession
    @State private var marks: Grid
    @State private var stepIndex = 0
    @State private var crossMode = false

    private struct Step {
        let text: String
        /// nil = an info step (advance with Next); otherwise switch to this mode.
        let crossMode: Bool?
        /// Goal cells + the value they must reach (nil = info-only step).
        let goal: [(Int, Int)]?
        let want: Cell
    }

    private let steps: [Step] = [
        Step(text: "The numbers around the grid count the runs of filled cells in each row and column. Let's solve this little 5×5.",
             crossMode: nil, goal: nil, want: .filled),
        Step(text: "Row 3's clue is 5, and the row is 5 wide — so it's all filled. Tap each highlighted cell.",
             crossMode: false, goal: [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4)], want: .filled),
        Step(text: "Cells you know are empty can be crossed. We switched you to ✕ Cross — cross the top-left corner.",
             crossMode: true, goal: [(0, 0)], want: .empty),
        Step(text: "Back to painting. Column 3's clue is 5 too — fill it to finish the picture.",
             crossMode: false, goal: [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2)], want: .filled),
        Step(text: "Solved! Read the clues, fill what's forced, cross what's empty. Every puzzle is solvable by logic alone.",
             crossMode: nil, goal: nil, want: .filled),
    ]

    init(onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        let p = PixelogicKit.puzzle(withID: "plus")!
        let s = GameSession(puzzle: p)
        _session = State(initialValue: s)
        _marks = State(initialValue: s.marks)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Illustration / interactive grid at the TOP.
                WatchTutorialBoard(puzzle: puzzle, marks: marks, highlight: highlightSet) { r, c in
                    handleTap(r, c)
                }
                .frame(height: 120)

                if let cross = steps[stepIndex].crossMode {
                    HStack(spacing: 4) {
                        Image(systemName: cross ? "xmark" : "paintbrush.fill")
                        Text(cross ? "Crossing" : "Painting")
                    }
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(cross ? .gray : .teal)
                }

                Text(steps[stepIndex].text)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Next / Start playing button at the BOTTOM.
                if steps[stepIndex].goal == nil {
                    Button {
                        if stepIndex == steps.count - 1 {
                            finish()
                        } else {
                            stepIndex += 1
                            applyStepMode()
                        }
                    } label: {
                        Text(stepIndex == steps.count - 1 ? "Start playing" : "Next")
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.teal)
                }
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("How to play")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Skip") { finish() }
                    .font(.system(.caption2, design: .rounded, weight: .bold))
            }
        }
    }

    /// Cells the current step wants the player to act on (lit up on the board).
    private var highlightSet: Set<[Int]> {
        guard let goal = steps[stepIndex].goal else { return [] }
        return Set(goal.map { [$0.0, $0.1] })
    }

    private func handleTap(_ r: Int, _ c: Int) {
        guard steps[stepIndex].goal != nil else { return }
        session.mode = crossMode ? .cross : .paint
        session.toggle(r, c)
        marks = session.marks
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.click)
        #endif
        advanceIfSatisfied()
    }

    private func applyStepMode() {
        if let cross = steps[stepIndex].crossMode { crossMode = cross }
    }

    /// Completing the PICTURE by any path jumps to the final step — the player
    /// can never get trapped.
    private func advanceIfSatisfied() {
        if session.isSolved && stepIndex < steps.count - 1 {
            stepIndex = steps.count - 1
            return
        }
        guard let goal = steps[stepIndex].goal else { return }
        let want = steps[stepIndex].want
        if goal.allSatisfy({ marks[$0.0][$0.1] == want }) {
            stepIndex += 1
            applyStepMode()
        }
    }

    private func finish() {
        if let onFinish { onFinish() } else { dismiss() }
    }
}

/// Tutorial board: like the play board but with optional cell highlighting and a
/// fixed small footprint. Reuses the same clue-rail geometry.
struct WatchTutorialBoard: View {
    let puzzle: Puzzle
    let marks: Grid
    let highlight: Set<[Int]>
    let onTap: (Int, Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let rowSpan: CGFloat = 0.62 * CGFloat(max(1, puzzle.rowClues.map(\.count).max() ?? 1))
            let colSpan: CGFloat = 0.62 * CGFloat(max(1, puzzle.colClues.map(\.count).max() ?? 1))
            let cell = min(
                geo.size.width / (CGFloat(puzzle.width) + rowSpan),
                geo.size.height / (CGFloat(puzzle.height) + colSpan)
            )
            let ox = rowSpan * cell
            let oy = colSpan * cell

            ZStack(alignment: .topLeading) {
                ForEach(0..<puzzle.width, id: \.self) { c in
                    let nums = puzzle.colClues[c].isEmpty ? [0] : puzzle.colClues[c]
                    VStack(spacing: 0) {
                        ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                            Text("\(n)").font(.system(size: cell * 0.42, weight: .heavy, design: .rounded))
                        }
                    }
                    .frame(width: cell)
                    .position(x: ox + CGFloat(c) * cell + cell / 2, y: oy / 2)
                }
                ForEach(0..<puzzle.height, id: \.self) { r in
                    let nums = puzzle.rowClues[r].isEmpty ? [0] : puzzle.rowClues[r]
                    HStack(spacing: 2) {
                        ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                            Text("\(n)").font(.system(size: cell * 0.42, weight: .heavy, design: .rounded))
                        }
                    }
                    .frame(height: cell)
                    .position(x: ox / 2, y: oy + CGFloat(r) * cell + cell / 2)
                }

                ForEach(0..<puzzle.height, id: \.self) { r in
                    ForEach(0..<puzzle.width, id: \.self) { c in
                        cellView(r, c, size: cell)
                            .position(x: ox + CGFloat(c) * cell + cell / 2, y: oy + CGFloat(r) * cell + cell / 2)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cellView(_ r: Int, _ c: Int, size: CGFloat) -> some View {
        let mark = marks[r][c]
        let lit = highlight.contains([r, c])
        Button {
            onTap(r, c)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(mark == .filled ? Color.teal : Color.white.opacity(0.14))
                if lit {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.yellow, lineWidth: 1.5)
                }
                if mark == .empty {
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: size - 1.5, height: size - 1.5)
        }
        .buttonStyle(.plain)
    }
}
