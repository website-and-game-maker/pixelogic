import Testing
import Foundation
@testable import ClueweaveKit

private func grid(_ rows: [String]) -> [[Bool]] {
    bitmapToGrid(rows)
}

// MARK: - Clues

@Suite struct ClueTests {
    @Test func runLengthEncoding() {
        #expect(cluesForLine([false, false, false]) == [])
        #expect(cluesForLine([true, true, true]) == [3])
        #expect(cluesForLine([true, false, true, true]) == [1, 2])
    }

    @Test func gridClues() {
        let clues = cluesForGrid(grid(["#.#", "###"]))
        #expect(clues.rowClues == [[1, 1], [3]])
        #expect(clues.colClues == [[2], [1], [2]])
    }
}

// MARK: - Line solver

@Suite struct LineSolverTests {
    @Test func fullLine() {
        let out = solveLine([.unknown, .unknown, .unknown], [3])
        #expect(out == [.filled, .filled, .filled])
    }

    @Test func emptyClueCrossesAll() {
        let out = solveLine([.unknown, .unknown], [])
        #expect(out == [.empty, .empty])
    }

    @Test func overlapDeduction() {
        // clue [3] in 5 cells: middle cell is filled in every placement.
        let out = solveLine([.unknown, .unknown, .unknown, .unknown, .unknown], [3])
        #expect(out?[2] == .filled)
        #expect(out?[0] == .unknown)
    }

    @Test func infeasibleReturnsNil() {
        #expect(solveLine([.empty, .empty, .empty], [1]) == nil)
    }
}

// MARK: - Solver

@Suite struct SolverTests {
    @Test func solvesSimpleGrid() {
        let g = grid(["#.", ".#"])
        let clues = cluesForGrid(g)
        // checkerboard 2x2 with [1],[1] clues is ambiguous — two solutions
        #expect(countSolutionsDetailed(clues.rowClues, clues.colClues).count == 2)
        #expect(!hasUniqueSolution(clues.rowClues, clues.colClues))
    }

    @Test func uniqueSolutionDetected() {
        let g = grid(["##", "#."])
        let clues = cluesForGrid(g)
        #expect(hasUniqueSolution(clues.rowClues, clues.colClues))
        #expect(enumerateSolutions(clues.rowClues, clues.colClues).first == g)
    }
}

// MARK: - Deduce

@Suite struct DeduceTests {
    @Test func solvesByLogicWithReadableCaptions() {
        let plus = puzzle(withID: "plus")!
        let result = solveByLogic(plus.rowClues, plus.colClues)
        #expect(result.solved)
        #expect(toBooleans(result.grid) == plus.solution)
        #expect(result.steps.allSatisfy { !$0.caption.isEmpty })
    }

    @Test func contradictionTechniqueOnMaxPuzzle() {
        let hard = puzzle(withID: "static")!
        let result = solveByLogic(hard.rowClues, hard.colClues)
        #expect(result.solved)
        #expect(result.steps.contains { $0.technique == .contradiction })
    }
}

// MARK: - Symmetry & badges

@Suite struct SymmetryTests {
    @Test func detectsDirections() {
        #expect(detectSymmetry(grid(["#.#", "###", "..."])).horizontal)
        #expect(detectSymmetry(grid(["##.", "...", "##."])).vertical)
        #expect(symmetryDetail(grid(["#.#", "...", "#.#"])) == "H+V")
        #expect(symmetryDetail(grid(["#..", "...", "..#"])) == "180°")
        #expect(symmetryDetail(grid(["#..", "#..", ".##"])) == nil)
    }
}

@Suite struct BadgeTests {
    @Test func patternedDetection() {
        #expect(detectPatterned(grid(["..#..", ".###.", "#####", ".###.", "..#.."])))
        #expect(!detectPatterned(grid([".#.#.", "#####", "#####", ".###.", "..#.."])))
        #expect(!detectPatterned(grid(["#####", "#...#", "#####"])))
    }

    @Test func badgeCollection() {
        let diamond = grid(["..#..", ".###.", "#####", ".###.", "..#.."])
        let badges = puzzleBadges(solution: diamond, named: true)
        #expect(Set(badges.map(\.key)) == [.symmetric, .named, .patterned])
        #expect(badges.first { $0.key == .symmetric }!.label.contains("H+V"))
        let expected = 0.85 * 0.9 * 0.8
        #expect(abs(badgeWeightMultiplier(badges) - expected) < 1e-10)
    }
}

