// Home: brand, tagline, laurel Clueweave Score, actions, tier sections with
// score/time cards + badge trait chips, My Puzzles with manage mode —
// the web menu, translated to an adaptive iPhone/iPad grid.

import SwiftUI
import UIKit
import ClueweaveKit

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var managing = false
    @State private var selectedCustoms: Set<String> = []
    @State private var confirmDeleteAll = false
    @State private var showImport = false
    @State private var managingGenerated = false
    @State private var selectedGenerated: Set<String> = []

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
                generatedPuzzlesSection
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
                    .accessibilityLabel("About Clueweave")
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
                Text("Clueweave")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primaryDeep)
            }
            Text(taglineText)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkSoft)

            // Clueweave Score laurel (below the tagline, above the actions).
            // The laurel grows and gilds as the score climbs: a humble green
            // sprig for beginners, a fuller green branch, then bronze, silver,
            // and finally a full golden wreath for pros.
            let score = app.store.clueweaveScore
            let laurel = laurelTier(for: score)
            HStack(spacing: 12) {
                Image(systemName: "laurel.leading").resizable().scaledToFit().frame(height: laurel.height)
                    .foregroundStyle(laurel.tint)
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                    Text("/ 1600").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.inkSoft)
                    Text(scoreTitle(score).uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.primaryDeep)
                }
                Image(systemName: "laurel.trailing").resizable().scaledToFit().frame(height: laurel.height)
                    .foregroundStyle(laurel.tint)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surface).shadow(color: Theme.primaryDeep.opacity(0.12), radius: 10, y: 4))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Clueweave Score \(score) of 1600, \(scoreTitle(score))")

            HStack(spacing: 18) {
                ShareLink(item: URL(string: "https://website-and-game-maker.github.io/clueweave/")!, message: Text(scoreShareText)) {
                    Label("Share score", systemImage: "square.and.arrow.up")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                }
                Button { showImport = true } label: {
                    Label("Import a puzzle", systemImage: "square.and.arrow.down")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                }
                .accessibilityHint("Paste a shared Clueweave link to add the puzzle")
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
                if let rec = recommendation,
                   let pick = library.first(where: { $0.id == rec.puzzleID }) {
                    Button {
                        app.path.append(Route.play(rec.puzzleID))
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Recommended puzzle", systemImage: "target")
                                .font(.system(.caption2, design: .rounded, weight: .black))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.inkSoft)
                            HStack(spacing: 6) {
                                Text(pick.title)
                                    .font(.system(.subheadline, design: .rounded, weight: .black))
                                    .foregroundStyle(Theme.ink)
                                DifficultyChip(difficulty: pick.difficulty)
                            }
                            Text(rec.reason)
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.primaryDeep)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Theme.primary.opacity(0.35), lineWidth: 2))
                        )
                    }
                    .accessibilityLabel(
                        "Recommended puzzle: \(pick.title), \(pick.difficulty.displayName). \(rec.reason)")
                }
            }
            NavigationLink(value: Route.generator) {
                Label("Generate a puzzle", systemImage: "wand.and.stars")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.accentSoft))
                    .foregroundStyle(Theme.primaryDeep)
            }
        }
    }

    private var taglineText: String {
        let done = library.filter { app.store.isCompleted($0.id) }.count
        return done > 0 ? "\(done) of \(library.count) solved" : "Pick a puzzle and deduce the hidden picture from the number clues."
    }

    private var scoreShareText: String {
        let score = app.store.clueweaveScore
        let solved = library.filter { app.store.isCompleted($0.id) }.count
        let reset = app.store.wasProgressReset ? " (progress was reset at least once)" : ""
        return "My Clueweave Score is \(score)/1600 — \(scoreTitle(score)) (\(solved)/\(library.count) solved)\(reset). ▦ Can you beat it?"
    }

    /// The laurel that flanks the score, by tier. It grows and gilds as the
    /// Clueweave Score climbs; the first upgrade arrives after only a little
    /// play. Thresholds are deliberately easy to tune.
    ///
    /// This was five bitmap imagesets until the licensing pass: that art was
    /// rasterized from the system emoji font, which may not be redistributed
    /// inside an app bundle. It is now the SF Symbol laurel — shipped by the OS
    /// and licensed for in-app use — tinted and sized per tier instead.
    private func laurelTier(for score: Int) -> (tint: Color, height: CGFloat) {
        switch score {
        case ..<30:  return (Theme.primary, 30)      // Beginner — a humble sprig
        case ..<120: return (Theme.primaryDeep, 42)  // first upgrade — arrives soon
        case ..<350: return (Theme.bronze, 50)
        case ..<800: return (Theme.silver, 58)
        default:     return (Theme.gold, 68)         // Pro — the full gilded wreath
        }
    }

    /// The progression model's pick, with its reasoning. Replaces the old random
    /// "Surprise me" — this names its choice and says why, so the suggestion is
    /// legible rather than a dice roll. See docs/progression-model.md §5.
    private var recommendation: Recommendation? {
        recommend(
            app.store.progression,
            library,
            app.store.data.completed,
            app.store.data.bestScores
        )
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
                    Button { app.path.append(Route.playCustom(stored.id)) } label: { Label("Play", systemImage: "play.fill") }
                    NavigationLink(value: Route.editor(stored.id)) { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { app.deleteUserPuzzles(ids: [stored.id]) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var generatedPuzzlesSection: some View {
        let gens = app.store.generatedPuzzles
        if !gens.isEmpty {
            section("Generated") {
                HStack {
                    Button(managingGenerated ? "Done" : "Manage") { managingGenerated.toggle(); selectedGenerated = [] }
                        .font(.system(.footnote, design: .rounded, weight: .heavy))
                    if managingGenerated {
                        Button("Delete selected", role: .destructive) {
                            app.deleteGenerated(ids: selectedGenerated)
                            selectedGenerated = []
                        }
                        .disabled(selectedGenerated.isEmpty)
                    }
                    Spacer()
                }
                .font(.system(.footnote, design: .rounded, weight: .bold))

                // Grade each stored puzzle once (gradeGrid runs the solver), then
                // group by the engine's verdict — like the main library's divisions.
                let graded = gens.map { (stored: $0, puzzle: $0.asPuzzle) }
                let byTier = Dictionary(grouping: graded, by: { $0.puzzle.difficulty })
                ForEach(Difficulty.ordered, id: \.self) { tier in
                    if let tierGens = byTier[tier], !tierGens.isEmpty {
                        HStack(spacing: 8) {
                            DifficultyChip(difficulty: tier)
                            Text("\(tierGens.count)")
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .padding(.top, 2)
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(tierGens, id: \.stored.id) { item in
                                generatedCard(item.stored, puzzle: item.puzzle)
                            }
                        }
                    }
                }
            }
        }
    }

    private func generatedCard(_ stored: StoredPuzzle, puzzle p: Puzzle) -> some View {
        Group {
            if managingGenerated {
                Button {
                    if selectedGenerated.contains(stored.id) { selectedGenerated.remove(stored.id) } else { selectedGenerated.insert(stored.id) }
                } label: {
                    PuzzleCard(puzzle: p, store: app.store, selected: selectedGenerated.contains(stored.id))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedGenerated.contains(stored.id) ? "Deselect \(p.title)" : "Select \(p.title)")
            } else {
                NavigationLink(value: Route.playGenerated(stored.id)) {
                    PuzzleCard(puzzle: p, store: app.store)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { app.path.append(Route.playGenerated(stored.id)) } label: { Label("Play", systemImage: "play.fill") }
                    ShareLink(item: webShareURL(forToken: encodePuzzle(stored.solution, title: stored.title))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { app.deleteGenerated(ids: [stored.id]) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Text("Every puzzle is provably solvable by logic alone — no guessing required.")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            // An understated, website-style privacy link at the very bottom —
            // plain system text, kept deliberately out of the way. (The old
            // "About" link here was redundant with the toolbar info button.)
            NavigationLink(value: Route.privacy) {
                Text("Privacy Policy")
                    .font(.footnote)
                    .underline()
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }
}

/// A library/custom puzzle card: score pill top-left, best time top-right,
/// title, then difficulty + badge trait chips. The whole card is the single
/// tap target that plays the puzzle; the badge chips are non-clickable
/// indicators that wrap onto extra lines when several apply.
struct PuzzleCard: View {
    let puzzle: Puzzle
    let store: PlayerStore
    var selected = false

    private var badges: [Badge] {
        puzzleBadges(solution: puzzle.solution, named: puzzle.named)
    }

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
            FlowLayout(spacing: 4, lineSpacing: 6) {
                DifficultyChip(difficulty: puzzle.difficulty)
                ForEach(badges, id: \.key) {
                    BadgeChipView(badge: $0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Extra breathing room when several badges stack, so the chips
            // aren't cramped and the card stays comfortable to tap.
            .padding(.bottom, badges.count >= 2 ? 4 : 0)
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
/// clueweave:// link, or a bare token — the puzzle lives inside the link.
struct ImportPuzzleView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var errorText: String?
    @State private var checking = false
    @State private var work: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste a Clueweave link or code", text: $input, axis: .vertical)
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
                    Text("Works with links shared from Clueweave on the web or on another device — the whole puzzle is encoded in the link itself. Nothing is downloaded.")
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
                Section {
                    Button {
                        importNow()
                    } label: {
                        if checking {
                            HStack(spacing: 8) { ProgressView(); Text("Checking the puzzle…") }
                        } else {
                            Text("Import puzzle")
                        }
                    }
                    .disabled(checking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Import a puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onDisappear { work?.cancel() } // a cancelled sheet must not still import
    }

    private func importNow() {
        errorText = nil
        // A library link (web #/play/<id>) opens the built-in puzzle directly.
        if let libID = libraryShareID(fromUserInput: input), ClueweaveKit.puzzle(withID: libID) != nil {
            open(.play(libID))
            return
        }
        guard let token = shareToken(fromUserInput: input),
              let decoded = try? decodePuzzle(token) else {
            errorText = "That doesn\u{2019}t look like a Clueweave puzzle link. Copy the whole link (it contains \u{201C}/p/\u{201D}) and try again."
            return
        }
        checking = true
        work = Task {
            let playable = await validateSharedSolution(decoded.solution)
            if Task.isCancelled { return } // sheet was dismissed mid-check
            checking = false
            guard playable else {
                errorText = "This shared puzzle doesn\u{2019}t have a single logical solution, so it can\u{2019}t be played here."
                return
            }
            let id = app.importPuzzle(title: decoded.title, solution: decoded.solution)
            open(.playCustom(id))
        }
    }

    /// Push the route, THEN dismiss — appending after dismiss races the sheet
    /// teardown on iOS 16 and the push is silently dropped.
    private func open(_ route: Route) {
        app.path.append(route)
        dismiss()
    }
}
