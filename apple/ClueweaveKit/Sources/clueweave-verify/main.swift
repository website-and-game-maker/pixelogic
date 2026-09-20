// Framework-free verification runner: mirrors the Swift Testing suites so the
// engine can be fully verified with bare Command Line Tools (no Xcode).
// Exits 1 on any failure.   Run:  swift run clueweave-verify

import Foundation
import ClueweaveKit

var failures = 0
var checks = 0

@MainActor
func check(_ cond: Bool, _ name: String) {
    checks += 1
    print("  \(cond ? "✓" : "✗") \(name)")
    if !cond { failures += 1 }
}

func grid(_ rows: [String]) -> [[Bool]] { bitmapToGrid(rows) }

// MARK: - Clues
print("Clues:")
check(cluesForLine([false, false, false]) == [], "empty line → []")
check(cluesForLine([true, true, true]) == [3], "full line → [3]")
check(cluesForLine([true, false, true, true]) == [1, 2], "runs encode in order")
let gc = cluesForGrid(grid(["#.#", "###"]))
check(gc.rowClues == [[1, 1], [3]] && gc.colClues == [[2], [1], [2]], "grid clues derive")

// MARK: - Line solver
print("LineSolver:")
check(solveLine([.unknown, .unknown, .unknown], [3]) == [.filled, .filled, .filled], "tight clue fills line")
check(solveLine([.unknown, .unknown], []) == [.empty, .empty], "zero clue crosses all")
let overlap = solveLine([.unknown, .unknown, .unknown, .unknown, .unknown], [3])
check(overlap?[2] == .filled && overlap?[0] == .unknown, "overlap forces centre only")
check(solveLine([.empty, .empty, .empty], [1]) == nil, "infeasible → nil")

// MARK: - Solver
print("Solver:")
let amb = cluesForGrid(grid(["#.", ".#"]))
check(countSolutionsDetailed(amb.rowClues, amb.colClues).count == 2, "checkerboard has 2 solutions")
check(!hasUniqueSolution(amb.rowClues, amb.colClues), "checkerboard not unique")
let uniq = cluesForGrid(grid(["##", "#."]))
check(hasUniqueSolution(uniq.rowClues, uniq.colClues), "L-shape unique")
check(enumerateSolutions(uniq.rowClues, uniq.colClues).first == grid(["##", "#."]), "enumerate returns picture")

// MARK: - Deduce
print("Deduce:")
let plus = puzzle(withID: "plus")!
let plusLogic = solveByLogic(plus.rowClues, plus.colClues)
check(plusLogic.solved, "plus solves by logic")
check(plusLogic.steps.allSatisfy { !$0.caption.isEmpty }, "every step has a caption")
let staticP = puzzle(withID: "static")!
let staticLogic = solveByLogic(staticP.rowClues, staticP.colClues)
check(staticLogic.solved, "static solves by logic")
check(staticLogic.steps.contains { $0.technique == .contradiction }, "static needs contradiction")

// MARK: - Symmetry & badges
print("Symmetry/Badges:")
check(detectSymmetry(grid(["#.#", "###", "..."])).horizontal, "horizontal mirror")
check(symmetryDetail(grid(["#.#", "...", "#.#"])) == "H+V", "H+V detail")
check(symmetryDetail(grid(["#..", "...", "..#"])) == "180°", "rotational detail")
check(symmetryDetail(grid(["#..", "#..", ".##"])) == nil, "asymmetric → nil")
check(detectPatterned(grid(["..#..", ".###.", "#####", ".###.", "..#.."])), "diamond patterned")
check(!detectPatterned(grid(["#####", "#...#", "#####"])), "frame not patterned")
let diamondBadges = puzzleBadges(solution: grid(["..#..", ".###.", "#####", ".###.", "..#.."]), named: true)
check(Set(diamondBadges.map(\.key)) == [.symmetric, .named, .patterned], "diamond collects 3 badges")
check(abs(badgeWeightMultiplier(diamondBadges) - 0.85 * 0.9 * 0.8) < 1e-10, "multipliers compose")

// MARK: - Grader
print("Grader:")
let letterA = grid([".###.", "#...#", "#####", "#...#", "#...#"])
let aClues = cluesForGrid(letterA)
check(!isLineSolvable(aClues.rowClues, aClues.colClues), "letter A needs contradictions")
// Playtested ground truth: Letter A is easy. 25 cells you can hold in your head,
// and a mirror axis that hands you half of it. A flat per-contradiction weight
// plus an easy ceiling below every 5×5 used to ship it as Hard.
check(gradeGrid(letterA) == .easy, "small symmetric contradiction picture is easy")
check(gradeGrid(puzzle(withID: "diamond")!.solution) == .medium, "patterned caps at medium")

