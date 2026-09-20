// Clueweave for iPhone & iPad — free, no ads, no accounts, fully on-device.

import SwiftUI
import ClueweaveKit

@MainActor
final class AppModel: ObservableObject {
    let store = PlayerStore()
    @Published var path = NavigationPath()
    @Published var showSettings = false
    @Published var showTutorial = false
    /// The card-based feature tour, shown once after the first-launch tutorial.
    @Published var showTour = false
    /// Surfaced when a shared link can't be opened (junk, or a non-unique puzzle).
    @Published var importError: String?

    /// Pop the current screen and push another (used by prev/next puzzle).
    func replaceTop(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    /// Store mutations the UI must observe go through these wrappers —
    /// PlayerStore itself is not observable.
    func deleteUserPuzzles(ids: Set<String>) {
        store.deleteUserPuzzles(ids: ids)
        objectWillChange.send()
    }

    @discardableResult
    func importPuzzle(title: String, solution: [[Bool]]) -> String {
        let id = store.importUserPuzzle(title: title, solution: solution)
        objectWillChange.send()
        return id
    }

    @discardableResult
    func saveGenerated(title: String, solution: [[Bool]]) -> String {
        let id = store.saveGeneratedPuzzle(title: title, solution: solution)
        objectWillChange.send()
        return id
    }

    func deleteGenerated(ids: Set<String>) {
        store.deleteGeneratedPuzzles(ids: ids)
        objectWillChange.send()
    }

    // MARK: - Progression (docs/progression-model.md)

    func noteSmartNextUse() {
        store.noteSmartNextUse()
        objectWillChange.send()
    }

    func markSmartNextPrompted() {
        store.markSmartNextPrompted()
        objectWillChange.send()
    }

    func setSmartNext(_ on: Bool) {
        var s = store.settings
        s.progression.smartNext = on
        store.settings = s
        objectWillChange.send()
    }

    func updateProgressionSettings(_ mutate: (inout ProgressionSettings) -> Void) {
        var s = store.settings
        mutate(&s.progression)
        store.settings = s
        objectWillChange.send()
    }

    func resetProgressionState() {
        store.progression = ProgressionState()
        objectWillChange.send()
    }

    /// Resolve a puzzle for routes that may point at library, custom, or generated art.
    func anyPuzzle(withID id: String) -> Puzzle? {
        ClueweaveKit.puzzle(withID: id)
            ?? store.userPuzzles.first(where: { $0.id == id })?.asPuzzle
            ?? store.generatedPuzzles.first(where: { $0.id == id })?.asPuzzle
    }
}

@main
struct ClueweaveApp: App {
    @StateObject private var app = AppModel()

    /// The rebrand renamed the app-name-prefixed `@AppStorage` keys. `PlayerStore`
    /// migrates the save blob itself; this picks up the loose UI preferences that
    /// live outside it, so nothing silently reverts to its default.
    init() {
        let defaults = UserDefaults.standard
        for suffix in ["highVisibility"] {
            let old = "pixelogic.ios.\(suffix)"
            let new = "clueweave.ios.\(suffix)"
            guard defaults.object(forKey: new) == nil,
                  let value = defaults.object(forKey: old) else { continue }
            defaults.set(value, forKey: new)
            defaults.removeObject(forKey: old)
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $app.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
            }
            .environmentObject(app)
            .tint(Theme.primaryDeep)
            // The hand-tuned baby-blue palette now ships LIGHT and DARK
            // adaptive variants (see Theme.swift), so the app follows the
            // system appearance instead of forcing one.
            .sheet(isPresented: $app.showSettings) {
                SettingsView().environmentObject(app)
            }
            .fullScreenCover(isPresented: $app.showTutorial, onDismiss: {
                // Right after the first-launch tutorial dismisses, hand off to the
                // feature tour — but only once, and never over a deep-linked puzzle.
                if !app.store.tourSeen && app.path.isEmpty { app.showTour = true }
            }) {
                TutorialView().environmentObject(app)
            }
            .fullScreenCover(isPresented: $app.showTour) {
                TourView().environmentObject(app)
            }
            .onAppear {
                // First-ever launch: show the tutorial before the menu — unless a
                // deep link has already pushed a puzzle (path non-empty).
                if !app.store.tutorialSeen && app.path.isEmpty { app.showTutorial = true }
                // Existing users who've seen the tutorial but predate the tour get
                // it once, on the menu only (never over a deep-linked puzzle).
                else if app.store.tutorialSeen && !app.store.tourSeen && app.path.isEmpty {
                    app.showTour = true
                }
            }
            .onOpenURL { url in
                openSharedPuzzle(url)
            }
            .alert("Couldn’t open that puzzle", isPresented: Binding(
                get: { app.importError != nil },
                set: { if !$0 { app.importError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(app.importError ?? "")
            }
        }
    }

    /// clueweave://p/<token> (and the web URL form) → validate, import & play.
    private func openSharedPuzzle(_ url: URL) {
        guard let token = shareToken(fromUserInput: url.absoluteString),
              let decoded = try? decodePuzzle(token) else {
            app.importError = "That link isn’t a Clueweave puzzle."
            return
        }
        Task {
            guard await validateSharedSolution(decoded.solution) else {
                // Leave any first-launch tutorial intact — a bad link shouldn't
                // silently swallow onboarding.
                app.importError = "This shared puzzle doesn’t have a single logical solution, so it can’t be played here."
                return
            }
            // Success: clear whatever's covering the stack, then open the puzzle.
            app.showTutorial = false
            app.showTour = false
            app.showSettings = false
            let id = app.importPuzzle(title: decoded.title, solution: decoded.solution)
            app.path = NavigationPath()
            app.path.append(Route.playCustom(id))
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .play(let id):
            if let p = puzzle(withID: id) {
                PlayView(puzzle: p, isLibrary: true, store: app.store)
            }
        case .playCustom(let id):
            if let stored = app.store.userPuzzles.first(where: { $0.id == id }) {
                PlayView(puzzle: stored.asPuzzle, isLibrary: false, store: app.store)
            }
        case .badge(let key):
            BadgeListView(key: key)
        case .editor(let id):
            EditorView(editID: id, store: app.store)
        case .about:
            AboutView()
        case .privacy:
            PrivacyView()
        case .explainer(let id):
            if let p = app.anyPuzzle(withID: id) {
                ExplainerView(puzzle: p)
            }
        case .generator:
            GeneratorView()
        case .playGenerated(let id):
            if let stored = app.store.generatedPuzzles.first(where: { $0.id == id }) {
                PlayView(puzzle: stored.asPuzzle, isLibrary: false, store: app.store)
            }
        }
    }
}
