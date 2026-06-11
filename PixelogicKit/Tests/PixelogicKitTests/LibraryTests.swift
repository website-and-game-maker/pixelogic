import Testing
@testable import PixelogicKit

// The same shipping guarantee as the web engine: every library puzzle has
// exactly one solution, is solvable by pure logic, and sits in the tier the
// grader assigns (no silent drift between the baked difficulty and the engine).

@Suite struct LibraryInvariants {
    @Test func healthySize() {
        #expect(library.count >= 30)
        #expect(Set(library.map(\.id)).count == library.count)
    }

    @Test func coversEveryTier() {
        for tier in Difficulty.ordered {
            #expect(!puzzles(in: tier).isEmpty, "tier \(tier) is empty")
        }
    }

    @Test(arguments: library.map(\.id))
    func puzzleInvariants(id: String) {
        let p = puzzle(withID: id)!

        // Exactly one solution, never capped.
        let count = countSolutionsDetailed(p.rowClues, p.colClues, limit: 2)
        #expect(count.count == 1 && !count.capped, "\(p.title) is not provably unique")

        // Solvable without guessing (line logic + depth-1 contradiction).
        #expect(isLogicSolvable(p.rowClues, p.colClues), "\(p.title) is not logic-solvable")

        // The baked difficulty matches the engine's judgement.
        #expect(gradeGrid(p.solution) == p.difficulty, "\(p.title) tier drifted")

        // Tier rules.
        let lineSolvable = isLineSolvable(p.rowClues, p.colClues)
        switch p.difficulty {
        case .easy, .medium:
            #expect(lineSolvable, "\(p.title) below hard must be line-solvable")
        case .expert, .max:
            #expect(!lineSolvable, "\(p.title) in top tiers must need contradictions")
            #expect(!isSymmetric(p.solution), "\(p.title) in top tiers must be asymmetric")
        case .hard:
            break // hard may be either (e.g. Letter A is a capped contradiction puzzle)
        }

        // Clue dimensions match.
        #expect(p.rowClues.count == p.height)
        #expect(p.colClues.count == p.width)

        // The engine's solution matches the stored picture.
        let solved = enumerateSolutions(p.rowClues, p.colClues, limit: 1).first
        #expect(solved == p.solution, "\(p.title) solver answer differs from stored art")
    }

    @Test func expectedTierSpotChecks() {
        #expect(puzzle(withID: "diamond")!.difficulty == .medium) // big but simple
        #expect(puzzle(withID: "tree")!.difficulty == .medium)
        #expect(puzzle(withID: "bird")!.difficulty == .hard)
        #expect(puzzle(withID: "letter-a")!.difficulty == .hard) // symmetric cap
        #expect(puzzle(withID: "cipher")!.difficulty == .expert)
        #expect(puzzle(withID: "static")!.difficulty == .max) // "another level"
        #expect(puzzle(withID: "obsidian")!.difficulty == .max)
    }

    @Test func abstractTitlesLackNameHint() {
        #expect(!puzzle(withID: "static")!.named)
        #expect(!puzzle(withID: "enigma")!.named)
        #expect(puzzle(withID: "heart")!.named)
        #expect(puzzle(withID: "cat")!.named)
    }
}