// MARK: - Scoring
print("Scoring:")
check(parSeconds(.easy, area: 25) == 25, "easy par 1s/cell")
check(parSeconds(.max, area: 196) == 882, "max par 4.5s/cell")
check(puzzleScore(difficulty: .easy, area: 25, bestTimeMs: 25_000, assists: AssistTally()) == 100, "at-par clean = 100")
check(puzzleScore(difficulty: .medium, area: 100, bestTimeMs: 300_000, assists: AssistTally()) == 50, "2×par = 50")
var assists = AssistTally()
assists.checkSquare = 2
assists.checkLine = 1
assists.hint = 1
check(assists.penaltyTotal == 45, "penalties total 45")
var voided = AssistTally()
voided.voided = true
check(puzzleScore(difficulty: .easy, area: 25, bestTimeMs: 25_000, assists: voided) == 0, "voided = 0")
let lib2 = [PuzzleMeta(id: "e", difficulty: .easy), PuzzleMeta(id: "x", difficulty: .expert)]
check(clueweaveScore(bestScores: ["e": 100, "x": 100], library: lib2) == 1600, "perfect = 1600")
check(clueweaveScore(bestScores: ["e": 100], library: lib2) == 200, "weighting 1/8")
let badged = [PuzzleMeta(id: "e", difficulty: .easy, weightMult: 0.5), PuzzleMeta(id: "x", difficulty: .expert)]
check(clueweaveScore(bestScores: ["e": 100, "x": 100], library: badged) == 1600, "badges keep 1600 ceiling")
check(scoreTitle(1600) == "Grandmaster" && scoreTitle(0) == "Novice", "titles band")
check(Difficulty.max.checkBudget == 1 && Difficulty.easy.checkBudget == nil, "check budgets")

// MARK: - PlayerStore
print("PlayerStore:")
let suite = UserDefaults(suiteName: "verify.\(UUID().uuidString)")!
let store = PlayerStore(defaults: suite)
check(store.recordScore("heart", score: 70) == (70, true), "first score records")
check(store.recordScore("heart", score: 60) == (70, false), "lower score ignored")
check(store.recordScore("heart", score: 95) == (95, true), "higher score replaces")
check(store.recordBestTime("heart", elapsedMs: 9000) == (9000, true), "first time records")
check(store.recordBestTime("heart", elapsedMs: 12000) == (9000, false), "slower time ignored")
var st = store.settings
st.mistakeCheck = true
store.settings = st
store.markCompleted("smiley")
store.resetProgress()
check(!store.isCompleted("smiley") && store.bestScore(for: "smiley") == nil, "reset clears progress")
check(store.wasProgressReset, "reset sets disclosure flag")
check(store.settings.mistakeCheck, "reset keeps settings")
store.recordScore("plus", score: 100)
check(store.clueweaveScore > 0, "clueweave score rises")

// MARK: - GameSession (pure play model used by the apps)
print("GameSession:")
let session = GameSession(puzzle: puzzle(withID: "plus")!, now: { Date(timeIntervalSince1970: 0) })
session.toggle(2, 0)
check(session.marks[2][0] == .filled, "paint toggles a fill")
session.toggle(2, 0)
check(session.marks[2][0] == .unknown, "paint toggles back off")
session.mode = .cross
session.toggle(0, 0)
check(session.marks[0][0] == .empty, "cross mode crosses")
check(session.canUndo, "undo available")
session.undo()
check(session.marks[0][0] == .unknown, "undo restores")
session.redo()
check(session.marks[0][0] == .empty, "redo reapplies")

let s2 = GameSession(puzzle: puzzle(withID: "plus")!)
s2.setCell(0, 2, .filled) // row 0 clue [1] met
check(s2.applyAutoCross() > 0, "autoCross crosses leftover cells of a met line")
check(s2.marks[0][0] == .empty && s2.marks[0][4] == .empty, "autoCross crossed the right cells")

let maxSession = GameSession(puzzle: puzzle(withID: "obsidian")!)
check(maxSession.checkSquaresLeft == 1, "MAX allows a single square check")
check(maxSession.checkSquare(0, 0), "first square check allowed")
check(!maxSession.checkSquare(0, 1), "second square check denied at MAX")
check(maxSession.assists.checkSquare == 1, "denied check not charged")

let s3 = GameSession(puzzle: puzzle(withID: "plus")!)
check(s3.hint() != nil, "hint returns a forced cell")
check(s3.assists.hint == 1, "hint charged")
check(s3.checkBoard() == 0, "no mistakes to clear")
s3.fillOut()
check(s3.isSolved && s3.filledOut && s3.assists.voided, "fill-out completes + voids")
check(s3.currentScore == 0, "voided attempt scores 0")
s3.restart()
check(!s3.isSolved && s3.assists == AssistTally(), "restart wipes attempt state")

// MARK: - ShareCodec (web-compatible links)
print("ShareCodec:")
let art = grid(["#.", ".#"])
let token = encodePuzzle(art, title: "Tiny")
let decoded = try! decodePuzzle(token)
check(decoded.solution == art && decoded.title == "Tiny", "round-trips solution + title")
// Token produced by the WEB app for the same payload must decode identically
// (cross-platform guarantee): {"w":2,"h":2,"t":"Tiny","b":"1001"}
let webToken = "eyJ3IjoyLCJoIjoyLCJ0IjoiVGlueSIsImIiOiIxMDAxIn0"
let webDecoded = try! decodePuzzle(webToken)
check(webDecoded.solution == art && webDecoded.title == "Tiny", "decodes a web-generated token")
check((try? decodePuzzle("not-a-token")) == nil, "malformed token throws")

// MARK: - Share-token parsing (every import path the app accepts)
print("Share-token parsing:")
check(shareToken(fromUserInput: token) == token, "bare token passes through")
check(shareToken(fromUserInput: "https://website-and-game-maker.github.io/clueweave/#/p/\(token)") == token, "web URL form parses")
check(shareToken(fromUserInput: "clueweave://p/\(token)") == token, "clueweave:// form parses")
check(shareToken(fromUserInput: "  clueweave://p/\(token)\n") == token, "surrounding whitespace trimmed")
check(shareToken(fromUserInput: "https://example.com/nothing-here") == nil, "foreign URL rejected")
check(shareToken(fromUserInput: "not a token!!") == nil, "junk rejected")
check(shareToken(fromUserInput: "") == nil, "empty input rejected")
if let webRT = shareToken(fromUserInput: webShareURL(forToken: token).absoluteString) {
    let rt = try! decodePuzzle(webRT)
    check(rt.solution == art && rt.title == "Tiny", "share URL → token → puzzle round-trips")
} else {
    check(false, "share URL → token → puzzle round-trips")
}

