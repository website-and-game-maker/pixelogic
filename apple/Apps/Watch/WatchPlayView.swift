// The play screen: the same compact board + one giant mode toggle, now with a
// scene-aware elapsed timer driven by ClueweaveKit's GameSession. The session is
// paused whenever the app leaves .active (Control Center, notifications, wrist
// down, app switch) and resumed when it returns, so ambient time off-screen
// never inflates the solve time shown on the win view.

import SwiftUI
import ClueweaveKit

#if canImport(WatchKit)
import WatchKit
#endif

struct WatchPlayView: View {
    let puzzle: Puzzle
    @ObservedObject var progress: WatchProgress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("clueweave.watch.showTimer") private var showTimer = true
    @AppStorage("clueweave.watch.haptics") private var haptics = true

    @State private var session: GameSession
    @State private var marks: Grid
    @State private var crossMode = false
    @State private var won = false
    @State private var elapsedMs = 0
    @State private var finalMs = 0

    // A lightweight repeating tick to refresh the on-screen clock while playing.
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(puzzle: Puzzle, progress: WatchProgress) {
        self.puzzle = puzzle
        self.progress = progress
        let s = GameSession(puzzle: puzzle)
        _session = State(initialValue: s)
        _marks = State(initialValue: s.marks)
    }

    var body: some View {
        VStack(spacing: 6) {
            if showTimer && !won {
                Text(timeString(elapsedMs))
                    .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            WatchBoardView(puzzle: puzzle, marks: marks, won: won) { r, c in
                guard !won else { return }
                session.mode = crossMode ? .cross : .paint
                session.toggle(r, c)
                marks = session.marks
                playClick()
                if session.isSolved {
                    win()
                }
            }

            if won {
                VStack(spacing: 6) {
                    Label("Solved \(puzzle.title)!", systemImage: "checkmark.seal.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(WatchPalette.cellFill)
                    Text("Time \(timeString(finalMs))")
                        .font(.system(.caption2, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .tint(WatchPalette.cellFill)
                }
            } else {
                // One giant mode toggle — the only control on the wrist.
                Button {
                    crossMode.toggle()
                    playClick()
                } label: {
                    Label(crossMode ? "Crossing" : "Painting", systemImage: crossMode ? "xmark" : "paintbrush.fill")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                }
                .tint(crossMode ? .gray : WatchPalette.cellFill)
            }
        }
        .navigationTitle(puzzle.title)
        .onAppear {
            // Begin timing as play opens; only resume if we are actually active.
            if scenePhase == .active { session.start() }
        }
        .onReceive(tick) { _ in
            guard !won else { return }
            elapsedMs = session.elapsedMs
        }
        .onChange(of: scenePhase) { phase in
            guard !won else { return }
            switch phase {
            case .active:
                session.start()
            default:
                // .inactive / .background: wrist down, Control Center, app switch.
                session.pause()
                elapsedMs = session.elapsedMs
            }
        }
    }

    private func win() {
        session.pause()
        finalMs = session.elapsedMs
        elapsedMs = finalMs
        won = true
        progress.markCompleted(puzzle.id)
        playSuccess()
    }

    private func timeString(_ ms: Int) -> String {
        let total = ms / 1000
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func playClick() {
        guard haptics else { return }
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    private func playSuccess() {
        guard haptics else { return }
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
}

/// Compact board renderer: clue rails + tappable cells, tuned for 40–45 mm.
struct WatchBoardView: View {
    let puzzle: Puzzle
    let marks: Grid
    let won: Bool
    let onTap: (Int, Int) -> Void

    var body: some View {
        GeometryReader { geo in
            // Rails sized independently: row clues take width, column clues
            // take height (a board can have deep column stacks but short rows).
            let rowSpan: CGFloat = 0.62 * CGFloat(max(1, puzzle.rowClues.map(\.count).max() ?? 1))
            let colSpan: CGFloat = 0.62 * CGFloat(max(1, puzzle.colClues.map(\.count).max() ?? 1))
            let cell = min(
                geo.size.width / (CGFloat(puzzle.width) + rowSpan),
                geo.size.height / (CGFloat(puzzle.height) + colSpan)
            )
            let ox = rowSpan * cell
            let oy = colSpan * cell

            ZStack(alignment: .topLeading) {
                // Clue rails
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

                // Cells
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
        Button {
            onTap(r, c)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(mark == .filled ? WatchPalette.cellFill : WatchPalette.cellEmpty)
                if mark == .empty {
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(WatchPalette.cellCross)
                }
            }
            .frame(width: size - 1.5, height: size - 1.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Row \(r + 1) column \(c + 1)\(mark == .filled ? ", filled" : mark == .empty ? ", crossed" : "")")
    }
}
