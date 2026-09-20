// The play screen: header chips, board, assist toolbar with live penalty
// meter, post-solve bar, symmetry strip, and the win sheet — a direct
// translation of the web app's play view.

import SwiftUI
import ClueweaveKit

struct PlayView: View {
    @StateObject private var vm: PlayViewModel
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("clueweave.ios.highVisibility") private var highVisibility = false
    @State private var showSmartPrompt = false
    @State private var smartTarget: Recommendation?
    @State private var sheenOffset: CGFloat = -44
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    highVisibility: highVisibility,
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

                // Level-to-level browsing lives at the very bottom, away from
                // the solving tools.
                if vm.isLibrary, curriculumPosition != nil {
                    puzzleNav
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
            ToolbarItem(placement: .navigationBarTrailing) {
                if vm.isLibrary, curriculumPosition != nil { smartNextButton }
            }
        }
        .sheet(isPresented: $vm.showWinSheet) { winSheet }
        .sheet(isPresented: $showSmartPrompt) {
            if let smartTarget { smartPromptSheet(smartTarget) }
        }
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
        }
    }

    // MARK: - Navigation (docs/progression-model.md §6)
    // Two deliberately different affordances: the bottom strip walks curriculum
    // order — predictable, never wrapping, greyed at the ends, and it never
    // consults or mutates the model; the sheened → in the toolbar asks the
    // progression model what suits you.

    private var curriculum: [Puzzle] { curriculumOrder(library) }
    private var curriculumPosition: Int? { curriculumIndex(library, id: vm.puzzle.id) }

    private var puzzleNav: some View {
        HStack {
            navArrow("chevron.left", label: "Previous puzzle", title: "Previous", offset: -1)
            Spacer(minLength: 8)
            if let pos = curriculumPosition {
                Text("\(pos + 1) of \(curriculum.count) · \(vm.puzzle.difficulty.displayName)")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            navArrow("chevron.right", label: "Next puzzle", title: "Next", offset: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.lineMajor).frame(height: 2).opacity(0.5)
        }
    }

    private func navArrow(_ icon: String, label: String, title: String, offset: Int) -> some View {
        let target = curriculumNeighbour(library, id: vm.puzzle.id, offset: offset)
        return Button {
            if let target { app.replaceTop(with: .play(target)) }
        } label: {
            HStack(spacing: 5) {
                if offset < 0 { Image(systemName: icon) }
                Text(title)
                if offset > 0 { Image(systemName: icon) }
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.lineMajor, lineWidth: 2))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        // Greyed, not hidden — the end of the run should be visible, not mysterious.
        .disabled(target == nil)
        .opacity(target == nil ? 0.38 : 1)
        .accessibilityLabel(label)
    }

    /// The smart-next arrow. Sheened while it is actually being smart; losing the
    /// sheen is the visible signal that it has become an ordinary next button.
    ///
    /// The shine sweeps once when the view settles, not on a loop — a permanent
    /// shimmer reads as a spinner and pulls the eye off the board for the whole
    /// solve. Matches the web app's `.sheen-intro` behaviour.
    private var smartNextButton: some View {
        Button {
            pressSmartNext()
        } label: {
            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .black))
                .frame(width: 34, height: 34)
                .foregroundStyle(smartOn ? .white : Theme.ink)
                .background(
                    Circle().fill(
                        smartOn
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Theme.primary, Theme.accent],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Theme.surface))
                )
                .overlay {
                    if smartOn {
                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.35),
                                        .init(color: .white.opacity(0.75), location: 0.5),
                                        .init(color: .clear, location: 0.65),
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .offset(x: sheenOffset)
                            .clipShape(Circle())
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    Circle().strokeBorder(smartOn ? Color.clear : Theme.lineMajor, lineWidth: 1.5)
                )
                .shadow(color: smartOn ? Theme.primary.opacity(0.45) : .clear, radius: 6, y: 3)
        }
        .accessibilityLabel(smartOn ? "Recommended next puzzle" : "Next puzzle")
        .onAppear(perform: playSheenOnce)
    }

    private func playSheenOnce() {
        guard smartOn, !reduceMotion else { return }
        sheenOffset = -44
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 1.05)) { sheenOffset = 44 }
        }
    }

    private var smartOn: Bool { app.store.settings.progression.smartNext }

    private func pressSmartNext() {
        guard let target = smartNextTarget(
            app.store.progression,
            currentPuzzleID: vm.puzzle.id,
            app.store.settings.progression,
            library,
            app.store.data.completed,
            app.store.data.bestScores
        ) else { return }
        // Each press counts toward the spam guard; any finished attempt clears it.
        app.noteSmartNextUse()
        if shouldPromptSmartNext(app.store.progression, app.store.settings.progression) {
            smartTarget = target
            showSmartPrompt = true
        } else {
            app.replaceTop(with: .play(target.puzzleID))
        }
    }

    /// On the first few uses, explain the pick and offer to turn the sheen off.
    private func smartPromptSheet(_ target: Recommendation) -> some View {
        let pick = library.first { $0.id == target.puzzleID }
        return VStack(spacing: 14) {
            Text("Picked for you")
                .font(.system(.title2, design: .rounded, weight: .black))
            HStack(spacing: 8) {
                Text(pick?.title ?? "Next puzzle")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                DifficultyChip(difficulty: target.tier)
            }
            Text(target.reason)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.primaryDeep)
            Text("This arrow picks your next puzzle from how you're going — moving you up a level when you solve quickly, and easing off when you keep getting stuck. You can change this any time in Settings.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            VStack(spacing: 10) {
                Button("Keep choosing for me") { answerSmartPrompt(keepSmart: true, target: target) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryDeep)
                Button("Just go in order") { answerSmartPrompt(keepSmart: false, target: target) }
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private func answerSmartPrompt(keepSmart: Bool, target: Recommendation) {
        if !keepSmart { app.setSmartNext(false) }
        app.markSmartNextPrompted()
        showSmartPrompt = false
        app.replaceTop(with: .play(target.puzzleID))
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
                if vm.isLibrary || vm.puzzle.id.hasPrefix("u-") || vm.puzzle.id.hasPrefix("g-") { // drafts have no route
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
                // Follows the progression model, so a string of solves walks
                // forward through the curriculum instead of looping back to an
                // Easy the way raw library order used to.
                Button {
                    if let target = smartNextTarget(
                        app.store.progression,
                        currentPuzzleID: vm.puzzle.id,
                        app.store.settings.progression,
                        library,
                        app.store.data.completed,
                        app.store.data.bestScores
                    ) {
                        app.replaceTop(with: .play(target.puzzleID))
                    } else {
                        dismiss()
                    }
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
                .foregroundStyle(Theme.symmetryInk)
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
