// URL-safe (de)serialization of a custom puzzle — byte-compatible with the web
// app's share links (src/ui/shareCodec.ts), so a puzzle shared from the iPhone
// opens in any browser and vice versa.

import Foundation

public enum ShareCodecError: Error {
    case malformed
    case invalidDimensions
}

private struct TokenPayload: Codable {
    let w: Int
    let h: Int
    let t: String
    let b: String
}

private func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func base64URLDecode(_ s: String) -> Data? {
    var padded = s
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while padded.count % 4 != 0 { padded += "=" }
    return Data(base64Encoded: padded)
}

/// Encode a solution grid + title into a short URL-safe token.
public func encodePuzzle(_ solution: [[Bool]], title: String) -> String {
    let h = solution.count
    let w = h > 0 ? solution[0].count : 0
    let bits = solution.flatMap { $0 }.map { $0 ? "1" : "0" }.joined()
    let payload = TokenPayload(w: w, h: h, t: title, b: bits)
    let encoder = JSONEncoder()
    // Match the web's compact JSON (no spaces); key order doesn't matter for decode.
    let data = (try? encoder.encode(payload)) ?? Data()
    return base64URLEncode(data)
}

/// Decode a token back into a solution grid + title. Throws on malformed input.
public func decodePuzzle(_ token: String) throws -> (solution: [[Bool]], title: String) {
    guard let data = base64URLDecode(token),
          let payload = try? JSONDecoder().decode(TokenPayload.self, from: data) else {
        throw ShareCodecError.malformed
    }
    let w = payload.w
    let h = payload.h
    let bits = Array(payload.b)
    guard w > 0, h > 0, w <= 30, h <= 30, bits.count == w * h else {
        throw ShareCodecError.invalidDimensions
    }
    var solution: [[Bool]] = []
    solution.reserveCapacity(h)
    for r in 0..<h {
        var row: [Bool] = []
        row.reserveCapacity(w)
        for c in 0..<w { row.append(bits[r * w + c] == "1") }
        solution.append(row)
    }
    return (solution, payload.t)
}

/// The canonical web URL that opens this puzzle anywhere.
public func webShareURL(forToken token: String) -> URL {
    URL(string: "https://website-and-game-maker.github.io/pixelogic/#/p/\(token)")!
}

public func webShareURL(forLibraryID id: String) -> URL {
    URL(string: "https://website-and-game-maker.github.io/pixelogic/#/play/\(id)")!
}

/// Extract a share token from whatever the user pasted or tapped: a bare
/// token, a `pixelogic://p/<token>` link, or the canonical web URL
/// (`…/pixelogic/#/p/<token>`). Returns nil when nothing token-shaped is found.
public func shareToken(fromUserInput input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let range = trimmed.range(of: "/p/", options: .backwards) {
        let tail = trimmed[range.upperBound...]
        let token = tail.split(whereSeparator: { "?&#/".contains($0) }).first.map(String.init) ?? ""
        return token.isEmpty ? nil : token
    }
    // Bare token: base64url alphabet only (what encodePuzzle emits).
    guard trimmed.unicodeScalars.allSatisfy({
        ("A"..."Z").contains(Character($0)) || ("a"..."z").contains(Character($0))
            || ("0"..."9").contains(Character($0)) || $0 == "-" || $0 == "_"
    }) else { return nil }
    return trimmed
}

/// Whether a decoded share payload is safe to play: it must have EXACTLY ONE
/// solution — the same guarantee the editor enforces before it lets you Save.
/// Share tokens can encode any grid (a tampered or hand-made link, or a legacy
/// token), and a multi-solution board is unwinnable here: `GameSession.isSolved`
/// compares against the one stored picture, so a player who finds a different
/// valid picture never registers a win, and mistake-check would paint their
/// (valid) cells red. Imports run this gate; non-unique tokens are refused.
public func sharedSolutionIsUnique(_ solution: [[Bool]]) -> Bool {
    let h = solution.count
    guard h > 0, let w = solution.first?.count, w > 0,
          solution.allSatisfy({ $0.count == w }) else { return false }
    let clues = cluesForGrid(solution)
    return hasUniqueSolution(clues.rowClues, clues.colClues)
}

/// Pull a LIBRARY puzzle id out of a shared link (web `#/play/<id>`), the form
/// `webShareURL(forLibraryID:)` emits. Returns nil if the input isn't a library
/// link. (Custom-puzzle links use `/p/<token>` — see `shareToken`.)
public func libraryShareID(fromUserInput input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let range = trimmed.range(of: "/play/", options: .backwards) else { return nil }
    let tail = trimmed[range.upperBound...]
    let id = tail.split(whereSeparator: { "?&#/".contains($0) }).first.map(String.init) ?? ""
    return id.isEmpty ? nil : id
}

/// Off-the-caller's-actor async wrapper, so a big imported grid is validated
/// without blocking the main thread. A free `async` function is `nonisolated`,
/// so the solver runs on the cooperative pool.
public func validateSharedSolution(_ solution: [[Bool]]) async -> Bool {
    sharedSolutionIsUnique(solution)
}
