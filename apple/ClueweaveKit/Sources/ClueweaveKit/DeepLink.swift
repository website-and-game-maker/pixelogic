// Deep links. One parser, shared by both apps and both widget bundles, so a
// complication can never build a URL the app doesn't understand.
//
//   clueweave://home                 the menu
//   clueweave://tier/hard            that difficulty's section
//   clueweave://resume/<id>          re-open an unfinished attempt
//   clueweave://puzzle/<id>          open a puzzle (library, custom or generated)
//   clueweave://recommended          whatever `recommend()` picks right now
//   clueweave://p/<token>            an imported shared puzzle (pre-existing)
//
// `resume` and `puzzle` differ only in intent: `resume` is what a Continue
// widget emits, and lets the app tell "the player tapped their saved board"
// apart from "the player picked this puzzle from a list". The destination is
// the same screen — `PlayView` restores the saved attempt either way — but the
// distinction is what keeps a stale complication from looking broken: if the
// attempt is gone, `resume` falls back to the menu instead of silently
// starting a fresh board the player didn't ask for.

import Foundation

public enum ClueweaveLink: Equatable, Sendable {
    case home
    case tier(Difficulty)
    case resume(String)
    case puzzle(String)
    case recommended
    case share(String)

    /// The URL a widget should hand to `widgetURL(_:)` / `Link(destination:)`.
    public var url: URL {
        URL(string: string)!
    }

    public var string: String {
        switch self {
        case .home: "\(ClueweaveLink.scheme)://home"
        case .tier(let d): "\(ClueweaveLink.scheme)://tier/\(d.rawValue)"
        case .resume(let id): "\(ClueweaveLink.scheme)://resume/\(ClueweaveLink.escape(id))"
        case .puzzle(let id): "\(ClueweaveLink.scheme)://puzzle/\(ClueweaveLink.escape(id))"
        case .recommended: "\(ClueweaveLink.scheme)://recommended"
        case .share(let token): "\(ClueweaveLink.scheme)://p/\(token)"
        }
    }

    public static let scheme = "clueweave"

    /// Puzzle ids are engine-generated (`e1`, `u-1a2b3c4d`, …) so percent-escaping
    /// is belt-and-braces — but an imported title could one day seed an id.
    private static func escape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-_."))) ?? s
    }
}

/// Parse an incoming URL. Falls back to the share-token reader so the
/// pre-existing `clueweave://p/<token>` and web-URL forms keep working.
public func parseClueweaveLink(_ url: URL) -> ClueweaveLink? {
    parseClueweaveLink(url.absoluteString)
}

public func parseClueweaveLink(_ raw: String) -> ClueweaveLink? {
    guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return nil
    }
    if url.scheme?.lowercased() == ClueweaveLink.scheme {
        // "clueweave://tier/hard" → host "tier", first path component "hard".
        let host = url.host?.lowercased() ?? ""
        let rest = url.pathComponents.filter { $0 != "/" }
        let first = rest.first.flatMap { $0.removingPercentEncoding } ?? rest.first

        switch host {
        case "home", "menu":
            return .home
        case "recommended", "recommend":
            return .recommended
        case "tier", "difficulty":
            guard let first, let tier = Difficulty(rawValue: first.lowercased()) else { return nil }
            return .tier(tier)
        case "resume", "continue":
            guard let first, !first.isEmpty else { return nil }
            return .resume(first)
        case "puzzle", "play":
            guard let first, !first.isEmpty else { return nil }
            return .puzzle(first)
        default:
            break
        }
    }
    // Anything else: the shared-puzzle reader decides (it also accepts web URLs
    // and a bare token pasted by hand).
    if let token = shareToken(fromUserInput: raw) {
        return .share(token)
    }
    return nil
}
