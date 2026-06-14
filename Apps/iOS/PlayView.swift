// The play screen: header chips, board, assist toolbar with live penalty
// meter, post-solve bar, symmetry strip, and the win sheet — a direct
// translation of the web app's play view.

import SwiftUI
import PixelogicKit

struct PlayView: View {
    @StateObject private var vm: PlayViewModel
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(puzzle: Puzzle, isLibrary: Bool, store: PlayerStore) {
        _vm = StateObject(wrappedValue: PlayViewModel(puzzle: puzzle, isLibrary: isLibrary, store: store))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                BoardView(
                    puzzle: vm.puzzle,
                    marks: vm.marks,
                    clueStyle: vm.settings.clueStyle,
                    mistakeCheck: vm.settings.mistakeCheck,
                    onTouch: { r, c, drag in vm.touch(r, c, isDrag: drag) }
                )
                .padding(.horizontal, 12)

                if let banner = vm.banner {
                    Text(banner)
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if vm.postSolve {
                    postSolveBar
                } else {
                    controls
                }

                if let badge = vm.symmetricBadge {
                    symmetryStrip(badge)
                }
            }
            .padding(.vertical)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(vm.puzzle.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if vm.settings.showTimer {
                    Text(TimeFormat.string(ms: vm.elapsedMs))
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityLabel("Elapsed time")
                }
            }
        }
        .sheet(isPresented: $vm.showWinSheet) { winSheet }
        .onAppear { vm.setActive(true) }
        .onDisappear { vm.setActive(false); vm.persistNow() }
        .onChange(of: scenePhase) { phase in
            vm.setActive(phase == .active)
            if phase == .background { vm.persistNow() } // .inactive is transient — don't churn saves
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            // Chips wrap onto extra lines on narrow screens (iPhone SE) so
            // badges never overflow or clip; badge chips are non-clickable
            // trait indicators.
            FlowLayout(spacing: 6, lineSpacing: 6) {
                DifficultyChip(difficulty: vm.puzzle.difficulty)
                Chip(text: "\(vm.puzzle.width) × \(vm.puzzle.height)", bg: Theme.surface2, fg: Theme.inkSoft)
                ForEach(vm.badges, id: \.key) { BadgeChipView(badge: $0) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            if vm.isLibrary {
                HStack {
                    navArrow("chevron.left", label: "Previous puzzle", offset: -1)
                    Spacer()
                    navArrow("chevron.right", label: "Next puzzle", offset: 1)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func navArrow(_ icon: String, label: String, offset: Int) -> some View {
        Button {
            guard let idx = library.firstIndex(where: { $0.id == vm.puzzle.id }) else { return }
            let next = library[(idx + offset + library.count) % library.count]
            app.replaceTop(with: .play(next.id))
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .heavy))
                .padding(10)
                .background(Circle().fill(Theme.surface))
        }
        .accessibilityLabel(label)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $vm.mode) {
                Text("🖌 Paint").tag(GameSession.Mode.paint)
                Text("✕ Cross").tag(GameSession.Mode.cross)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            HStack(spacing: 10) {
                toolButton("arrow.uturn.backward", "Undo", disabled: !vm.canUndo) { vm.undo() }
                toolButton("arrow.uturn.forward", "Redo", disabled: !vm.canRedo) { vm.redo() }
                Spacer()
                Menu {
                    Button("Square −\(AssistTally.penaltyCheckSquare)\(vm.checkSquaresLeft.map { " (\($0) left)" } ?? "")") { vm.armCheckSquare() }
                    Button("Row & column −\(AssistTally.penaltyCheckLine)") { vm.armCheckLine() }
                    Button("Whole board −\(AssistTally.penaltyCheckBoard)") { vm.checkBoard() }
                } label: {
                    Label("Check", systemImage: "magnifyingglass")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                }
                toolButton("lightbulb", "Hint −\(AssistTally.penaltyHint)") { vm.hint() }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 14) {
                if vm.isLibrary || vm.puzzle.id.hasPrefix("u-") { // drafts have no route
                    Button {
                        vm.voidForWatchSolve() // voiding must not depend on gesture timing
                        app.path.append(Route.explainer(vm.puzzle.id))
                    } label: {
                        Label("Watch solve", systemImage: "brain")
                    }
                }
                Button("Fill out", role: .destructive) { vm.fillOut() }
                Button { vm.restart() } label: { Label("Restart", systemImage: "arrow.counterclockwise") }
            }
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.inkSoft)

            Text(meterText)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(vm.voided ? Theme.mistake : Theme.inkSoft)
        }
    }

    private var meterText: String {
        if vm.voided { return "⚠ No score this attempt (Fill out / Watch solve used) — Restart for a clean run." }
        return vm.penalty > 0 ? "Assists used: −\(vm.penalty) to your score" : "Clean solve — no assists yet"
    }

    private func toolButton(_ icon: String, _ label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
        }
        .disabled(disabled)
    }

    private var postSolveBar: some View {
        HStack(spacing: 12) {
            if !vm.filledOut {
                ShareLink(item: vm.shareURL, message: Text(vm.shareText)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            if vm.isLibrary {
                Button {
                    guard let idx = library.firstIndex(where: { $0.id == vm.puzzle.id }) else { return }
                    app.replaceTop(with: .play(library[(idx + 1) % library.count].id))
                } label: {
                    Label("Next puzzle", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryDeep)
            }
            Button("Play again") { vm.restart() }
            Button("Menu") { dismiss() }
        }
        .font(.system(.subheadline, design: .rounded, weight: .heavy))
    }

    private func symmetryStrip(_ badge: Badge) -> some View {
        NavigationLink(value: Route.badge(BadgeKey.symmetric)) {
            Text("\(badge.label) — its halves mirror each other, so each deduction does double duty.")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(Color(hex: 0x0B7E89))
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.symmetrySoft))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.symmetry, lineWidth: 1.5))
                .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private var winSheet: some View {
        VStack(spacing: 14) {
            Text(vm.filledOut ? "🧩" : "🎉").font(.system(size: 56))
            Text(vm.filledOut ? "Filled out" : "Solved!")
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(Theme.ink)
            if let score = vm.finalScore {
                Text("Score: \(score)/100\(vm.isNewBestScore ? " · best yet!" : "")")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.primaryDeep)
            }
            if vm.filledOut {
                Text("No score — you used Fill out.")
                    .foregroundStyle(Theme.inkSoft)
            } else if let best = vm.bestTimeMs {
                Text(vm.isNewBestTime
                     ? "🏅 New best time — \(TimeFormat.string(ms: vm.elapsedMs))"
                     : "Time \(TimeFormat.string(ms: vm.elapsedMs)) · Best \(TimeFormat.string(ms: best))")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            if let note = vm.puzzle.note {
                Text("ℹ \(note)")
                    .font(.system(.footnote, design: .rounded))
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                if !vm.filledOut {
                    ShareLink(item: vm.shareURL, message: Text(vm.shareText)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Admire the picture") {
                    vm.showWinSheet = false
                    vm.postSolve = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryDeep)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .presentationDetents([.medium])
        .onDisappear { vm.postSolve = true }
    }
}