// MARK: - Grader

@Suite struct GraderTests {
    @Test func smallSymmetricContradictionPictureIsEasy() {
        // Playtested ground truth: Letter A is easy. 25 cells you can hold in
        // your head, and a mirror axis that hands you half of it. A flat
        // per-contradiction weight plus an easy ceiling that sat below every 5×5
        // used to ship it as Hard.
        let letterA = grid([".###.", "#...#", "#####", "#...#", "#...#"])
        let clues = cluesForGrid(letterA)
        #expect(!isLineSolvable(clues.rowClues, clues.colClues))
        #expect(gradeGrid(letterA) == .easy)
    }

    @Test func irregularTenByTenIsHard() {
        // The other half of the same playtest: Cat is hard. Asymmetric and
        // unpatterned, so nothing discounts it, and 100 cells of real deduction
        // is more work than any 5×5 — which sweep-counting used to miss.
        let cat = puzzle(withID: "cat")!
        #expect(!isSymmetric(cat.solution))
        #expect(gradeGrid(cat.solution) == .hard)
    }

    @Test func patternedCapsAtMedium() {
        // Diamond shape: symmetric AND patterned → at most medium.
        let diamond = puzzle(withID: "diamond")!
        #expect(gradeGrid(diamond.solution) == .medium)
    }
}

// MARK: - Scoring

@Suite struct ScoringTests {
    @Test func parScaling() {
        #expect(parSeconds(.easy, area: 25) == 25)
        #expect(parSeconds(.medium, area: 100) == 150)
        #expect(parSeconds(.max, area: 196) == 882)
    }

    @Test func perPuzzleScore() {
        let par = parSeconds(.easy, area: 25) * 1000
        #expect(puzzleScore(difficulty: .easy, area: 25, bestTimeMs: par, assists: AssistTally()) == 100)
        #expect(puzzleScore(difficulty: .easy, area: 25, bestTimeMs: par / 2, assists: AssistTally()) == 100)
        let mediumPar = parSeconds(.medium, area: 100) * 1000
        #expect(puzzleScore(difficulty: .medium, area: 100, bestTimeMs: mediumPar * 2, assists: AssistTally()) == 50)
    }

    @Test func penaltiesAndVoid() {
        var assists = AssistTally()
        assists.checkSquare = 2
        assists.checkLine = 1
        assists.hint = 1
        #expect(assists.penaltyTotal == 45)
        let par = parSeconds(.hard, area: 100) * 1000
        #expect(puzzleScore(difficulty: .hard, area: 100, bestTimeMs: par, assists: assists) == 55)
        var voided = AssistTally()
        voided.voided = true
        #expect(puzzleScore(difficulty: .easy, area: 25, bestTimeMs: par, assists: voided) == 0)
    }

    @Test func clueweaveScoreWeighting() {
        let lib = [
            PuzzleMeta(id: "e", difficulty: .easy),
            PuzzleMeta(id: "x", difficulty: .expert),
        ]
        #expect(clueweaveScore(bestScores: [:], library: lib) == 0)
        #expect(clueweaveScore(bestScores: ["e": 100, "x": 100], library: lib) == 1600)
        #expect(clueweaveScore(bestScores: ["e": 100], library: lib) == 200)
        #expect(clueweaveScore(bestScores: ["x": 100], library: lib) == 1400)
        // Badge multipliers shift shares without breaking the ceiling.
        let badged = [
            PuzzleMeta(id: "e", difficulty: .easy, weightMult: 0.5),
            PuzzleMeta(id: "x", difficulty: .expert),
        ]
        #expect(clueweaveScore(bestScores: ["e": 100, "x": 100], library: badged) == 1600)
        #expect(clueweaveScore(bestScores: ["e": 100], library: badged) == Int((1600 * 0.5 / 7.5).rounded()))
    }

    @Test func titlesAndBudgets() {
        #expect(scoreTitle(0) == "Novice")
        #expect(scoreTitle(900) == "Sharp")
        #expect(scoreTitle(1600) == "Grandmaster")
        #expect(Difficulty.easy.checkBudget == nil)
        #expect(Difficulty.hard.checkBudget == 3)
        #expect(Difficulty.max.checkBudget == 1)
    }
}