// MARK: - In-progress attempts (quit the app, keep the board)
print("In-progress attempts:")
let ipStore = PlayerStore(defaults: UserDefaults(suiteName: "verify.ip.\(UUID().uuidString)")!)
var ipTally = AssistTally()
ipTally.hint = 1
let plusP = puzzle(withID: "plus")!
let ipSession = GameSession(puzzle: plusP)
ipSession.toggle(2, 0)
ipSession.toggle(2, 1)
let snapshotAttempt = InProgressAttempt(marks: ipSession.marks, elapsedMs: 12_000, assists: ipTally)
ipStore.saveInProgress(snapshotAttempt, for: "plus")
check(ipStore.inProgress(for: "plus") == snapshotAttempt, "attempt round-trips through the store")
let resumed = GameSession(puzzle: plusP)
resumed.restore(marks: ipStore.inProgress(for: "plus")!.grid, elapsedMs: 12_000, assists: ipTally)
check(resumed.marks[2][0] == .filled && resumed.marks[2][1] == .filled, "restored marks match")
check(resumed.elapsedMs == 12_000, "restored clock continues from the save")
check(resumed.assists.hint == 1 && resumed.assists.penaltyTotal == AssistTally.penaltyHint, "restored assists keep their penalty")
check(!resumed.canUndo, "history does not cross a relaunch")
resumed.restore(marks: [[.filled]], elapsedMs: 1, assists: AssistTally())
check(resumed.marks[2][0] == .filled, "dimension-mismatched restore is ignored")
ipStore.markCompleted("plus")
check(ipStore.inProgress(for: "plus") == nil, "completing clears the snapshot")
ipStore.saveInProgress(snapshotAttempt, for: "smiley")
ipStore.resetProgress()
check(ipStore.inProgress(for: "smiley") == nil, "reset clears snapshots")

// A v1 save written before in-progress snapshots existed must load losslessly.
let v1Blob = #"{"completed":["plus"],"bestTimes":{"plus":9000},"bestScores":{"plus":88},"assists":{},"userPuzzles":[],"settings":{"mistakeCheck":true,"showTimer":true,"clueStyle":"grey","autoCross":false},"tutorialSeen":true,"progressReset":false}"#
let v1Defaults = UserDefaults(suiteName: "verify.v1.\(UUID().uuidString)")!
v1Defaults.set(Data(v1Blob.utf8), forKey: PlayerStore.storageKey)
let migrated = PlayerStore(defaults: v1Defaults)
check(migrated.isCompleted("plus") && migrated.bestScore(for: "plus") == 88, "v1 save: progress survives the upgrade")
check(migrated.settings.mistakeCheck && migrated.tutorialSeen, "v1 save: settings & tutorial flag survive")

// Corrupt saves are stashed for recovery, never silently destroyed.
let corruptDefaults = UserDefaults(suiteName: "verify.corrupt.\(UUID().uuidString)")!
corruptDefaults.set(Data("{broken".utf8), forKey: PlayerStore.storageKey)
_ = PlayerStore(defaults: corruptDefaults)
check(corruptDefaults.data(forKey: PlayerStore.storageKey + ".corrupt") == Data("{broken".utf8), "corrupt save stashed, not destroyed")

// MARK: - Import dedupe
print("Import:")
let importStore = PlayerStore(defaults: UserDefaults(suiteName: "verify.import.\(UUID().uuidString)")!)
let firstID = importStore.importUserPuzzle(title: "Tiny", solution: art)
let secondID = importStore.importUserPuzzle(title: "Tiny again", solution: art)
check(firstID == secondID && importStore.userPuzzles.count == 1, "re-importing the same picture reuses it")
check(importStore.importUserPuzzle(title: "Other", solution: grid(["##", "##"])) != firstID, "different picture gets its own id")

// MARK: - Custom puzzles in the store
print("Custom puzzles:")
let customStore = PlayerStore(defaults: UserDefaults(suiteName: "verify.custom.\(UUID().uuidString)")!)
let mine = StoredPuzzle(id: "u-1", title: "Mine", solution: grid(["##", "#."]))
customStore.saveUserPuzzle(mine)
check(customStore.userPuzzles.count == 1, "custom saved")
customStore.saveUserPuzzle(StoredPuzzle(id: "u-1", title: "Renamed", solution: mine.solution))
check(customStore.userPuzzles.count == 1 && customStore.userPuzzles[0].title == "Renamed", "same id updates, no dupes")
check(customStore.userPuzzles[0].asPuzzle.difficulty == gradeGrid(mine.solution), "custom grades via engine")
customStore.resetProgress()
check(customStore.userPuzzles.count == 1, "reset keeps custom puzzles")
customStore.deleteUserPuzzles(ids: ["u-1"])
check(customStore.userPuzzles.isEmpty, "mass delete works")

