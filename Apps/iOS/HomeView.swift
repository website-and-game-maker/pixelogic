// Home: brand, tagline, laurel Pixelogic Score, actions, tier sections with
// score/time cards + clickable badge chips, My Puzzles with manage mode —
// the web menu, translated to an adaptive iPhone/iPad grid.

import SwiftUI
import UIKit
import PixelogicKit

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var managing = false
    @State private var selectedCustoms: Set<String> = []
    @State private var confirmDeleteAll = false
    @State private var showImport = false

    private let columns = [GridItem(.adaptive(minimum: 165), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                ForEach(Difficulty.ordered, id: \.self) { tier in
                    let tierPuzzles = puzzles(in: tier)
                    if !tierPuzzles.isEmpty {
                        section(tier.displayName) {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(tierPuzzles) { p in
                                    NavigationLink(value: Route.play(p.id)) {
                                        PuzzleCard(puzzle: p, store: app.store)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                myPuzzles
                footer
            }
            .padding()
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("")
        .sheet(isPresented: $showImport) {
            ImportPuzzleView().environmentObject(app)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { app.showTutorial = true } label: { Image(systemName: "graduationcap") }
                    .accessibilityLabel("How to play tutorial")
                NavigationLink(value: Route.about) { Image(systemName: "info.circle") }
                    .accessibilityLabel("About Pixelogic")
                Button { app.showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("▦")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.brandGradient))
                Text("Pixelogic")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primaryDeep)
            }
            Text(taglineText)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkSoft)

            // Pixelogic Score laurel (below the tagline, above the actions)
            let score = app.store.pixelogicScore
            HStack(spacing: 12) {
                Text("🌿").font(.title)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                    Text("/ 1600").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.inkSoft)
                    Text(scoreTitle(score).uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.primaryDeep)
                }
                Text("🌿").font(.title).scaleEffect(x: -1)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surface).shadow(color: Theme.primaryDeep.opacity(0.12), radius: 10, y: 4))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pixelogic Score \(score) of 1600, \(scoreTitle(score))")

            HStack(spacing: 18) {
                ShareLink(item: URL(string: "https://website-and-game-maker.github.io/pixelogic/")!, message: Text(scoreShareText)) {
                    Label("Share score", systemImage: "square.and.arrow.up")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                }
                Button { showImport = true } label: {
                    Label("Import a puzzle", systemImage: "square.and.arrow.down")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                }
                .accessibilityHint("Paste a shared Pixelogic link to add the puzzle")
            }

            HStack(spacing: 12) {
                NavigationLink(value: Route.editor(nil)) {
                    Label("Create your own", systemImage: "pencil")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.brandGradient))
                        .foregroundStyle(.white)
                }
                Button {
                    app.path.append(Route.play(surpriseID()))
                } label: {
                    Label("Surprise me", systemImage: "die.face.5")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.surface))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private var taglineText: String {
        let done = library.filter { app.store.isCompleted($0.id) }.count
        return done > 0 ? "\(done) of \(library.count) solved" : "Pick a puzzle and deduce the hidden picture from the number clues."
    }

    private var scoreShareText: String {
        let score = app.store.pixelogicScore
        let solved = library.filter { app.store.isCompleted($0.id) }.count
        let reset = app.store.wasProgressReset ? " (progress was reset at least once)" : ""
        return "My Pixelogic Score is \(score)/1600 — \(scoreTitle(score)) (\(solved)/\(library.count) solved)\(reset). ▦ Can you beat it?"
    }

    /// Adaptive Surprise me: a random unsolved puzzle from the frontier tier.
    private func surpriseID() -> String {
        let completed = Set(library.filter { app.store.isCompleted($0.id) }.map(\.id))
        var frontier = 0
        for (i, tier) in Difficulty.ordered.enumerated()
        where library.contains(where: { $0.difficulty == tier && completed.contains($0.id) }) {
            frontier = i
        }
        let tierList = puzzles(in: Difficulty.ordered[frontier])
        let cleared = !tierList.isEmpty && tierList.allSatisfy { completed.contains($0.id) }
        let start = cleared ? min(frontier + 1, Difficulty.ordered.count - 1) : frontier
        for i in start..<Difficulty.ordered.count {
            let pool = puzzles(in: Difficulty.ordered[i]).filter { !completed.contains($0.id) }
            if let pick = pool.randomElement() { return pick.id }
        }
        return (library.filter { !completed.contains($0.id) }.randomElement() ?? library[0]).id
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(Theme.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var myPuzzles: some View {
        let customs = app.store.userPuzzles
        if !customs.isEmpty {
            section("My Puzzles") {
                HStack {
                    Button(managing ? "Done" : "Manage") { managing.toggle(); selectedCustoms = [] }
                        .font(.system(.footnote, design: .rounded, weight: .heavy))
                    if managing {
                        Button("Delete selected", role: .destructive) {
                            app.deleteUserPuzzles(ids: selectedCustoms)
                            selectedCustoms = []
                        }
                        .disabled(selectedCustoms.isEmpty)
                        Button("Delete all", role: .destructive) { confirmDeleteAll = true }
                    }
                    Spacer()
                }
                .font(.system(.footnote, design: .rounded, weight: .bold))
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(customs) { stored in
                        customCard(stored)
                    }
                }
            }
            .confirmationDialog("Delete ALL of your puzzles?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) {
                    app.deleteUserPuzzles(ids: Set(customs.map(\.id)))
                    managing = false
                }
            }
        }
    }

    private func customCard(_ stored: StoredPuzzle) -> some View {
        let p = stored.asPuzzle
        return Group {
            if managing {
                Button {
                    if selectedCustoms.contains(stored.id) { selectedCustoms.remove(stored.id) } else { selectedCustoms.insert(stored.id) }
                } label: {
                    PuzzleCard(puzzle: p, store: app.store, selected: selectedCustoms.contains(stored.id))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedCustoms.contains(stored.id) ? "Deselect \(p.title)" : "Select \(p.title)")
            } else {
                NavigationLink(value: Route.playCustom(stored.id)) {
                    PuzzleCard(puzzle: p, store: app.store)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    NavigationLink(value: Route.editor(stored.id)) { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { app.deleteUserPuzzles(ids: [stored.id]) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Every puzzle is provably solvable by logic alone — no guessing required.")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            NavigationLink(value: Route.about) {
                Text("ℹ About Pixelogic — scoring, difficulty & how it works")
                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.primaryDeep)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }
}

/// A library/custom puzzle card: score pill top-left, best time top-right,
/// title, then difficulty + badge chips.
struct PuzzleCard: View {
    let puzzle: Puzzle
    let store: PlayerStore
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let score = store.bestScore(for: puzzle.id) {
                    (Text("\(score)").font(.system(.body, design: .rounded, weight: .black))
                     + Text("/100").font(.system(size: 10, weight: .bold)))
                        .foregroundStyle(Theme.primaryDeep)
                } else {
                    Text("—").font(.system(.body, design: .rounded, weight: .black)).foregroundStyle(Theme.lineMajor)
                }
                Spacer()
                if let best = store.bestTime(for: puzzle.id) {
                    Label(TimeFormat.string(ms: best), systemImage: "stopwatch")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                } else if store.isCompleted(puzzle.id) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                }
            }
            Text(puzzle.title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 4) {
                DifficultyChip(difficulty: puzzle.difficulty)
                ForEach(puzzleBadges(solution: puzzle.solution, named: puzzle.named), id: \.key) {
                    BadgeChipView(badge: $0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(puzzle.width) × \(puzzle.height)")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .shadow(color: Theme.primaryDeep.opacity(0.08), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? Theme.primary : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Play \(puzzle.title), \(puzzle.difficulty.displayName)")
    }
}

/// Paste-to-import for shared puzzles: accepts the web link, the
/// pixelogic:// link, or a bare token — the puzzle lives inside the link.
struct ImportPuzzleView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste a Pixelogic link or code", text: $input, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.footnote, design: .monospaced))
                    Button {
                        if let s = UIPasteboard.general.string { input = s }
                    } label: {
                        Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                    }
                } footer: {
                    Text("Works with links shared from Pixelogic on the web or on another device — the whole puzzle is encoded in the link itself. Nothing is downloaded.")
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
                Section {
                    Button("Import puzzle") { importNow() }
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Import a puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func importNow() {
        guard let token = shareToken(fromUserInput: input),
              let decoded = try? decodePuzzle(token) else {
            errorText = "That doesn\u{2019}t look like a Pixelogic puzzle link. Copy the whole link (it contains \u{201C}/p/\u{201D}) and try again."
            return
        }
        let id = app.importPuzzle(title: decoded.title, solution: decoded.solution)
        dismiss()
        app.path.append(Route.playCustom(id))
    }
}