// MARK: - Player store

@Suite struct PlayerStoreTests {
    private func freshStore() -> PlayerStore {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        suite.removePersistentDomain(forName: suite.description)
        return PlayerStore(defaults: suite)
    }

    @Test func bestScoreKeepsMax() {
        let store = freshStore()
        #expect(store.recordScore("heart", score: 70) == (70, true))
        #expect(store.recordScore("heart", score: 60) == (70, false))
        #expect(store.recordScore("heart", score: 95) == (95, true))
        #expect(store.bestScore(for: "heart") == 95)
    }

    @Test func bestTimeKeepsMin() {
        let store = freshStore()
        #expect(store.recordBestTime("heart", elapsedMs: 9000) == (9000, true))
        #expect(store.recordBestTime("heart", elapsedMs: 12000) == (9000, false))
        #expect(store.recordBestTime("heart", elapsedMs: 7000) == (7000, true))
    }

    @Test func resetSetsDisclosureFlagAndKeepsSettings() {
        let store = freshStore()
        var settings = store.settings
        settings.mistakeCheck = true
        store.settings = settings
        store.markCompleted("smiley")
        store.recordScore("smiley", score: 88)

        store.resetProgress()

        #expect(!store.isCompleted("smiley"))
        #expect(store.bestScore(for: "smiley") == nil)
        #expect(store.wasProgressReset)
        #expect(store.settings.mistakeCheck) // kept
        #expect(store.clueweaveScore == 0)
    }

    @Test func clueweaveScoreRisesWithSolves() {
        let store = freshStore()
        #expect(store.clueweaveScore == 0)
        store.recordScore("plus", score: 100)
        #expect(store.clueweaveScore > 0)
    }
}

// MARK: - Ad readiness (ships with NO ads)

@Suite struct AdReadinessTests {
    @Test func noAdsAnywhere() {
        let provider = AdSlots.current()
        for placement in AdPlacement.allCases {
            #expect(!provider.hasAd(for: placement))
        }
        #expect(!provider.interstitialAllowed(after: 1000))
    }
}

// MARK: - Share-token parsing & import

@Suite struct ShareTokenTests {
    private let art = grid(["#.", ".#"])

    @Test func everyAcceptedForm() {
        let token = encodePuzzle(art, title: "Tiny")
        #expect(shareToken(fromUserInput: token) == token)
        #expect(shareToken(fromUserInput: "https://website-and-game-maker.github.io/clueweave/#/p/\(token)") == token)
        #expect(shareToken(fromUserInput: "clueweave://p/\(token)") == token)
        #expect(shareToken(fromUserInput: "  clueweave://p/\(token)\n") == token)
    }

    @Test func junkRejected() {
        #expect(shareToken(fromUserInput: "https://example.com/nothing-here") == nil)
        #expect(shareToken(fromUserInput: "not a token!!") == nil)
        #expect(shareToken(fromUserInput: "") == nil)
    }

    @Test func shareURLRoundTrips() throws {
        let token = encodePuzzle(art, title: "Tiny")
        let parsed = try #require(shareToken(fromUserInput: webShareURL(forToken: token).absoluteString))
        let decoded = try decodePuzzle(parsed)
        #expect(decoded.solution == art && decoded.title == "Tiny")
    }

    @Test func importDeduplicates() {
        let store = PlayerStore(defaults: UserDefaults(suiteName: "test.import.\(UUID().uuidString)")!)
        let first = store.importUserPuzzle(title: "Tiny", solution: art)
        let second = store.importUserPuzzle(title: "Tiny again", solution: art)
        #expect(first == second && store.userPuzzles.count == 1)
        #expect(store.importUserPuzzle(title: "Other", solution: grid(["##", "##"])) != first)
    }
}

// MARK: - In-progress attempts

