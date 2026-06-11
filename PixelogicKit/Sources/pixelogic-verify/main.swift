// Framework-free verification runner: mirrors the Swift Testing suites so the
// engine can be fully verified with bare Command Line Tools (no Xcode).
// Exits 1 on any failure.   Run:  swift run pixelogic-verify

import Foundation
import PixelogicKit

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
check(gradeGrid(letterA) == .hard, "symmetric contradiction caps at hard")
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
check(pixelogicScore(bestScores: ["e": 100, "x": 100], library: lib2) == 1600, "perfect = 1600")
check(pixelogicScore(bestScores: ["e": 100], library: lib2) == 200, "weighting 1/8")
let badged = [PuzzleMeta(id: "e", difficulty: .easy, weightMult: 0.5), PuzzleMeta(id: "x", difficulty: .expert)]
check(pixelogicScore(bestScores: ["e": 100, "x": 100], library: badged) == 1600, "badges keep 1600 ceiling")
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
check(store.pixelogicScore > 0, "pixelogic score rises")

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

// MARK: - Ads (none, ever)
print("AdReadiness:")
let ads = AdSlots.current()
check(AdPlacement.allCases.allSatisfy { !ads.hasAd(for: $0) }, "no placement has an ad")
check(!ads.interstitialAllowed(after: 1000), "no interstitials")

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
    check(gradeGrid(p.solution) == p.difficulty, "\(p.title): tier matches engine (\(p.difficulty.rawValue))")
    let lineSolvable = isLineSolvable(p.rowClues, p.colClues)
    switch p.difficulty {
    case .easy, .medium:
        check(lineSolvable, "\(p.title): line-solvable as befits its tier")
    case .expert, .max:
        check(!lineSolvable && !isSymmetric(p.solution), "\(p.title): top-tier rules hold")
    case .hard:
        break
    }
    check(p.rowClues.count == p.height && p.colClues.count == p.width, "\(p.title): clue dimensions")
    check(enumerateSolutions(p.rowClues, p.colClues, limit: 1).first == p.solution, "\(p.title): solver matches art")
}
check(puzzle(withID: "diamond")!.difficulty == .medium, "Diamond is Medium")
check(puzzle(withID: "static")!.difficulty == .max, "Static is MAX")
check(!puzzle(withID: "enigma")!.named && puzzle(withID: "cat")!.named, "name-hint flags")

print("\n\(checks) checks, \(failures) failures")
if failures > 0 {
    print("VERIFY FAIL")
    exit(1)
}
print("VERIFY OK")
