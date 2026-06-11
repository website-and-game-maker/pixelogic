// Pixelogic for Apple Watch — the "pocket set": every 5×5 puzzle, rethought
// for 5-second wrist sessions. See DESIGN.md for the rationale.

import SwiftUI
import PixelogicKit

@main
struct PixelogicWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
            }
        }
    }
}

/// Minimal wrist-local progress (completion only — no scores on the wrist).
@MainActor
final class WatchProgress: ObservableObject {
    @AppStorage("pixelogic.watch.completed") private var completedRaw = ""

    var completed: Set<String> {
        Set(completedRaw.split(separator: ",").map(String.init))
    }

    func markCompleted(_ id: String) {
        var set = completed
        set.insert(id)
        completedRaw = set.sorted().joined(separator: ",")
        objectWillChange.send()
    }
}

/// The wrist-sized library: every 5×5 (cells stay at/above the 7 mm touch minimum).
let watchLibrary: [Puzzle] = library.filter { $0.width == 5 && $0.height == 5 }

struct WatchHomeView: View {
    @StateObject private var progress = WatchProgress()

    var body: some View {
        List(watchLibrary) { p in
            NavigationLink {
                WatchPlayView(puzzle: p, progress: progress)
            } label: {
                HStack {
                    Image(systemName: progress.completed.contains(p.id) ? "checkmark.circle.fill" : "circle.dotted")
                        .foregroundStyle(progress.completed.contains(p.id) ? .teal : .secondary)
                    Text(p.title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
        .navigationTitle("Pixelogic")
        .overlay(alignment: .bottom) {
            let done = watchLibrary.filter { progress.completed.contains($0.id) }.count
            if done == watchLibrary.count {
                Text("Pocket set complete! 🌿")
                    .font(.footnote.bold())
                    .padding(6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

struct WatchPlayView: View {
    let puzzle: Puzzle
    @ObservedObject var progress: WatchProgress
    @Environment(\.dismiss) private var dismiss

    @State private var session: GameSession
    @State private var marks: Grid
    @State private var crossMode = false
    @State private var won = false

    init(puzzle: Puzzle, progress: WatchProgress) {
        self.puzzle = puzzle
        self.progress = progress
        let s = GameSession(puzzle: puzzle)
        _session = State(initialValue: s)
        _marks = State(initialValue: s.marks)
    }

    var body: some View {
        VStack(spacing: 6) {
            WatchBoardView(puzzle: puzzle, marks: marks, won: won) { r, c in
                guard !won else { return }
                session.mode = crossMode ? .cross : .paint
                session.toggle(r, c)
                marks = session.marks
                WKInterfaceDevice.current().play(.click)
                if session.isSolved {
                    won = true
                    progress.markCompleted(puzzle.id)
                    WKInterfaceDevice.current().play(.success)
                }
            }

            if won {
                Button {
                    dismiss()
                } label: {
                    Label("Solved \(puzzle.title)!", systemImage: "checkmark.seal.fill")
                        .font(.footnote.bold())
                }
                .tint(.teal)
            } else {
                // One giant mode toggle — the only control on the wrist.
                Button {
                    crossMode.toggle()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Label(crossMode ? "Crossing" : "Painting", systemImage: crossMode ? "xmark" : "paintbrush.fill")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                }
                .tint(crossMode ? .gray : .teal)
            }
        }
        .navigationTitle(puzzle.title)
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
            let clueSpan: CGFloat = 0.62 * CGFloat(max(1, puzzle.rowClues.map(\.count).max() ?? 1))
            let cell = min(
                geo.size.width / (CGFloat(puzzle.width) + clueSpan),
                geo.size.height / (CGFloat(puzzle.height) + clueSpan)
            )
            let ox = clueSpan * cell
            let oy = clueSpan * cell

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
                    .fill(mark == .filled ? Color.teal : Color.white.opacity(0.14))
                if mark == .empty {
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: size - 1.5, height: size - 1.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Row \(r + 1) column \(c + 1)\(mark == .filled ? ", filled" : mark == .empty ? ", crossed" : "")")
    }
}

#if canImport(WatchKit)
import WatchKit
#endif
