// The App Group that lets the apps and their widget/complication extensions read
// the same player data.
//
// Widgets run in a *separate process* with a separate `UserDefaults.standard`.
// Without a shared suite a widget sees an empty save and renders "nothing to
// continue" forever. Everything the extensions need therefore lives in the
// group container, and `PlayerStore` adopts any save still sitting in the
// app-local defaults the first time it starts up against the group.

import Foundation

public enum AppGroup {
    /// Must match the `com.apple.security.application-groups` entitlement on
    /// every target (iOS app, watch app, both widget extensions).
    public static let identifier = "group.com.clueweave.app"

    /// The shared suite, or `.standard` when the entitlement is missing — the
    /// app still works, it just stops feeding the widgets.
    public static let defaults: UserDefaults =
        UserDefaults(suiteName: identifier) ?? .standard

    /// False when we fell back to app-local defaults (no entitlement, or a
    /// unit-test host). Callers can use it to skip widget reloads.
    public static var isShared: Bool { defaults !== UserDefaults.standard }
}
