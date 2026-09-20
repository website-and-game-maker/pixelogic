// Everything the widgets, complications and the Live Activity read.
// Mirrored one-for-one in `Sources/clueweave-verify/main.swift`, so these
// checks also run with bare Command Line Tools.

import Testing
import Foundation
@testable import ClueweaveKit

private func grid(_ rows: [String]) -> [[Bool]] { bitmapToGrid(rows) }

/// 3×3, no symmetry and no single-run lines, so it earns no badges.
private func pz(_ id: String, _ d: Difficulty) -> Puzzle {
    Puzzle(id: id, title: id, solution: grid(["#.#", "...", "#.."]), difficulty: d)
}

private let plib = [
    pz("m1", .medium), pz("e1", .easy), pz("h1", .hard), pz("e2", .easy), pz("m2", .medium),
]

// MARK: - Deep links

@Suite struct DeepLinkTests {
    private func roundTrips(_ link: ClueweaveLink) -> Bool {
        parseClueweaveLink(link.url) == link
    }

    @Test func everyLinkRoundTrips() {
        #expect(roundTrips(.home))
        #expect(roundTrips(.recommended))
        #expect(roundTrips(.resume("u-1a2b3c4d")))
        #expect(roundTrips(.puzzle("plus")))
        for tier in Difficulty.allCases {
            #expect(roundTrips(.tier(tier)), "tier \(tier.rawValue)")
        }
    }

    @Test func tierLinksUseRawValues() {
        // Not the display name — "Extra Hard" would never survive a URL.
        #expect(ClueweaveLink.tier(.expert).string == "clueweave://tier/expert")
    }

    @Test func parsingIsForgivingButNotGullible() {
        #expect(parseClueweaveLink("clueweave://TIER/Hard") == .tier(.hard))
        #expect(parseClueweaveLink("clueweave://tier/legendary") == nil)
        #expect(parseClueweaveLink("clueweave://resume/") == nil)
        #expect(parseClueweaveLink("https://example.com/") == nil)
    }

    @Test func shareLinksStillWork() {
        let token = encodePuzzle(grid(["#.", ".#"]), title: "Two")
        #expect(parseClueweaveLink("clueweave://p/\(token)") == .share(token))
        #expect(parseClueweaveLink(webShareURL(forToken: token).absoluteString) == .share(token))
    }
}

// MARK: - Snapshot

@Suite struct WidgetSnapshotTests {
    private let solution = grid(["#.#", "...", "#.."])   // 3 filled cells

    private func marks(_ rows: [String]) -> Grid {
        rows.map { row -> [Cell] in
            row.map { ch -> Cell in
                switch ch {
                case "#": return .filled
                case "x": return .empty
                default: return .unknown
                }
            }
        }
    }

    @Test func progressCountsOnlyCorrectFills() {
        #expect(solveProgress(marks: marks(["...", "...", "..."]), solution: solution) == (0, 3))
        // A cross and a wrong fill must not move the ring.
        #expect(solveProgress(marks: marks(["#x.", ".#.", "..."]), solution: solution) == (1, 3))
        #expect(solveProgress(marks: marks(["#x#", ".#.", "#.."]), solution: solution) == (3, 3))
    }

    @Test func boardPreviewRoundTrips() {
        let m = marks(["#x#", ".#.", "#.."])
        let preview = BoardPreview(marks: m)
        #expect(preview.width == 3 && preview.height == 3 && preview.cells.count == 9)
        #expect(preview.grid == m)
    }

    @Test func truncatedPreviewReadsUnknown() {
        // A snapshot from another app version must never crash a watch face.
        #expect(BoardPreview(width: 3, height: 3, cells: "").cell(2, 2) == .unknown)
        #expect(BoardPreview(width: 3, height: 3, cells: "##").grid[2][2] == .unknown)
    }

    @Test func tierSuggestionWalksThenReplays() {
        #expect(tierSuggestion(.easy, plib, [], [:])?.id == "e1")
        #expect(tierSuggestion(.easy, plib, ["e1"], [:])?.id == "e2")
        // Finished tier: the puzzle with the most score left to win.
        #expect(tierSuggestion(.easy, plib, ["e1", "e2"], ["e1": 100, "e2": 40])?.id == "e2")
        // Ties keep the earlier curriculum index.
        #expect(tierSuggestion(.easy, plib, ["e1", "e2"], [:])?.id == "e1")
        #expect(tierSuggestion(.max, plib, [], [:]) == nil)
    }

    @Test func snapshotSummarisesTheSave() {
        let snap = makeWidgetSnapshot(
            library: plib,
            completed: ["e1"],
            bestScores: ["e1": 80],
            continueFrom: ContinueSource(
                puzzle: pz("m1", .medium), marks: marks(["#x#", ".#.", "#.."]), elapsedMs: 42_000),
            score: 1234
        )
        #expect(snap.solved == 1 && snap.total == 5)
        #expect(snap.tiers.map(\.tier) == [.easy, .medium, .hard])  // empty tiers dropped
        #expect(snap.tier(.easy)?.solved == 1 && snap.tier(.easy)?.total == 2)
        #expect(snap.tier(.easy)?.suggestionID == "e2")
        #expect(snap.continueEntry?.fraction == 1.0)
        #expect(snap.recommendation?.puzzleID != "m1", "never recommend the board you're on")
    }