// MARK: - Library share links
print("Library share links:")
check(libraryShareID(fromUserInput: "https://website-and-game-maker.github.io/clueweave/#/play/plus") == "plus", "library URL → id")
check(libraryShareID(fromUserInput: "  #/play/heart\n") == "heart", "trims + parses bare fragment")
check(libraryShareID(fromUserInput: webShareURL(forLibraryID: "smiley").absoluteString) == "smiley", "round-trips webShareURL(forLibraryID:)")
check(libraryShareID(fromUserInput: "clueweave://p/\(token)") == nil, "custom token link is not a library link")
check(libraryShareID(fromUserInput: "nonsense") == nil, "junk → nil")

// MARK: - Editing a custom puzzle drops its stale in-progress board
print("Edit invalidates stale resume:")
let editStore = PlayerStore(defaults: UserDefaults(suiteName: "verify.edit.\(UUID().uuidString)")!)
editStore.saveUserPuzzle(StoredPuzzle(id: "u-e", title: "Mine", solution: grid(["##", "#."])))
editStore.saveInProgress(InProgressAttempt(marks: [[.filled, .unknown], [.unknown, .unknown]], elapsedMs: 5, assists: AssistTally()), for: "u-e")
editStore.saveUserPuzzle(StoredPuzzle(id: "u-e", title: "Mine", solution: grid(["##", "#."]))) // same art
check(editStore.inProgress(for: "u-e") != nil, "same-art re-save keeps the in-progress board")
editStore.saveUserPuzzle(StoredPuzzle(id: "u-e", title: "Mine", solution: grid([".#", "##"]))) // changed art
check(editStore.inProgress(for: "u-e") == nil, "edited art drops the stale in-progress board")

// MARK: - Import uniqueness gate
print("Import uniqueness gate:")
check(sharedSolutionIsUnique(grid(["##", "#."])), "L-shape (unique) accepted")
check(!sharedSolutionIsUnique(grid(["#.", ".#"])), "checkerboard (2 solutions) refused")
check(!sharedSolutionIsUnique([]), "empty grid refused")
check(!sharedSolutionIsUnique([[true], [true, false]]), "ragged grid refused")
check(sharedSolutionIsUnique(puzzle(withID: "plus")!.solution), "a library puzzle is unique")

// MARK: - Corrupt custom-puzzle entry doesn't wipe the rest
print("Resilient custom-puzzle decode:")
// One valid entry + one missing its `solution` field; only the bad one drops.
let mixedBlob = #"{"userPuzzles":[{"id":"good","title":"Good","solution":[[true,false],[false,true]]},{"id":"bad","title":"Broken"}]}"#
let mixedDefaults = UserDefaults(suiteName: "verify.mixed.\(UUID().uuidString)")!
mixedDefaults.set(Data(mixedBlob.utf8), forKey: PlayerStore.storageKey)
let mixedStore = PlayerStore(defaults: mixedDefaults)
check(mixedStore.userPuzzles.count == 1 && mixedStore.userPuzzles[0].id == "good", "one corrupt custom entry dropped, the good one survives")

// MARK: - Ads (none, ever)
print("AdReadiness:")
let ads = AdSlots.current()
check(AdPlacement.allCases.allSatisfy { !ads.hasAd(for: $0) }, "no placement has an ad")
check(!ads.interstitialAllowed(after: 1000), "no interstitials")

// MARK: - Generator
print("Generator:")
var genRNG = SeededGenerator(seed: 99)
for size in [5, 7, 8, 10] {
    guard let g = generatePuzzle(size: size, using: &genRNG) else { check(false, "generated \(size)x\(size)"); continue }
    check(g.width == size && g.height == size, "gen \(size): correct size")
    check(hasUniqueSolution(g.rowClues, g.colClues), "gen \(size): unique")
    check(isLogicSolvable(g.rowClues, g.colClues), "gen \(size): logic-solvable")
    check(gradeGrid(g.solution) == g.difficulty, "gen \(size): tier matches engine")
    check(!g.named && g.id.hasPrefix("g-"), "gen \(size): untitled g- id, no name-hint")
    let f = g.solution.flatMap { $0 }.filter { $0 }.count
    check(f >= size && f <= size * size - size, "gen \(size): not degenerate")
}
var detA = SeededGenerator(seed: 5), detB = SeededGenerator(seed: 5)
check(generatePuzzle(size: 8, using: &detA)?.solution == generatePuzzle(size: 8, using: &detB)?.solution, "seeded generation is deterministic")
check(generatePuzzle(size: 4, using: &genRNG) == nil && generatePuzzle(size: 16, using: &genRNG) == nil, "out-of-range sizes refused")

// MARK: - Generated puzzles in the store
print("Generated store:")
let gStore = PlayerStore(defaults: UserDefaults(suiteName: "verify.gen.\(UUID().uuidString)")!)
let gArt = grid(["##", "#."])
let gid1 = gStore.saveGeneratedPuzzle(title: "A", solution: gArt)
let gid2 = gStore.saveGeneratedPuzzle(title: "B", solution: gArt)
check(gid1.hasPrefix("g-") && gid1 == gid2 && gStore.generatedPuzzles.count == 1, "generated save dedups identical art")
gStore.resetProgress()
check(gStore.generatedPuzzles.count == 1, "generated puzzles survive reset")
gStore.deleteGeneratedPuzzles(ids: [gid1])
check(gStore.generatedPuzzles.isEmpty, "generated delete works")
let gOld = PlayerStore(defaults: { let d = UserDefaults(suiteName: "verify.gold.\(UUID().uuidString)")!; d.set(Data("{\"userPuzzles\":[]}".utf8), forKey: PlayerStore.storageKey); return d }())
check(gOld.generatedPuzzles.isEmpty, "older save without the key decodes to empty")

