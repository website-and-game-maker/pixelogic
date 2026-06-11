// Settings, About, badge filter, and watch-solve screens.

import SwiftUI
import PixelogicKit

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Playing") {
                    Toggle("Auto-check mistakes", isOn: binding(\.mistakeCheck))
                    Toggle("Show timer", isOn: binding(\.showTimer))
                    Toggle("Auto-cross finished lines", isOn: binding(\.autoCross))
                    Picker("Completed clues", selection: binding(\.clueStyle)) {
                        ForEach(ClueStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Privacy") {
                    Link(destination: URL(string: "https://website-and-game-maker.github.io/pixelogic/#/about")!) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    Text("Pixelogic collects nothing. Your progress, scores and creations stay on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                } header: {
                    Text("Danger zone")
                } footer: {
                    Text("Clears solved puzzles, scores and best times. Your custom puzzles are kept, and a shared Pixelogic Score will disclose the reset.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Erase all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Yes, reset", role: .destructive) {
                    app.store.resetProgress()
                    app.objectWillChange.send()
                }
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<GameSettings, T>) -> Binding<T> {
        Binding(
            get: { app.store.settings[keyPath: keyPath] },
            set: { newValue in
                var s = app.store.settings
                s[keyPath: keyPath] = newValue
                app.store.settings = s
                app.objectWillChange.send()
            }
        )
    }
}

// MARK: - Badge filter

struct BadgeListView: View {
    let key: BadgeKey
    @EnvironmentObject private var app: AppModel
    private let columns = [GridItem(.adaptive(minimum: 165), spacing: 14)]

    var body: some View {
        let matches = library.filter { p in
            puzzleBadges(solution: p.solution, named: p.named).contains { $0.key == key }
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(key.blurb)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(key.multiplier < 1
                     ? "Because they're a little easier, \(key.name) puzzles count slightly less toward your Pixelogic Score."
                     : "Because they're harder, \(key.name) puzzles count for more in your Pixelogic Score.")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                ForEach(Difficulty.ordered, id: \.self) { tier in
                    let tierMatches = matches.filter { $0.difficulty == tier }
                    if !tierMatches.isEmpty { // hide empty tiers
                        HStack(spacing: 8) {
                            DifficultyChip(difficulty: tier)
                            Text("\(tierMatches.count)")
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(tierMatches) { p in
                                NavigationLink(value: Route.play(p.id)) {
                                    PuzzleCard(puzzle: p, store: app.store)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("\(key.icon) \(key.name) puzzles")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About

struct AboutView: View {
    private struct Section: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let sections: [Section] = [
        Section(icon: "square.grid.3x3.fill", title: "What is Pixelogic?",
                body: "Pixelogic is a nonogram (picross) game: the numbers along each row and column describe the runs of filled cells in that line, and from those clues alone you can reconstruct a hidden pixel picture. Our promise is simple: every puzzle can be finished with certain logic — never a guess."),
        Section(icon: "brain.head.profile", title: "How do we know a puzzle never needs guessing?",
                body: "Before a puzzle ships, the game plays it against itself — with a twist: the built-in solver is only allowed moves a careful human could make. It examines one line at a time and asks: across every possible way this clue could fit, which cells come out the same? Those cells are forced, and it marks them and repeats. Separately, a second check tries to find two different pictures matching the same clues; if it can, the puzzle is rejected. Hints replay this same chain of forced moves — that's why a hint can always tell you why a cell is certain."),
        Section(icon: "thermometer.medium", title: "How is difficulty decided?",
                body: "Not by size! Difficulty measures how hard the solver has to think. If single-line reasoning cracks the puzzle in a sweep or two, it's Easy; more sweeps feeding into each other make Medium and Hard. Some puzzles stall every line — the only way forward is a what-if: assume a cell, watch the assumption collapse into contradiction, and conclude the opposite. Those are Extra Hard, and the ones demanding it over and over across long lines are MAX. Symmetric, patterned, or tell-tale-named pictures confess their secrets early, so the grader caps or discounts them."),
        Section(icon: "laurel.leading", title: "The Pixelogic Score",
                body: "Your Pixelogic Score (0–1,600) measures mastery of the whole library. Each puzzle contributes its best result, weighted by tier — a MAX puzzle moves your score about a dozen Easies' worth. Per puzzle you score out of 100: solve at par or faster with no help for a perfect score; assists subtract by how much they reveal, and auto-completing scores zero. If you ever reset your progress, your shared score says so."),
        Section(icon: "link", title: "How do shared puzzles travel without a server?",
                body: "There's no backend at all. When you share a custom puzzle, the picture itself is encoded into the link — the URL is the puzzle. Your progress, scores and creations live on your device and never leave it."),
        Section(icon: "hand.raised.fill", title: "Your privacy",
                body: "Pixelogic collects no data whatsoever: no accounts, no analytics, no tracking, no network calls. Progress, scores, settings and your custom puzzles are stored only on this device, and deleting the app deletes them."),
        Section(icon: "sparkles", title: "Built entirely with AI",
                body: "Every line of Pixelogic — the logic engine and its uniqueness prover, the difficulty grader, the scoring model, the puzzle art, the test suites, this very page — was designed and written by AI (Anthropic's Claude), steered by a human with opinions about how a logic game should feel."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(sections) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(s.title, systemImage: s.icon)
                            .font(.system(.headline, design: .rounded, weight: .black))
                            .foregroundStyle(Theme.ink)
                        Text(s.body)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.9))
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
                }
            }
            .padding()
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("About Pixelogic")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Watch solve (explainer)

struct ExplainerView: View {
    let puzzle: Puzzle
    @State private var steps: [Deduction] = []
    @State private var grid: Grid
    @State private var stepIndex = 0
    @State private var playing = false
    @State private var speed = 1.0
    @State private var timer: Timer?

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        _grid = State(initialValue: makeGrid(puzzle.height, puzzle.width))
    }

    var body: some View {
        VStack(spacing: 16) {
            BoardView(puzzle: puzzle, marks: grid, clueStyle: .grey, mistakeCheck: false, interactive: false)
                .padding(.horizontal)
            Text(stepIndex > 0 && stepIndex <= steps.count ? steps[stepIndex - 1].caption : "Press play to watch the logical solution unfold, one undeniable step at a time.")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(minHeight: 64)
                .padding(.horizontal)
            Text("\(stepIndex) / \(steps.count) steps")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 14) {
                Button { reset() } label: { Image(systemName: "arrow.counterclockwise") }
                Button { togglePlay() } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryDeep)
                Button { stepForward() } label: { Image(systemName: "forward.frame.fill") }
                Picker("Speed", selection: $speed) {
                    Text("0.5×").tag(0.5)
                    Text("1×").tag(1.0)
                    Text("2×").tag(2.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .onChange(of: speed) { _ in if playing { startTimer() } }
            }
        }
        .padding(.vertical)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Watch solve — \(puzzle.title)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            steps = solveByLogic(puzzle.rowClues, puzzle.colClues).steps
        }
        .onDisappear { timer?.invalidate() }
    }

    private func togglePlay() {
        playing.toggle()
        if playing { startTimer() } else { timer?.invalidate() }
    }

    private func startTimer() {
        timer?.invalidate()
        // Deliberately slow (1.6 s base) so each deduction can be read.
        timer = Timer.scheduledTimer(withTimeInterval: 1.6 / speed, repeats: true) { _ in
            Task { @MainActor in stepForward() }
        }
    }

    private func stepForward() {
        guard stepIndex < steps.count else {
            playing = false
            timer?.invalidate()
            return
        }
        for cell in steps[stepIndex].cells { grid[cell.r][cell.c] = cell.value }
        stepIndex += 1
    }

    private func reset() {
        playing = false
        timer?.invalidate()
        stepIndex = 0
        grid = makeGrid(puzzle.height, puzzle.width)
    }
}
