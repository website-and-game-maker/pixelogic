// The interactive tutorial and the custom-puzzle editor.

import SwiftUI
import PixelogicKit

// MARK: - Tutorial

struct TutorialView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pixelogic.ios.highVisibility") private var highVisibility = false

    private let puzzle = PixelogicKit.puzzle(withID: "plus")!
    @State private var session: GameSession
    @State private var marks: Grid
    @State private var stepIndex = 0
    @State private var mode: GameSession.Mode = .paint

    private struct Step {
        let text: String
        let mode: GameSession.Mode?
        /// Goal cells and the value they must reach (nil = info step, Next to advance).
        let goal: [(Int, Int)]?
        let want: Cell
    }

    private let steps: [Step] = [
        Step(text: "Welcome to Pixelogic! 👋 The numbers around the grid tell you the runs of filled cells in each row and column. Let's solve this little 5×5 together.",
             mode: nil, goal: nil, want: .filled),
        Step(text: "Row 3's clue is 5 — and the grid is 5 wide, so the whole row is filled. Tap each highlighted cell to fill it.",
             mode: .paint, goal: [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4)], want: .filled),
        Step(text: "Cells you know are empty can be crossed so you don't fill them by mistake. We've switched you to ✕ Cross — cross the top-left corner.",
             mode: .cross, goal: [(0, 0)], want: .empty),
        Step(text: "Back to painting. Column 3's clue is also 5 — fill the whole column to finish the picture.",
             mode: .paint, goal: [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2)], want: .filled),
        Step(text: "🎉 You solved it! That's the whole game: read the clues, fill what's forced, cross what's empty. A clue turns grey once its line is done — and plum if you've filled too many squares in that line. Need more contrast? Turn on High-visibility board in Settings for solid black crosses.",
             mode: nil, goal: nil, want: .filled),
    ]

    init() {
        let p = PixelogicKit.puzzle(withID: "plus")!
        let s = GameSession(puzzle: p)
        _session = State(initialValue: s)
        _marks = State(initialValue: s.marks)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("How to play")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Skip tutorial") { finish() }
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal)

            BoardView(puzzle: puzzle, marks: marks, clueStyle: .grey, mistakeCheck: false, highVisibility: highVisibility) { r, c, drag in
                guard steps[stepIndex].goal != nil || drag else { return }
                session.mode = mode
                if drag {
                    session.setCell(r, c, mode == .paint ? .filled : .empty, recordHistory: false)
                } else {
                    session.toggle(r, c)
                }
                marks = session.marks
                advanceIfSatisfied()
            }
            .padding(.horizontal, 28)

            if steps[stepIndex].goal != nil {
                Picker("Mode", selection: $mode) {
                    Text("🖌 Paint").tag(GameSession.Mode.paint)
                    Text("✕ Cross").tag(GameSession.Mode.cross)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 60)
            }

            VStack(spacing: 12) {
                Text(steps[stepIndex].text)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                if steps[stepIndex].goal == nil {
                    Button(stepIndex == steps.count - 1 ? "Start playing →" : "Next") {
                        if stepIndex == steps.count - 1 { finish() } else { stepIndex += 1; applyStepMode() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryDeep)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface))
            .padding(.horizontal)
            Spacer()
        }
        .padding(.top)
        .background(Theme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(false)
    }

    private func applyStepMode() {
        if let m = steps[stepIndex].mode { mode = m }
    }

    /// Robustness rule (same as web): completing the PICTURE by any path jumps
    /// straight to the final step — the player can never get trapped.
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
        app.store.tutorialSeen = true
        app.showTutorial = false
        dismiss()
    }
}

// MARK: - Editor