// MARK: - Library invariants (the shipping guarantee)
print("Library (32 puzzles × invariants):")
check(library.count >= 30, "healthy library size (\(library.count))")
check(Set(library.map(\.id)).count == library.count, "unique ids")
for tier in Difficulty.ordered {
    check(!puzzles(in: tier).isEmpty, "tier \(tier.displayName) populated (\(puzzles(in: tier).count))")
}
for p in library {
    let count = countSolutionsDetailed(p.rowClues, p.colClues, limit: 2)
    check(count.count == 1 && !count.capped, "\(p.title): provably unique")
    check(isLogicSolvable(p.rowClues, p.colClues), "\(p.title): logic-solvable")
    check(
        gradeGrid(p.solution) == p.difficulty,
        "\(p.title): tier matches engine (stored \(p.difficulty.rawValue), graded \(gradeGrid(p.solution).rawValue))"
    )
    // NB: there are deliberately no technique-based tier invariants here any more.
    // They used to assert "easy/medium ⇒ line-solvable" and "expert/max ⇒ needs
    // contradictions AND is asymmetric", which described the old grader: tiers
    // were named after the hardest *technique* required. The grader now measures
    // total solving *effort*, and those two ideas genuinely come apart —
    //   • Letter A needs a what-if but is a 25-cell mirror image, so it is Easy;
    //   • Pine Tree is line-solvable and symmetric but 15×15 of sustained work,
    //     so it is Extra Hard.
    // Tier correctness is fully covered by the `gradeGrid == stored` check above;
    // re-asserting the old technique rules would only pin the bug back in place.
    check(p.rowClues.count == p.height && p.colClues.count == p.width, "\(p.title): clue dimensions")
    check(enumerateSolutions(p.rowClues, p.colClues, limit: 1).first == p.solution, "\(p.title): solver matches art")
}
check(puzzle(withID: "static")!.difficulty == .max, "Static is MAX")
// Playtested anchors — these two are how a human actually rates them, and both
// were mis-tiered by the old sweep-counting grader (A shipped Hard, Cat Medium).
check(puzzle(withID: "letter-a")!.difficulty == .easy, "Letter A is Easy")
check(puzzle(withID: "cat")!.difficulty == .hard, "Cat is Hard")
check(!puzzle(withID: "enigma")!.named && puzzle(withID: "cat")!.named, "name-hint flags")

// MARK: - Progression (docs/progression-model.md §8 test obligations)
print("Progression:")

func pz(_ id: String, _ d: Difficulty, named: Bool = false) -> Puzzle {
    // 3×3 with no symmetry and no single-run lines, so it earns no badges.
    Puzzle(id: id, title: id, solution: grid(["#.#", "...", "#.."]), difficulty: d, named: named)
}
// easy×2, medium×2, hard×1 — deliberately shuffled so tier-major sorting shows.
let plib = [pz("m1", .medium), pz("e1", .easy), pz("h1", .hard), pz("e2", .easy), pz("m2", .medium)]
let defSettings = ProgressionSettings()
var pstate = ProgressionState()

// 1. curriculum order
check(curriculumOrder(plib).map(\.id) == ["e1", "e2", "m1", "m2", "h1"], "curriculum is tier-major, stable")
check(curriculumNeighbour(plib, id: "e1", offset: -1) == nil, "no wrap before the first puzzle")
check(curriculumNeighbour(plib, id: "h1", offset: 1) == nil, "no wrap after the last puzzle")
check(curriculumNeighbour(plib, id: "e1", offset: 1) == "e2", "curriculum next")

// 2-3. signal classification + precedence. easy par = 9 × 1.0s = 9000ms; fast ≤ 5400ms.
func outcome(
    solved: Bool = true, voided: Bool = false, assists: AssistTally = AssistTally(), ms: Int
) -> AttemptOutcome {
    AttemptOutcome(solved: solved, voided: voided, assists: assists,
                   elapsedMs: ms, difficulty: .easy, area: 9)
}
check(classifySignal(outcome(ms: 1000), defSettings) == .fastClean, "clean + fast → fastClean")
check(classifySignal(outcome(ms: 8000), defSettings) == .normal, "clean but slow → normal")
var oneCheck = AssistTally(); oneCheck.checkSquare = 1
check(classifySignal(outcome(assists: oneCheck, ms: 1000), defSettings) == .normal,
      "fastClean requires a zero assist penalty")
check(classifySignal(outcome(voided: true, ms: 1000), defSettings) == .gaveUp, "giving up outranks being fast")
var boardCheck = AssistTally(); boardCheck.checkBoard = 1
check(classifySignal(outcome(assists: boardCheck, ms: 1000), defSettings) == .struggled,
      "a board check outranks being fast")
var heavyHints = AssistTally(); heavyHints.hint = hintStruggleThreshold
check(classifySignal(outcome(assists: heavyHints, ms: 8000), defSettings) == .struggled, "heavy hints → struggled")
var noHintStruggle = ProgressionSettings(); noHintStruggle.hintsCountAsStruggle = false
check(classifySignal(outcome(assists: heavyHints, ms: 8000), noHintStruggle) == .normal,
      "hints ignored when the setting is off")
check(classifySignal(outcome(solved: false, ms: 1000), defSettings) == .abandoned, "unfinished → abandoned")

