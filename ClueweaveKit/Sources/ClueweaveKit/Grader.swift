// Difficulty grading by reasoning effort (port of src/engine/grader.ts).
//
// Every constant here is **product**, on the same footing as par times and share
// tokens: it must stay numerically identical to the web engine. Changing one
// means changing it in both repos and both test suites in the same change.

/// Effective-work cutoffs. A puzzle's `effectiveWork` (see below) is bucketed
/// into a tier by these thresholds. They were chosen by measuring every curated
/// puzzle on the unified work scale and placing the boundaries where the natural
/// gaps fall, so the tiers are monotonic in real solving effort.
///
///   effectiveWork < 25   → easy
///                 < 55   → medium
///                 < 80   → hard
///                 < 120  → expert   (shown as "Extra Hard")
///                 else   → max
///
/// The easy ceiling is deliberately set above every 5×5 in the library. A 5×5 is
/// 25 cells — small enough to hold entirely in your head — so it reads as easy to
/// a player no matter how many forced steps the solver logs getting there.
///
/// Each boundary sits in the middle of a real gap in the measured spread, not
/// hard against a puzzle's score, so a small future change to a bitmap can't flip
/// a tier by accident. The nearest puzzle to any cutoff is ~5 work units away.
private let tierCutoffs: [(ceiling: Double, tier: Difficulty)] = [
    (25, .easy),
    (55, .medium),
    (80, .hard),
    (120, .expert),
]

private func tierForEffort(_ effort: Double) -> Difficulty {
    for cutoff in tierCutoffs where effort < cutoff.ceiling { return cutoff.tier }
    return .max
}

/// Raw solving work, computed uniformly for every puzzle — line-solvable or not.
///
///   work = deductionSteps + longestLine × contradictionProofs + area / 4
///
/// `solveByLogic` runs the same line-then-depth-1-contradiction reasoning a
/// careful human uses, so the step count is a faithful proxy for effort. Each
/// what-if (contradiction) proof is a full sub-deduction, so it is weighted
/// heavily — but **how** heavily has to depend on the board. A what-if on a 5×5
/// means eyeballing a couple of placements in a five-cell line; the same proof
/// on a 15×15 is real work you have to hold in your head. Scaling by the longest
/// line keeps small puzzles honest (a flat weight used to shove tiny grids two
/// whole tiers up) while leaving the big contradiction puzzles where they were.
/// The area term is a small allowance for sheer bookkeeping — divided by four so
/// a big-but-trivial picture (e.g. a 10×10 that falls out in two sweeps) never
/// masquerades as difficult.
private func rawWork(_ rowClues: [Clue], _ colClues: [Clue], _ area: Int) -> Double {
    let result = solveByLogic(rowClues, colClues)
    let contradictions = result.steps.filter { $0.technique == .contradiction }.count
    let longestLine = Swift.max(rowClues.count, colClues.count)
    return Double(result.steps.count) + Double(longestLine * contradictions) + Double(area) / 4.0
}

/// How much a picture's shape *leaks* to a human that the blind solver can't use.
/// Symmetry and single-run patterning are genuine head-starts, so they discount
/// the work **proportionally** (never a hard cap — a hard puzzle stays hard, it
/// just eases toward the next tier down rather than snapping to it).
private func informationFactor(_ solution: [[Bool]]) -> Double {
    let s = detectSymmetry(solution)
    var factor = 1.0
    if s.horizontal && s.vertical {
        factor *= 0.55 // both mirror axes leak the most
    } else if s.horizontal || s.vertical {
        factor *= 0.7 // one axis
    } else if s.rotational {
        factor *= 0.55 // 180° rotation is as strong as two axes
    }
    if detectPatterned(solution) { factor *= 0.65 } // one solid run per line
    return factor
}

/// Grade from the clues alone (no grid). Used by the editor's quick read and by
/// tests. Without the solution grid we can't see symmetry or patterning, so this
/// is the *undiscounted* work tier — `gradeGrid` refines it with the whole-picture
/// information factor.
public func grade(_ rowClues: [Clue], _ colClues: [Clue]) -> Difficulty {
    let area = rowClues.count * colClues.count
    return tierForEffort(rawWork(rowClues, colClues, area))
}

/// Grade a full solution grid. This is the authoritative tier shown to the player:
/// unified solving work, discounted by the information the picture's shape gives a
/// human (symmetry, patterning). Size enters only through the small area term in
/// the work — a picture is not hard just for being large.
public func gradeGrid(_ solution: [[Bool]]) -> Difficulty {
    let clues = cluesForGrid(solution)
    let area = solution.count * (solution.first?.count ?? 0)
    let effort = rawWork(clues.rowClues, clues.colClues, area) * informationFactor(solution)
    return tierForEffort(effort)
}
