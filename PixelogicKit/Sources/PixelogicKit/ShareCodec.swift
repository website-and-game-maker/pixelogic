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
