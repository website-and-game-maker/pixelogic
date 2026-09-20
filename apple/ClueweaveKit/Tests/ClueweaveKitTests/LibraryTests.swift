import Testing
@testable import ClueweaveKit

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

        // NB: no technique-based tier rules any more. They used to assert
        // "easy/medium ⇒ line-solvable" and "expert/max ⇒ needs contradictions
        // AND is asymmetric", which described the old grader, where tiers were
        // named after the hardest *technique* required. The grader now measures
        // total solving *effort*, and the two ideas genuinely come apart —
        //   • Letter A needs a what-if but is a 25-cell mirror image → Easy;
        //   • Pine Tree is line-solvable and symmetric but 15×15 of sustained
        //     work → Extra Hard.
        // The `gradeGrid == stored` check above covers tier correctness; the old
        // rules would only pin the bug back in place.

        // Clue dimensions match.
        #expect(p.rowClues.count == p.height)
        #expect(p.colClues.count == p.width)

        // The engine's solution matches the stored picture.
        let solved = enumerateSolutions(p.rowClues, p.colClues, limit: 1).first
        #expect(solved == p.solution, "\(p.title) solver answer differs from stored art")
    }

    @Test func expectedTierSpotChecks() {
        // The two playtested anchors first — both were mis-tiered by the old
        // sweep-counting grader (A shipped Hard, Cat shipped Medium).
        #expect(puzzle(withID: "letter-a")!.difficulty == .easy)
        #expect(puzzle(withID: "cat")!.difficulty == .hard)

        #expect(puzzle(withID: "diamond")!.difficulty == .medium) // big but simple
        #expect(puzzle(withID: "tree")!.difficulty == .expert) // 15×15 of sustained work
        #expect(puzzle(withID: "bird")!.difficulty == .hard)
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