// 4. promotion needs consecutive fast solves; a normal in between resets it
pstate = applySignal(.fastClean, ProgressionState(), defSettings, plib, [])
check(pstate.workingTier == .easy && pstate.fastStreak == 1, "one fast solve does not promote")
pstate = applySignal(.fastClean, pstate, defSettings, plib, [])
check(pstate.workingTier == .medium && pstate.fastStreak == 0, "two fast solves promote")
var broken = applySignal(.fastClean, ProgressionState(), defSettings, plib, [])
broken = applySignal(.normal, broken, defSettings, plib, [])
broken = applySignal(.fastClean, broken, defSettings, plib, [])
check(broken.workingTier == .easy, "a normal solve breaks the fast streak")

// 5. demotion needs consecutive struggles
var hardState = ProgressionState(); hardState.workingTier = .hard
var dem = applySignal(.gaveUp, hardState, defSettings, plib, [])
check(dem.workingTier == .hard, "a single give-up holds the tier")
dem = applySignal(.gaveUp, dem, defSettings, plib, [])
check(dem.workingTier == .medium, "a second give-up demotes")

// 6. canDemote is false when everything below is cleared
let clearedBelow: Set<String> = ["e1", "e2", "m1", "m2"]
check(!canDemote(.hard, plib, clearedBelow), "cannot demote into a fully cleared run")
check(canDemote(.hard, plib, ["m1", "m2"]), "can demote when only two tiers down has work")
check(!canDemote(.easy, plib, []), "cannot demote below the lowest tier")
var held = applySignal(.gaveUp, hardState, defSettings, plib, clearedBelow)
held = applySignal(.gaveUp, held, defSettings, plib, clearedBelow)
check(held.workingTier == .hard, "holds position when there is nothing useful below")

// 7. autoAdjustDifficulty off records streaks but never moves the tier
var noAdjust = ProgressionSettings(); noAdjust.autoAdjustDifficulty = false
var frozen = applySignal(.fastClean, ProgressionState(), noAdjust, plib, [])
frozen = applySignal(.fastClean, frozen, noAdjust, plib, [])
check(frozen.workingTier == .easy && frozen.fastStreak == 2, "auto-adjust off freezes the tier")

// 8. recommendation walks the tier, then up, then down
var medState = ProgressionState(); medState.workingTier = .medium
check(recommend(medState, plib, [], [:])?.puzzleID == "m1", "recommends within the working tier")
check(recommend(medState, plib, ["m1", "m2"], [:])?.puzzleID == "h1", "walks upward when the tier is done")
check(recommend(medState, plib, ["m1", "m2", "h1"], [:])?.puzzleID == "e1", "walks down only as a last resort")

// 9. best improvement respects tier weight × badge multiplier
let allDone = Set(plib.map(\.id))
check(recommend(medState, plib, allDone, ["e1": 0, "e2": 100, "m1": 100, "m2": 100, "h1": 50])?.puzzleID == "h1",
      "best improvement weighs tier, not the raw gap")
let badgeLib = [pz("plain", .hard), pz("badged", .hard, named: true)]
check(recommend(medState, badgeLib, ["plain", "badged"], ["plain": 40, "badged": 40])?.puzzleID == "plain",
      "best improvement weighs badge multipliers")

// 10. spam guard degrades smart next to plain curriculum order; a solve clears it
check(smartNextTarget(medState, currentPuzzleID: "e1", defSettings, plib, [], [:])?.puzzleID == "m1",
      "smart next recommends under the threshold")
var spammed = medState; spammed.spamCount = spamThreshold
check(smartNextTarget(spammed, currentPuzzleID: "e1", defSettings, plib, [], [:])?.puzzleID == "e2",
      "spam guard degrades to plain curriculum next")
var smartOff = ProgressionSettings(); smartOff.smartNext = false
check(smartNextTarget(medState, currentPuzzleID: "e1", smartOff, plib, [], [:])?.puzzleID == "e2",
      "smart next off behaves as plain next")
check(smartNextTarget(medState, currentPuzzleID: "h1", smartOff, plib, [], [:]) == nil,
      "plain next has nowhere to go past the last puzzle")
check(applySignal(.normal, spammed, defSettings, plib, []).spamCount == 0, "a finished attempt clears the spam guard")
check(applySignal(.abandoned, spammed, defSettings, plib, []).spamCount == spamThreshold,
      "abandoning does not clear the spam guard")

// 11. sensitivity constants
check(FastSensitivity.relaxed.factor == 0.5 && FastSensitivity.relaxed.streak == 3, "relaxed tuning")
check(FastSensitivity.normal.factor == 0.6 && FastSensitivity.normal.streak == 2, "normal fast tuning")
check(FastSensitivity.eager.factor == 0.75 && FastSensitivity.eager.streak == 2, "eager tuning")
check(StruggleSensitivity.forgiving.streak == 3 && StruggleSensitivity.normal.streak == 2
        && StruggleSensitivity.quick.streak == 1, "struggle tuning")

// 12. never recommend the puzzle you are already on
check(smartNextTarget(medState, currentPuzzleID: "m1", defSettings, plib, [], [:])?.puzzleID == "m2",
      "smart next never returns the current puzzle")
check(smartNextTarget(medState, currentPuzzleID: "m1", defSettings, plib, ["m2"], [:])?.puzzleID == "h1",
      "moves on when the current puzzle is the only one left at the tier")