    @Test func primaryLinkPrefersTheUnfinishedBoard() {
        let withBoard = makeWidgetSnapshot(
            library: plib, completed: [],
            continueFrom: ContinueSource(
                puzzle: pz("m1", .medium), marks: marks(["...", "...", "..."]), elapsedMs: 0))
        #expect(withBoard.primaryLink == .resume("m1"))

        let noBoard = makeWidgetSnapshot(library: plib, completed: [])
        #expect(noBoard.primaryLink == .puzzle("e1"))
        #expect(WidgetSnapshot().primaryLink == .home)
    }

    @Test func snapshotSurvivesJSONAndJunk() throws {
        let snap = makeWidgetSnapshot(library: plib, completed: ["e1"], score: 7)
        let data = try JSONEncoder().encode(snap)
        let round = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(round == snap)

        // Field-by-field, like SaveData: a bad field must not blank the widget.
        let partial = Data(#"{"solved":3,"workingTier":"nonsense","tiers":"junk"}"#.utf8)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: partial)
        #expect(decoded.solved == 3)
        #expect(decoded.workingTier == .easy)
        #expect(decoded.tiers.isEmpty)
    }
}

// MARK: - Live Activity content state

@Suite struct LiveActivityStateTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func runningClockFoldsInBankedTime() {
        let s = PuzzleActivityState(
            correct: 2, totalFilled: 8, runningSince: start, elapsedMs: 30_000)
        #expect(s.fraction == 0.25)
        #expect(s.totalElapsedMs(at: start.addingTimeInterval(5)) == 35_000)
        // Anchoring the timer back by the banked time is what makes a resumed
        // attempt show its true total instead of restarting from zero.
        #expect(s.timerStart == start.addingTimeInterval(-30))
    }

    @Test func pausedClockDoesNotDrift() {
        let s = PuzzleActivityState(correct: 2, totalFilled: 8, runningSince: nil, elapsedMs: 30_000)
        #expect(s.totalElapsedMs(at: start.addingTimeInterval(600)) == 30_000)
        #expect(s.timerStart == nil, "a paused attempt shows a frozen number, not a lying timer")
    }

    @Test func solvedFreezesAtTheFinalTime() {
        let s = PuzzleActivityState(
            correct: 8, totalFilled: 8, runningSince: start, elapsedMs: 90_000, isSolved: true)
        #expect(s.fraction == 1.0)
        #expect(s.totalElapsedMs(at: .distantFuture) == 90_000)
        #expect(s.timerStart == nil)
    }

    @Test func emptyPictureCannotDivideByZero() {
        #expect(PuzzleActivityState(correct: 3, totalFilled: 0, elapsedMs: 0).fraction == 0)
    }
}

// MARK: - App Group migration

@Suite struct AppGroupMigrationTests {
    private func suite(_ name: String) -> UserDefaults {
        UserDefaults(suiteName: "test.\(name).\(UUID().uuidString)")!
    }

    @Test func preRebrandAppLocalSaveMovesToTheGroup() throws {
        let local = suite("local")
        let shared = suite("shared")
        var seed = SaveData()
        seed.completed = ["plus"]
        local.set(try JSONEncoder().encode(seed), forKey: "pixelogic.save.v1")

        let store = PlayerStore(defaults: shared, migratingFrom: [local])
        #expect(store.isCompleted("plus"), "both migrations stack: rebrand, then App Group")
        #expect(shared.data(forKey: PlayerStore.storageKey) != nil)
        #expect(local.data(forKey: "pixelogic.save.v1") == nil, "migrates once")
    }

    @Test func migrationNeverOverwritesNewerProgress() throws {
        let local = suite("local")
        let shared = suite("shared")
        var stale = SaveData(); stale.completed = ["plus"]
        var current = SaveData(); current.completed = ["heart"]
        local.set(try JSONEncoder().encode(stale), forKey: PlayerStore.storageKey)
        shared.set(try JSONEncoder().encode(current), forKey: PlayerStore.storageKey)

        let store = PlayerStore(defaults: shared, migratingFrom: [local])
        #expect(store.isCompleted("heart"))
        #expect(!store.isCompleted("plus"))
    }

    @Test func continueOffersTheMostRecentBoard() {
        let shared = suite("continue")
        let store = PlayerStore(defaults: shared)
        let m: Grid = Array(repeating: Array(repeating: Cell.unknown, count: 3), count: 3)
        store.saveInProgress(
            InProgressAttempt(marks: m, elapsedMs: 5_000, assists: AssistTally(),
                              updatedAt: Date(timeIntervalSince1970: 10)),
            for: "older")
        store.saveInProgress(
            InProgressAttempt(marks: m, elapsedMs: 9_000, assists: AssistTally(),
                              updatedAt: Date(timeIntervalSince1970: 20)),
            for: "newer")

        #expect(store.latestContinue(resolve: { pz($0, .medium) })?.puzzle.id == "newer")
        #expect(store.latestContinue(resolve: { _ in nil }) == nil,
                "a saved board whose puzzle was deleted is not offered")
    }

    @Test func publishingWritesWhatTheWidgetReads() {
        let shared = suite("publish")
        let store = PlayerStore(defaults: shared)
        let m: Grid = Array(repeating: Array(repeating: Cell.unknown, count: 5), count: 5)
        store.saveInProgress(
            InProgressAttempt(marks: m, elapsedMs: 1_000, assists: AssistTally()), for: "plus")
        store.publishWidgetSnapshot(resolve: { puzzle(withID: $0) })

        let read = SnapshotStore.read(from: shared)
        #expect(read?.continueEntry?.puzzleID == "plus")
        #expect(read?.total == library.count)
    }
}
