// Ad readiness — PROTOCOL ONLY. Pixelogic ships absolutely free with no ads,
// no tracking, and no reserved ad space in any layout.
//
// This file exists so that IF ads are ever added, the integration path is
// already designed and reviewed:
//
//  1. An ad SDK adapter implements `AdSlotProvider` in its own module.
//  2. The app registers it at launch via `AdSlots.register(_:)`.
//  3. Views that may host an ad ask `AdSlots.view(for:)` at render time and
//     insert the returned view INLINE (layout reflows when — and only when —
//     a real ad exists; no placeholder space is ever reserved).
//  4. `interstitialAllowed(after:)` gates frequency so an ad can never
//     interrupt an active solve (App Store 4.5.x friendliness by design).
//
// Until then, `NoAds` is the registered provider and every slot resolves to
// nothing — verified by unit tests.

import Foundation

/// Logical places an ad could one day appear. Deliberately few.
public enum AdPlacement: String, CaseIterable, Sendable {
    /// Below the puzzle list on the home screen.
    case homeFooter
    /// After the win sheet is dismissed (never during play).
    case postSolveInterstitial
}

/// Implemented by a future ad adapter. Methods are deliberately minimal so no
/// ad SDK types leak into the app's views.
public protocol AdSlotProvider: Sendable {
    /// Whether a placement currently has an ad to show. Must be cheap.
    func hasAd(for placement: AdPlacement) -> Bool
    /// Frequency gate for interruptive placements.
    func interstitialAllowed(after solveCount: Int) -> Bool
}

/// The shipping provider: no ads, ever.
public struct NoAds: AdSlotProvider {
    public init() {}
    public func hasAd(for placement: AdPlacement) -> Bool { false }
    public func interstitialAllowed(after solveCount: Int) -> Bool { false }
}

/// Global registry. Swapping providers is a one-line change at app launch.
public enum AdSlots {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var provider: AdSlotProvider = NoAds()

    public static func register(_ newProvider: AdSlotProvider) {
        lock.lock()
        defer { lock.unlock() }
        provider = newProvider
    }

    public static func current() -> AdSlotProvider {
        lock.lock()
        defer { lock.unlock() }
        return provider
    }
}