@Suite struct InProgressTests {
    @Test func attemptRoundTripsAndRestores() {
        let store = PlayerStore(defaults: UserDefaults(suiteName: "test.ip.\(UUID().uuidString)")!)
        let plus = puzzle(withID: "plus")!
        let session = GameSession(puzzle: plus)
        session.toggle(2, 0)
        session.toggle(2, 1)
        var tally = AssistTally()
        tally.hint = 1
        let attempt = InProgressAttempt(marks: session.marks, elapsedMs: 12_000, assists: tally)
        store.saveInProgress(attempt, for: "plus")
        #expect(store.inProgress(for: "plus") == attempt)

        let resumed = GameSession(puzzle: plus)
        resumed.restore(marks: store.inProgress(for: "plus")!.grid, elapsedMs: 12_000, assists: tally)
        #expect(resumed.marks[2][0] == .filled && resumed.marks[2][1] == .filled)
        #expect(resumed.elapsedMs == 12_000)
        #expect(resumed.assists.hint == 1)
        #expect(!resumed.canUndo) // history does not cross a relaunch
    }

    @Test func mismatchedRestoreIgnored() {
        let session = GameSession(puzzle: puzzle(withID: "plus")!)
        session.toggle(2, 0)
        session.restore(marks: [[.filled]], elapsedMs: 1, assists: AssistTally())
        #expect(session.marks[2][0] == .filled)
    }

    @Test func lifecycleClearsSnapshots() {
        let store = PlayerStore(defaults: UserDefaults(suiteName: "test.ip2.\(UUID().uuidString)")!)
        let attempt = InProgressAttempt(marks: makeGrid(5, 5), elapsedMs: 1, assists: AssistTally())
        store.saveInProgress(attempt, for: "plus")
        store.markCompleted("plus")
        #expect(store.inProgress(for: "plus") == nil)
        store.saveInProgress(attempt, for: "smiley")
        store.resetProgress()
        #expect(store.inProgress(for: "smiley") == nil)
    }

    @Test func v1SaveMigratesLosslessly() {
        let blob = #"{"completed":["plus"],"bestTimes":{"plus":9000},"bestScores":{"plus":88},"assists":{},"userPuzzles":[],"settings":{"mistakeCheck":true,"showTimer":true,"clueStyle":"grey","autoCross":false},"tutorialSeen":true,"progressReset":false}"#
        let defaults = UserDefaults(suiteName: "test.v1.\(UUID().uuidString)")!
        defaults.set(Data(blob.utf8), forKey: PlayerStore.storageKey)
        let store = PlayerStore(defaults: defaults)
        #expect(store.isCompleted("plus") && store.bestScore(for: "plus") == 88)
        #expect(store.settings.mistakeCheck && store.tutorialSeen)
    }

    @Test func corruptSaveStashedNotDestroyed() {
        let defaults = UserDefaults(suiteName: "test.corrupt.\(UUID().uuidString)")!
        defaults.set(Data("{broken".utf8), forKey: PlayerStore.storageKey)
        _ = PlayerStore(defaults: defaults)
        #expect(defaults.data(forKey: PlayerStore.storageKey + ".corrupt") == Data("{broken".utf8))
    }
}

// MARK: - Import safety (pass 2)

@Suite struct ImportSafetyTests {
    @Test func uniquenessGate() {
        #expect(sharedSolutionIsUnique(grid(["##", "#."])))          // one solution
        #expect(!sharedSolutionIsUnique(grid(["#.", ".#"])))         // checkerboard: two
        #expect(!sharedSolutionIsUnique([]))                          // empty
        #expect(!sharedSolutionIsUnique([[true], [true, false]]))    // ragged
        #expect(sharedSolutionIsUnique(puzzle(withID: "plus")!.solution))
    }

    @Test func asyncWrapperAgrees() async {
        #expect(await validateSharedSolution(grid(["##", "#."])))
        #expect(!(await validateSharedSolution(grid(["#.", ".#"]))))
    }

    @Test func oneCorruptCustomEntryDoesNotWipeTheRest() {
        let blob = #"{"userPuzzles":[{"id":"good","title":"Good","solution":[[true,false],[false,true]]},{"id":"bad","title":"Broken"}]}"#
        let defaults = UserDefaults(suiteName: "test.mixed.\(UUID().uuidString)")!
        defaults.set(Data(blob.utf8), forKey: PlayerStore.storageKey)
        let store = PlayerStore(defaults: defaults)
        #expect(store.userPuzzles.count == 1 && store.userPuzzles[0].id == "good")
    }
}

// MARK: - Library links & edit-invalidation (review pass)

