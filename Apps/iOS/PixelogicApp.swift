// Pixelogic for iPhone & iPad — free, no ads, no accounts, fully on-device.

import SwiftUI
import PixelogicKit

@MainActor
final class AppModel: ObservableObject {
    let store = PlayerStore()
    @Published var path = NavigationPath()
    @Published var showSettings = false
    @Published var showTutorial = false
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

    /// Resolve a puzzle for routes that may point at library OR custom art.
    func anyPuzzle(withID id: String) -> Puzzle? {
        PixelogicKit.puzzle(withID: id) ?? store.userPuzzles.first(where: { $0.id == id })?.asPuzzle
    }
}

@main
struct PixelogicApp: App {
    @StateObject private var app = AppModel()

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
            // The hand-tuned baby-blue palette is the brand in both modes;
            // forcing light keeps system surfaces (Form, sheets) coherent.
            .preferredColorScheme(.light)
            .sheet(isPresented: $app.showSettings) {
                SettingsView().environmentObject(app)
            }
            .fullScreenCover(isPresented: $app.showTutorial) {
                TutorialView().environmentObject(app)
            }
            .onAppear {
                // First-ever launch: show the tutorial before the menu — unless a
                // deep link has already pushed a puzzle (path non-empty).
                if !app.store.tutorialSeen && app.path.isEmpty { app.showTutorial = true }
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

    /// pixelogic://p/<token> (and the web URL form) → validate, import & play.
    private func openSharedPuzzle(_ url: URL) {
        guard let token = shareToken(fromUserInput: url.absoluteString),
              let decoded = try? decodePuzzle(token) else {
            app.importError = "That link isn’t a Pixelogic puzzle."
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
        case .explainer(let id):
            if let p = app.anyPuzzle(withID: id) {
                ExplainerView(puzzle: p)
            }
        }
    }
}
