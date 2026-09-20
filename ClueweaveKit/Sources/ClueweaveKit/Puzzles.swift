// Curated puzzle library (port of src/engine/puzzles.ts). Difficulties are
// baked in for instant startup; the test suite re-derives every one with
// `gradeGrid` and fails if any drifts from the engine's judgement.

private struct Entry {
    let id: String
    let title: String
    let difficulty: Difficulty
    let bitmap: [String]
    var note: String? = nil
}

/// Titles that deliberately do NOT describe their picture; everything else
/// earns the Name-hint badge.
private let abstractIDs: Set<String> = [
    "static", "cipher", "labyrinth", "riddle", "enigma", "obsidian", "leviathan", "nebula",
]

private let entries: [Entry] = [
    // ---------- Easy ----------
    Entry(id: "plus", title: "Plus", difficulty: .easy,
          bitmap: ["..#..", "..#..", "#####", "..#..", "..#.."]),
    Entry(id: "smiley", title: "Smiley", difficulty: .easy,
          bitmap: [".###.", "#.#.#", "#####", "#.#.#", ".###."]),
    Entry(id: "house", title: "House", difficulty: .easy,
          bitmap: ["..#..", ".###.", "#####", "#.#.#", "#.#.#"]),
    Entry(id: "tee", title: "Letter T", difficulty: .easy,
          bitmap: ["#####", "..#..", "..#..", "..#..", "..#.."]),
    Entry(id: "frame", title: "Frame", difficulty: .easy,
          bitmap: ["#####", "#...#", "#...#", "#...#", "#####"]),

    // ---------- Medium ----------
    Entry(id: "heart-s", title: "Little Heart", difficulty: .easy,
          bitmap: [".#.#.", "#####", "#####", ".###.", "..#.."]),
    Entry(id: "gem", title: "Gem", difficulty: .easy,
          bitmap: ["..#..", ".###.", "#####", ".###.", "..#.."]),
    Entry(id: "arrow", title: "Arrow", difficulty: .easy,
          bitmap: ["..#..", ".###.", "#.#.#", "..#..", "..#.."]),
    Entry(id: "heart", title: "Heart", difficulty: .medium,
          bitmap: [
            ".##....##.", "####..####", "##########", "##########", "##########",
            ".########.", "..######..", "...####...", "....##....", "..........",
          ]),
    Entry(id: "mushroom", title: "Mushroom", difficulty: .hard,
          bitmap: [
            "...###....", "..#####...", ".#######..", "#########.", "..#.#.#...",
            "...###....", "..#####...", "...###....", "...###....", "..#####...",
          ],
          note: "A woodland toadstool — domed cap, gills under the rim, and a ringed stem."),
    Entry(id: "cup", title: "Coffee Cup", difficulty: .hard,
          bitmap: [
            "..........", ".#######..", ".#.....#.#", ".#.....###", ".#.....#.#",
            ".#.....#..", ".#######..", "..#####...", "..........", ".#######..",
          ]),
    Entry(id: "balloon", title: "Balloon", difficulty: .medium,
          bitmap: [
            "...####...", "..######..", ".########.", ".########.", ".########.",
            "..######..", "...####...", "....##....", "....##....", "....##....",
          ]),
    Entry(id: "key", title: "Key", difficulty: .medium,
          bitmap: [
            ".####.....", ".#..#.....", ".#..#.....", ".####.....", "..##......",
            "..##......", "..###.....", "..##......", "..###.....", "..##......",
          ]),
    Entry(id: "umbrella", title: "Umbrella", difficulty: .medium,
          bitmap: [
            "..........", "...####...", "..######..", ".########.", "##########",
            "....#.....", "....#.....", "....#.....", "...##.....", "..##......",
          ]),
    Entry(id: "tree", title: "Pine Tree", difficulty: .expert,
          bitmap: [
            ".......#.......", "......###......", "......###......", ".....#####.....",
            ".....#####.....", "....#######....", "....#######....", "...#########...",
            "...#########...", "..###########..", "..###########..", ".#############.",
            ".......#.......", ".......#.......", ".....#####.....",
          ]),
    Entry(id: "snowman", title: "Snowman", difficulty: .expert,
          bitmap: [
            "......###......", ".....#####.....", ".....#.#.#.....", ".....#####.....",
            "......#.#......", "......###......", ".....#####.....", "....#######....",
            "....#######....", "....#######....", "...#########...", "...#########...",
            "...#########...", "....#######....", ".....#####.....",
          ]),
    Entry(id: "cat", title: "Cat", difficulty: .hard,
          bitmap: [
            "#........#", "##......##", ".########.", ".#.####.#.", ".########.",
            ".########.", ".########.", ".#######..", ".#######.#", ".######.##",
          ],
          note: "A cat sitting upright — pointy ears, two eyes, and a tail curling to the right."),
    Entry(id: "diamond", title: "Diamond", difficulty: .medium,
          bitmap: [
            ".......#.......", "......###......", ".....#####.....", "....#######....",
            "...#########...", "..###########..", ".#############.", "###############",
            ".#############.", "..###########..", "...#########...", "....#######....",
            ".....#####.....", "......###......", ".......#.......",
          ]),

    // ---------- Hard ----------
    Entry(id: "ghost", title: "Ghost", difficulty: .hard,
          bitmap: [
            "....##....", "...####...", "..######..", "..#.###...", "..######..",
            "...#####..", "....####..", "...###....", "..##......", ".#........",
          ],
          note: "A drifting wisp — hooded head, one eye, and a tail trailing off behind it."),
    Entry(id: "note", title: "Music Note", difficulty: .hard,
          bitmap: [
            "......##.....", "......####...", "......#.###..", "......#.####.",
            "......#..###.", "......#..##..", "......#..#...", "......#......",
            "......#......", "....###......", "..#####......", ".#####.......",
            ".###.........",
          ],
          note: "An eighth note — slanted head, tall stem, and the flag curling off the top."),
    Entry(id: "bird", title: "Bird", difficulty: .hard,
          bitmap: [
            "..........", ".##.......", ".####.....", "..######..", ".########.",
            "..######.#", "...####.##", "....##....", "....#.....", "..........",
          ]),
    Entry(id: "heart-l", title: "Big Heart", difficulty: .expert,
          bitmap: [
            "...###...###...", "..#####.#####..", ".#############.", ".#############.",
            ".#############.", ".#############.", "..###########..", "...#########...",
            "....#######....", ".....#####.....", "......###......", ".......#.......",
            "...............", "...............", "...............",
          ]),
    Entry(id: "anchor", title: "Anchor", difficulty: .expert,
          bitmap: [
            ".......#.......", "......#.#......", ".......#.......", ".....#####.....",
            ".......#.......", ".......#.......", ".......#.......", ".......#.......",
            "#......#......#", "#......#......#", "##.....#.....##", ".##...###...##.",
            "..###########..", "....#######....", ".....#####.....",
          ]),
    Entry(id: "letter-a", title: "Letter A", difficulty: .easy,
          bitmap: [".###.", "#...#", "#####", "#...#", "#...#"]),

    // ---------- Extra Hard (need contradiction / hypothesis reasoning) ----------
    Entry(id: "cipher", title: "Cipher", difficulty: .expert,
          bitmap: [
            "..##..#.##", "#.......##", "##...##.#.", "###.....#.", "....#.#..#",
            ".##.##.#.#", ".##.###...", "#.#..###.#", "#........#", ".....#....",
          ],
          note: "Named because the grid reads like rows of an encrypted message — only logic decodes it."),
    Entry(id: "riddle", title: "Riddle", difficulty: .expert,
          bitmap: [
            "#..#.#..#.", ".##..##.##", "..#.#.###.", ".#.#....#.", ".###..#..#",
            "..#.##..#.", "...###.##.", "....##....", ".##.##....", "###.#.####",
          ],
          note: "There's no obvious shape — the puzzle itself is the riddle."),
    Entry(id: "enigma", title: "Enigma", difficulty: .max,
          bitmap: [
            "#.....##.#..#", "##.##.##....#", "..#.#.#..##.#", "##.#.#.#..#..",
            "#.#..#..##..#", "##..##...##.#", "#####...#...#", "##.##...#.#..",
            "..#.###.####.", ".###..#...#..", "#.#....##.###", "##.##.##...#.",
            "##.#..###.#..",
          ],
          note: "Named for the Enigma machine — an inscrutable cipher you crack one forced cell at a time."),

    // ---------- MAX ----------
    Entry(id: "static", title: "Static", difficulty: .max,
          bitmap: [
            "...#......", ".##...##.#", "...##.....", "####.....#", ".##.##.###",
            "##..##....", ".....##..#", "..#.##.##.", "###..#..#.", "#####..#.#",
          ],
          note: "Named for TV static — there's no picture, just snow you must reason your way through."),
    Entry(id: "labyrinth", title: "Labyrinth", difficulty: .max,
          bitmap: [
            ".#....##.#..", ".....#.#.#..", "..##.####...", "..##..#..##.",
            "..#.###..###", "..#...##.###", "#.##......#.", ".###..##....",
            "#####..#..##", "#.#....#.#.#", ".#..##...##.", ".#......##.#",
          ],
          note: "Named for its maze-like tangle of corridors and dead ends."),
    Entry(id: "obsidian", title: "Obsidian", difficulty: .max,
          bitmap: [
            "#.#....#..##..", "..##...##....#", ".......##..##.", "#..#.#.#...##.",
            "......#.####.#", "..###.#.##....", "#..####...##..", "##...#..#...##",
            "..##.##.#..#..", "##.#..##.#.##.", "#.#..#...###..", "###.#.#...##..",
            "###...#.#.###.", "#..#.#.####.##",
          ],
          note: "A dense slab of black glass — 14×14 with no foothold but pure deduction."),
    Entry(id: "leviathan", title: "Leviathan", difficulty: .max,
          bitmap: [
            ".....###.#.#..#", ".......####..#.", "##.###.....#.#.", "#...#...#.##..#",
            ".#.##..#...#...", "#..#.#..###...#", "#..#.#...#.####", "....#.#####..##",
            "#..#.##.#.#.##.", "..####..#..#.#.", "#.##.##.#.##.##", "..#.####.###..#",
            ".##..#.###..###", ".#.##..##....##", "#.#.######.#.#.",
          ],
          note: "A 15×15 sea-monster of a grid — vast, and it fights back."),
    Entry(id: "nebula", title: "Nebula", difficulty: .max,
          bitmap: [
            "#.#.##.###.#..#", "###..#.#.#.....", "###..#.#.######", "..##..#.###...#",
            "##.##.#..#####.", "#.#.#.#.#...#..", ".#.#..#.#.#.##.", ".###.####.....#",
            "#.#....#.#.##.#", "..#..##..###..#", "###.##.#...####", ".#........##.#.",
            "...#.##.##.##..", ".#.#.#..#..#...", "..##.#..##...#.",
          ],
          note: "Scattered light across 15×15 — find the order hidden in the chaos."),

    // ---------- 7×7 pocket set (playable on larger Apple Watches) ----------
    // Every one is engine-verified: provably unique, solvable by pure line logic,
    // and its difficulty is the grader's own verdict.
    Entry(id: "plus7", title: "Big Plus", difficulty: .easy,
          bitmap: ["...#...", "...#...", "...#...", "#######", "...#...", "...#...", "...#..."]),
    Entry(id: "hourglass7", title: "Hourglass", difficulty: .easy,
          bitmap: ["#######", ".#####.", "..###..", "...#...", "..###..", ".#####.", "#######"]),
    Entry(id: "mug7", title: "Mug", difficulty: .easy,
          bitmap: ["#######", ".#####.", ".#####.", ".#####.", "..###..", "..###..", "#######"]),
    Entry(id: "diamond7", title: "Cut Diamond", difficulty: .easy,
          bitmap: ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."]),
    Entry(id: "heart7", title: "Plump Heart", difficulty: .easy,
          bitmap: [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."]),
    Entry(id: "bowtie7", title: "Bow Tie", difficulty: .easy,
          bitmap: ["#.....#", "##...##", "#.#.#.#", "#..#..#", "#.#.#.#", "##...##", "#.....#"]),
    Entry(id: "tree7", title: "Sapling", difficulty: .easy,
          bitmap: ["...#...", "..###..", ".#####.", "#######", "..###..", "...#...", "..###.."]),
    Entry(id: "spade7", title: "Spade", difficulty: .easy,
          bitmap: ["...#...", "..###..", ".#####.", "#######", "#######", "...#...", "..###.."]),
]

/// The built-in puzzle library, in menu order.
public let library: [Puzzle] = entries.map { e in
    Puzzle(
        id: e.id,
        title: e.title,
        solution: bitmapToGrid(e.bitmap),
        difficulty: e.difficulty,
        note: e.note,
        named: !abstractIDs.contains(e.id)
    )
}

public func puzzle(withID id: String) -> Puzzle? {
    library.first { $0.id == id }
}

public func puzzles(in tier: Difficulty) -> [Puzzle] {
    library.filter { $0.difficulty == tier }
}