@Suite struct LibraryLinkTests {
    @Test func parsesLibraryLinks() {
        #expect(libraryShareID(fromUserInput: "https://website-and-game-maker.github.io/clueweave/#/play/plus") == "plus")
        #expect(libraryShareID(fromUserInput: "  #/play/heart\n") == "heart")
        #expect(libraryShareID(fromUserInput: webShareURL(forLibraryID: "smiley").absoluteString) == "smiley")
    }
    @Test func rejectsNonLibrary() {
        #expect(libraryShareID(fromUserInput: "clueweave://p/abc123") == nil)
        #expect(libraryShareID(fromUserInput: "nonsense") == nil)
    }
}

@Suite struct EditInvalidationTests {
    @Test func editedArtDropsStaleResume() {
        let store = PlayerStore(defaults: UserDefaults(suiteName: "test.edit.\(UUID().uuidString)")!)
        let art = grid(["##", "#."])
        store.saveUserPuzzle(StoredPuzzle(id: "u-e", title: "Mine", solution: art))
        store.saveInProgress(InProgressAttempt(marks: makeGrid(2, 2), elapsedMs: 5, assists: AssistTally()), for: "u-e")
        store.saveUserPuzzle(StoredPuzzle(id: "u-e", title: "Mine", solution: art))      // same art
        #expect(store.inProgress(for: "u-e") != nil)
        store.saveUserPuzzle(StoredPuzzle(id: "u-e", title: "Mine", solution: grid([".#", "##"]))) // changed
        #expect(store.inProgress(for: "u-e") == nil)
    }
}

// MARK: - Generator & generated store

@Suite struct GeneratorTests {
    @Test func producesValidUniqueLogicSolvablePuzzles() throws {
        for size in [5, 7, 8, 10] {
            var rng = SeededGenerator(seed: UInt64(size) &* 1234567)
            let puzzle = try #require(generatePuzzle(size: size, using: &rng))
            #expect(puzzle.width == size && puzzle.height == size)
            #expect(puzzle.id.hasPrefix("g-") && !puzzle.named)
            #expect(hasUniqueSolution(puzzle.rowClues, puzzle.colClues))
            #expect(isLogicSolvable(puzzle.rowClues, puzzle.colClues))
            #expect(gradeGrid(puzzle.solution) == puzzle.difficulty)
            let filled = puzzle.solution.flatMap { $0 }.filter { $0 }.count
            #expect(filled >= size && filled <= size * size - size)
        }
    }
    @Test func deterministicForASeed() {
        var a = SeededGenerator(seed: 42), b = SeededGenerator(seed: 42)
        #expect(generatePuzzle(size: 8, using: &a)?.solution == generatePuzzle(size: 8, using: &b)?.solution)
    }
    @Test func rejectsOutOfRangeSizes() {
        var rng = SeededGenerator(seed: 1)
        #expect(generatePuzzle(size: 4, using: &rng) == nil)
        #expect(generatePuzzle(size: 16, using: &rng) == nil)
    }
    @Test func submittableGate() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<40 {
            if let g = generatePuzzle(size: 8, using: &rng), g.difficulty != .easy {
                #expect(isWorthSubmitting(g)); return
            }
        }
    }
}

@Suite struct GeneratedStoreTests {
    @Test func saveDedupResetDelete() {
        let s = PlayerStore(defaults: UserDefaults(suiteName: "t.gen.\(UUID().uuidString)")!)
        let art = bitmapToGrid(["##", "#."])
        let id1 = s.saveGeneratedPuzzle(title: "A", solution: art)
        let id2 = s.saveGeneratedPuzzle(title: "B", solution: art)
        #expect(id1.hasPrefix("g-") && id1 == id2 && s.generatedPuzzles.count == 1)
        s.resetProgress()
        #expect(s.generatedPuzzles.count == 1)
        s.deleteGeneratedPuzzles(ids: [id1])
        #expect(s.generatedPuzzles.isEmpty)
    }
    @Test func olderSaveDecodesToEmpty() {
        let d = UserDefaults(suiteName: "t.gen2.\(UUID().uuidString)")!
        d.set(Data(#"{"userPuzzles":[]}"#.utf8), forKey: PlayerStore.storageKey)
        #expect(PlayerStore(defaults: d).generatedPuzzles.isEmpty)
    }
}
