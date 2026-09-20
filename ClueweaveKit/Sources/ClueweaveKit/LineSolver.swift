// Single-line constraint solver (port of src/engine/lineSolver.ts).

/// Feasibility predicate: can the runs `clue[clueIdx...]` be placed within
/// `state[pos...]` consistently with the cells already fixed in `state`?
/// DP over (pos, clueIdx), memoized.
public func lineFeasible(_ state: [Cell], _ clue: Clue) -> Bool {
    let n = state.count
    let k = clue.count
    // memo[pos * (k+1) + clueIdx]: -1 unknown, 0 false, 1 true
    var memo = [Int8](repeating: -1, count: (n + 1) * (k + 1))

    func fits(_ pos: Int, _ clueIdx: Int) -> Bool {
        if clueIdx == k {
            var i = pos
            while i < n {
                if state[i] == .filled { return false }
                i += 1
            }
            return true
        }
        if pos >= n { return false }

        let key = pos * (k + 1) + clueIdx
        if memo[key] != -1 { return memo[key] == 1 }

        var result = false
        let run = clue[clueIdx]

        // Option A: leave cell `pos` empty (only if it isn't a fixed FILLED).
        if state[pos] != .filled && fits(pos + 1, clueIdx) {
            result = true
        }

        // Option B: place the run starting at `pos`.
        if !result && pos + run <= n {
            var ok = true
            for i in pos..<(pos + run) where state[i] == .empty {
                ok = false
                break
            }
            let after = pos + run
            if ok && after < n && state[after] == .filled { ok = false }
            if ok {
                let nextPos = after < n ? after + 1 : after // skip the mandatory gap
                if fits(nextPos, clueIdx + 1) { result = true }
            }
        }

        memo[key] = result ? 1 : 0
        return result
    }

    return fits(0, 0)
}

/// Return a new line in which every cell FILLED in all valid completions is set
/// FILLED, every cell EMPTY in all valid completions is set EMPTY, and the rest
/// stay UNKNOWN. Returns `nil` if the line is infeasible.
public func solveLine(_ state: [Cell], _ clue: Clue) -> [Cell]? {
    guard lineFeasible(state, clue) else { return nil }
    let n = state.count
    var out = state
    for i in 0..<n where out[i] == .unknown {
        var tryFilled = state
        tryFilled[i] = .filled
        var tryEmpty = state
        tryEmpty[i] = .empty
        let canFill = lineFeasible(tryFilled, clue)
        let canEmpty = lineFeasible(tryEmpty, clue)
        if canFill && !canEmpty {
            out[i] = .filled
        } else if !canFill && canEmpty {
            out[i] = .empty
        }
    }
    return out
}
