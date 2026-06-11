// Pixelogic for iPhone & iPad — free, no ads, no accounts, fully on-device.

import SwiftUI
import PixelogicKit

@MainActor
final class AppModel: ObservableObject {
    let store = PlayerStore()
    @Published var path = NavigationPath()
    @Published var showSettings = false
    @Published var showTutorial = false

    /// Pop the current screen and push another (used by prev/next puzzle).
    func replaceTop(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
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
            .sheet(isPresented: $app.showSettings) {
                SettingsView().environmentObject(app)
            }
            .fullScreenCover(isPresented: $app.showTutorial) {
                TutorialView().environmentObject(app)
            }
            .onAppear {
                // First-ever launch: show the interactive tutorial before the menu.
                if !app.store.tutorialSeen { app.showTutorial = true }
            }
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
            if let p = puzzle(withID: id) {
                ExplainerView(puzzle: p)
            }
        }
    }
}