struct EditorView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    let editID: String?
    @State private var size = 10
    @State private var solution: [[Bool]]
    @State private var title = ""
    @State private var verdict: Verdict = .empty
    @State private var ambiguous: (Int, Int)?
    @State private var testing = false
    /// The value the current draw stroke paints (decided by its first cell).
    @State private var strokeValue: Bool?

    enum Verdict: Equatable, Sendable {
        case empty, checking, unique(Difficulty), notUnique(Int)
    }

    init(editID: String?, store: PlayerStore) {
        self.editID = editID
        if let editID, let existing = store.userPuzzles.first(where: { $0.id == editID }) {
            _solution = State(initialValue: existing.solution)
            _title = State(initialValue: existing.title)
            _size = State(initialValue: existing.solution.count)
        } else {
            _solution = State(initialValue: Array(repeating: Array(repeating: false, count: 10), count: 10))
        }
    }

    private var drawnPuzzle: Puzzle {
        let graded: Difficulty
        if case .unique(let d) = verdict { graded = d } else { graded = .easy }
        return Puzzle(id: "draft", title: title.isEmpty ? "My Puzzle" : title, solution: solution, difficulty: graded)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Size", selection: $size) {
                    ForEach([5, 8, 10, 12, 15], id: \.self) { Text("\($0) × \($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: size) { newSize in
                    solution = Array(repeating: Array(repeating: false, count: newSize), count: newSize)
                    analyze()
                }

                Text("Tap or drag to draw. Clues and a uniqueness check update as you go.")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)

                drawGrid
                    .padding(.horizontal, 24)

                verdictView

                TextField("Name your puzzle", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)

                HStack(spacing: 12) {
                    Button {
                        save()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryDeep)
                    .disabled(!isUnique)

                    Button { testing = true } label: { Label("Test", systemImage: "play") }
                        .disabled(filledCount == 0)

                    if filledCount > 0 {
                        ShareLink(item: webShareURL(forToken: encodePuzzle(solution, title: title.isEmpty ? "My Puzzle" : title))) {
                            Label("Share link", systemImage: "link")
                        }
                    }

                    Button("Clear", role: .destructive) {
                        solution = Array(repeating: Array(repeating: false, count: size), count: size)
                        analyze()
                    }
                }
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
            }
            .padding(.vertical)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(editID == nil ? "Create a puzzle" : "Edit puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .task { analyze() }
        .navigationDestination(isPresented: $testing) {
            PlayView(puzzle: drawnPuzzle, isLibrary: false, store: app.store)
        }
    }

    private var filledCount: Int { solution.flatMap { $0 }.filter { $0 }.count }

    private var isUnique: Bool {
        if case .unique = verdict { return true }
        return false
    }

    private var drawGrid: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(size)
            Canvas { ctx, _ in
                for r in 0..<size {
                    for c in 0..<size {
                        let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell).insetBy(dx: 0.5, dy: 0.5)
                        if solution[r][c] {
                            ctx.fill(Path(rect), with: .color(Theme.filledB))
                        } else {
                            ctx.fill(Path(rect), with: .color(Theme.surface))
                        }
                        if let amb = ambiguous, amb == (r, c) {
                            ctx.stroke(Path(rect), with: .color(Theme.gold), lineWidth: 3)
                        }
                    }
                }
                for i in 0...size {
                    let major = i % 5 == 0
                    var p = Path()
                    p.move(to: CGPoint(x: CGFloat(i) * cell, y: 0))
                    p.addLine(to: CGPoint(x: CGFloat(i) * cell, y: geo.size.height))
                    p.move(to: CGPoint(x: 0, y: CGFloat(i) * cell))
                    p.addLine(to: CGPoint(x: geo.size.width, y: CGFloat(i) * cell))
                    ctx.stroke(p, with: .color(major ? Theme.lineMajor : Theme.line), lineWidth: major ? 1.5 : 0.8)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let c = Int(value.location.x / cell)
                        let r = Int(value.location.y / cell)
                        guard r >= 0, c >= 0, r < size, c < size else { return }
                        let target = strokeValue ?? !solution[r][c]
                        if strokeValue == nil { strokeValue = target }
                        if solution[r][c] != target { solution[r][c] = target }
                    }
                    .onEnded { _ in
                        strokeValue = nil
                        analyze()
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var verdictView: some View {
        switch verdict {
        case .empty:
            Text("Draw something to get started.")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        case .checking:
            ProgressView()
        case .unique(let d):
            Text("✓ Unique — solvable by logic (\(d.displayName)).")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(lightHex: 0x0C8F6C, darkHex: 0x34C89A))
        case .notUnique(let count):
            VStack(spacing: 6) {
                Text("⚠ Not unique — the clues match \(count)+ different pictures.")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color(lightHex: 0xB5651D, darkHex: 0xE0A45A))
                Text(ambiguous != nil
                     ? "The highlighted cell could be filled or empty under the same clues. Add or remove a filled cell near there — usually extending a run or breaking a symmetry — to pin the picture down. Save unlocks once there's exactly one solution."
                     : "Adjust the picture so the clues allow only one solution — Save unlocks then.")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private struct Analysis: Sendable {
        let verdict: Verdict
        let ambiguous: (Int, Int)?
    }

    /// Pure solver work; nonisolated async ⇒ runs off the main actor, so the
    /// UI stays responsive while big grids are checked.
    private nonisolated static func analyzeGrid(_ snapshot: [[Bool]]) async -> Analysis {
        let clues = cluesForGrid(snapshot)
        let count = countSolutionsDetailed(clues.rowClues, clues.colClues, limit: 2)
        let unique = count.count == 1 && !count.capped
        var amb: (Int, Int)?
        var tier = Difficulty.easy
        if unique {
            tier = gradeGrid(snapshot)
        } else {
            let sols = enumerateSolutions(clues.rowClues, clues.colClues, limit: 2)
            if sols.count >= 2 {
                outer: for r in 0..<sols[0].count {
                    for c in 0..<sols[0][r].count where sols[0][r][c] != sols[1][r][c] {
                        amb = (r, c)
                        break outer
                    }
                }
            }
        }
        return Analysis(verdict: unique ? .unique(tier) : .notUnique(count.count), ambiguous: amb)
    }

    private func analyze() {
        guard filledCount > 0 else {
            verdict = .empty
            ambiguous = nil
            return
        }
        verdict = .checking
        let snapshot = solution
        Task {
            let result = await Self.analyzeGrid(snapshot)
            guard snapshot == solution else { return } // stale check
            verdict = result.verdict
            ambiguous = result.ambiguous
        }
    }

    private func save() {
        guard isUnique else { return }
        let id = editID ?? "u-\(UUID().uuidString.prefix(8))"
        app.store.saveUserPuzzle(StoredPuzzle(id: id, title: title.isEmpty ? "My Puzzle" : title, solution: solution))
        dismiss() // back home, like the web app — no accidental duplicate saves
    }
}