check(recommend(medState, plib, allDone, ["e1": 0, "e2": 100, "m1": 100, "m2": 100, "h1": 50],
                excludeID: "h1")?.puzzleID == "e1",
      "excludeID applies to the best-improvement branch too")

// Persistence tolerance: a corrupt progression block must not poison the save.
let junk = Data(#"{"completed":["plus"],"progression":{"workingTier":"nonsense","fastStreak":"x"}}"#.utf8)
if let decoded = try? JSONDecoder().decode(SaveData.self, from: junk) {
    check(decoded.completed == ["plus"], "corrupt progression keeps the rest of the save")
    check(decoded.progression.workingTier == .easy && decoded.progression.fastStreak == 0,
          "corrupt progression falls back to defaults")
} else {
    check(false, "save with a corrupt progression block still decodes")
}

// MARK: - Deep links (widgets and complications build these; the apps parse them)
print("DeepLink:")

func roundTrips(_ link: ClueweaveLink) -> Bool { parseClueweaveLink(link.url) == link }

check(roundTrips(.home), "home link round-trips")
check(roundTrips(.recommended), "recommended link round-trips")
check(Difficulty.allCases.allSatisfy { roundTrips(.tier($0)) }, "every tier link round-trips")
check(roundTrips(.resume("u-1a2b3c4d")), "resume link round-trips")
check(roundTrips(.puzzle("plus")), "puzzle link round-trips")
check(ClueweaveLink.tier(.expert).string == "clueweave://tier/expert",
      "tier links use the raw value, not the display name")
check(parseClueweaveLink("clueweave://TIER/Hard") == .tier(.hard), "link parsing is case-insensitive")
check(parseClueweaveLink("clueweave://tier/legendary") == nil, "an unknown tier is refused")
check(parseClueweaveLink("clueweave://resume/") == nil, "resume with no id is refused")
check(parseClueweaveLink("https://example.com/") == nil, "an unrelated URL is refused")
// The pre-existing share forms must keep working through the same front door.
let sampleToken = encodePuzzle(grid(["#.", ".#"]), title: "Two")
check(parseClueweaveLink("clueweave://p/\(sampleToken)") == .share(sampleToken),
      "clueweave://p/<token> still parses as a share")
check(parseClueweaveLink(webShareURL(forToken: sampleToken).absoluteString) == .share(sampleToken),
      "the canonical web URL still parses as a share")

// MARK: - Widget snapshot
print("WidgetSnapshot:")

let wsSolution = grid(["#.#", "...", "#.."])   // 3 filled cells
var wsMarks: Grid = Array(repeating: Array(repeating: Cell.unknown, count: 3), count: 3)
check(solveProgress(marks: wsMarks, solution: wsSolution) == (0, 3), "an untouched board is 0 of 3")
wsMarks[0][0] = .filled
wsMarks[1][1] = .filled                         // a wrong fill
wsMarks[0][1] = .empty                          // a cross
check(solveProgress(marks: wsMarks, solution: wsSolution) == (1, 3),
      "only correctly filled cells count — crosses and mistakes do not")
wsMarks[0][2] = .filled
wsMarks[2][0] = .filled
check(solveProgress(marks: wsMarks, solution: wsSolution) == (3, 3),
      "progress reaches exactly 3 of 3 on a solved picture")

let preview = BoardPreview(marks: wsMarks)
check(preview.width == 3 && preview.height == 3 && preview.cells.count == 9, "preview is w×h chars")
check(preview.grid == wsMarks, "preview round-trips the marks")
check(BoardPreview(width: 3, height: 3, cells: "").cell(2, 2) == .unknown,
      "a truncated preview reads as unknown, never a crash")

// tierSuggestion: next unsolved in curriculum order, then most score left to win
check(tierSuggestion(.easy, plib, [], [:])?.id == "e1", "tier suggestion starts at the first unsolved")
check(tierSuggestion(.easy, plib, ["e1"], [:])?.id == "e2", "tier suggestion walks the tier")
check(tierSuggestion(.easy, plib, ["e1", "e2"], ["e1": 100, "e2": 40])?.id == "e2",
      "a finished tier suggests the puzzle with the most score left to win")
check(tierSuggestion(.easy, plib, ["e1", "e2"], [:])?.id == "e1",
      "ties in a finished tier keep the earlier curriculum index")
check(tierSuggestion(.max, plib, [], [:]) == nil, "an empty tier suggests nothing")

let wsSnap = makeWidgetSnapshot(
    library: plib,
    completed: ["e1"],
    bestScores: ["e1": 80],
    progression: ProgressionState(),
    continueFrom: ContinueSource(puzzle: pz("m1", .medium), marks: wsMarks, elapsedMs: 42_000),
    score: 1234
)
check(wsSnap.solved == 1 && wsSnap.total == 5, "snapshot counts the library")
check(wsSnap.tiers.map(\.tier) == [.easy, .medium, .hard], "snapshot keeps only non-empty tiers, in order")
check(wsSnap.tier(.easy)?.solved == 1 && wsSnap.tier(.easy)?.total == 2, "per-tier counts")
check(wsSnap.tier(.easy)?.suggestionID == "e2", "per-tier suggestion rides along")
check(wsSnap.continueEntry?.puzzleID == "m1" && wsSnap.continueEntry?.fraction == 1.0,
      "the continue entry carries its own progress")
check(wsSnap.recommendation?.puzzleID != "m1",
      "the recommendation never points at the board you are already on")
check(wsSnap.primaryLink == .resume("m1"), "a single-tap complication resumes when there is a board")
check(WidgetSnapshot(recommendation: RecommendationSnapshot(
        puzzleID: "e1", title: "E1", difficulty: .easy, reason: "x")).primaryLink == .puzzle("e1"),
      "with no board it opens what to play next")
check(WidgetSnapshot().primaryLink == .home, "with neither it just opens the app")

// Encoding must survive a round trip, and a junk/partial snapshot must still render.
if let enc = try? JSONEncoder().encode(wsSnap),
   let dec = try? JSONDecoder().decode(WidgetSnapshot.self, from: enc) {
    check(dec == wsSnap, "snapshot round-trips through JSON")
} else {
    check(false, "snapshot round-trips through JSON")
}
let partial = Data(#"{"solved":3,"workingTier":"nonsense","tiers":"junk"}"#.utf8)
if let dec = try? JSONDecoder().decode(WidgetSnapshot.self, from: partial) {
    check(dec.solved == 3 && dec.workingTier == .easy && dec.tiers.isEmpty,
          "a partial snapshot decodes field-by-field instead of blanking the widget")
} else {
    check(false, "a partial snapshot still decodes")
}

// MARK: - Live Activity content state
print("LiveActivity:")

let laStart = Date(timeIntervalSince1970: 1_000_000)
let running = PuzzleActivityState(
    correct: 2, totalFilled: 8, runningSince: laStart, elapsedMs: 30_000, headline: "Hard")
check(running.fraction == 0.25, "activity fraction is correct-over-filled")
check(running.totalElapsedMs(at: laStart.addingTimeInterval(5)) == 35_000,
      "elapsed folds banked time into the running stretch")
check(running.timerStart == laStart.addingTimeInterval(-30),
      "the timer is anchored back by the banked time so a resume shows the true total")
let paused = PuzzleActivityState(correct: 2, totalFilled: 8, runningSince: nil, elapsedMs: 30_000)
check(paused.totalElapsedMs(at: laStart.addingTimeInterval(600)) == 30_000, "a paused clock does not drift")
check(paused.timerStart == nil, "a paused activity shows a frozen number, not a lying timer")
let won = PuzzleActivityState(
    correct: 8, totalFilled: 8, runningSince: laStart, elapsedMs: 90_000, isSolved: true)
check(won.fraction == 1.0 && won.totalElapsedMs(at: .distantFuture) == 90_000 && won.timerStart == nil,
      "a solved activity freezes at its final time")
check(PuzzleActivityState(correct: 3, totalFilled: 0, elapsedMs: 0).fraction == 0,
      "an empty picture can't divide by zero")

// MARK: - App Group migration (widgets run in another process)
print("AppGroup:")

let suiteA = "clueweave.verify.local.\(UUID().uuidString)"
let suiteB = "clueweave.verify.group.\(UUID().uuidString)"
if let local = UserDefaults(suiteName: suiteA), let shared = UserDefaults(suiteName: suiteB) {
    // A player upgrading straight from the pre-rebrand build: old key, old store.
    var seed = SaveData()
    seed.completed = ["plus"]
    local.set(try! JSONEncoder().encode(seed), forKey: "pixelogic.save.v1")

    let store = PlayerStore(defaults: shared, migratingFrom: [local])
    check(store.isCompleted("plus"), "a pre-rebrand app-local save survives the move to the App Group")
    check(shared.data(forKey: PlayerStore.storageKey) != nil, "the save now lives in the shared suite")
    check(local.data(forKey: "pixelogic.save.v1") == nil, "the old location is cleared, so it migrates once")

    // A save already in the shared suite must win over anything app-local.
    var newer = SaveData()
    newer.completed = ["heart"]
    shared.set(try! JSONEncoder().encode(newer), forKey: PlayerStore.storageKey)
    local.set(try! JSONEncoder().encode(seed), forKey: PlayerStore.storageKey)
    let store2 = PlayerStore(defaults: shared, migratingFrom: [local])
    check(store2.isCompleted("heart") && !store2.isCompleted("plus"),
          "the shared save wins — migration never overwrites newer progress")

    // Snapshot publishing: what the widgets will actually read.
    let store3 = PlayerStore(defaults: shared, migratingFrom: [])
    store3.saveInProgress(
        InProgressAttempt(marks: wsMarks, elapsedMs: 5_000, assists: AssistTally(),
                          updatedAt: Date(timeIntervalSince1970: 10)),
        for: "older")
    store3.saveInProgress(
        InProgressAttempt(marks: wsMarks, elapsedMs: 9_000, assists: AssistTally(),
                          updatedAt: Date(timeIntervalSince1970: 20)),
        for: "newer")
    let picked = store3.latestContinue(resolve: { pz($0, .medium) })
    check(picked?.puzzle.id == "newer", "continue offers the most recently saved board")
    check(store3.latestContinue(resolve: { _ in nil }) == nil,
          "a saved board whose puzzle is gone is not offered")
    store3.publishWidgetSnapshot(resolve: { id in puzzle(withID: id) ?? pz(id, .medium) })
    check(SnapshotStore.read(from: shared)?.continueEntry?.puzzleID == "newer",
          "publishing writes a snapshot the widget process can read")

    UserDefaults.standard.removePersistentDomain(forName: suiteA)
    UserDefaults.standard.removePersistentDomain(forName: suiteB)
} else {
    check(false, "test suites available for the App Group checks")
}

print("\n\(checks) checks, \(failures) failures")
if failures > 0 {
    print("VERIFY FAIL")
    exit(1)
}
print("VERIFY OK")
