// Player persistence (mirrors src/ui/persistence.ts semantics): best times,
// best scores, completion, settings, in-progress attempt snapshots, and the
// honour-system progress-reset flag. Backed by UserDefaults; everything stays
// on-device (no accounts, no network).

import Foundation

/// How a clue is drawn once its line is complete.
public enum ClueStyle: String, Codable, CaseIterable, Sendable {
    case grey, strike, hide, none

    public var displayName: String {
        switch self {
        case .grey: "Grey out"
        case .strike: "Strike through"
        case .hide: "Hide them"
        case .none: "Leave them"
        }
    }
}

public struct GameSettings: Codable, Sendable, Equatable {
    public var mistakeCheck = false
    public var showTimer = true
    public var clueStyle: ClueStyle = .grey
    public var autoCross = false
    /// How the game picks your next puzzle. See docs/progression-model.md §4.
    public var progression = ProgressionSettings()
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case mistakeCheck, showTimer, clueStyle, autoCross, progression
    }

    /// Tolerant field-by-field decode so a save from any app version — older
    /// (no progression block) or newer — loads without losing the rest.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ type: T.Type, _ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)).flatMap { $0 } ?? fallback
        }
        mistakeCheck = field(Bool.self, .mistakeCheck, false)
        showTimer = field(Bool.self, .showTimer, true)
        clueStyle = field(ClueStyle.self, .clueStyle, .grey)
        autoCross = field(Bool.self, .autoCross, false)
        progression = field(ProgressionSettings.self, .progression, ProgressionSettings())
    }
}

/// A player-created puzzle (kept across progress resets, like the web app).
public struct StoredPuzzle: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var solution: [[Bool]]
    public init(id: String, title: String, solution: [[Bool]]) {
        self.id = id
        self.title = title
        self.solution = solution
    }

    public var asPuzzle: Puzzle {
        Puzzle(id: id, title: title, solution: solution, difficulty: gradeGrid(solution))
    }
}

/// A snapshot of an unfinished attempt, so quitting the app never loses a
/// board: marks, the paused clock, and any assist penalties already incurred.
public struct InProgressAttempt: Codable, Sendable, Equatable {
    /// `Cell` raw values, `[row][col]`.
    public var marks: [[UInt8]]
    public var elapsedMs: Int
    public var assists: AssistTally
    /// When this attempt was last written. Optional so saves from before the
    /// field existed decode untouched; "most recent attempt" falls back to the
    /// distant past for those, which only ever costs a widget its first render.
    public var updatedAt: Date?

    public init(marks: Grid, elapsedMs: Int, assists: AssistTally, updatedAt: Date? = Date()) {
        self.marks = marks.map { $0.map(\.rawValue) }
        self.elapsedMs = elapsedMs
        self.assists = assists
        self.updatedAt = updatedAt
    }

    public var grid: Grid { marks.map { $0.map { Cell(rawValue: $0) ?? .unknown } } }
}

/// Decodes `T` but never throws: a malformed element becomes `nil` instead of
/// failing the whole container. Used so a single corrupt custom-puzzle entry
/// can't wipe a player's entire collection.
private struct Failable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

public struct SaveData: Codable, Sendable {
    public var completed: Set<String> = []
    /// Fastest solve time (ms) per puzzle id.
    public var bestTimes: [String: Int] = [:]
    /// Best per-puzzle score (0–100) per puzzle id.
    public var bestScores: [String: Int] = [:]
    /// Assists used in the current (in-progress) attempt, per puzzle id.
    /// Superseded by `inProgress` (which carries the whole board); kept so
    /// old saves round-trip.
    public var assists: [String: AssistTally] = [:]
    /// Player-created puzzles.
    public var userPuzzles: [StoredPuzzle] = []
    /// Player-generated puzzles (separate "Generated" library).
    public var generatedPuzzles: [StoredPuzzle] = []
    public var settings = GameSettings()
    public var tutorialSeen = false
    /// True once the post-tutorial feature tour has been shown.
    public var tourSeen = false
    /// True once progress has ever been wiped — disclosed when sharing a score.
    public var progressReset = false
    /// Unfinished attempts, per puzzle id (board + clock + assists).
    public var inProgress: [String: InProgressAttempt] = [:]
    /// Working tier + boredom/struggle streaks. See docs/progression-model.md.
    public var progression = ProgressionState()
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case completed, bestTimes, bestScores, assists, userPuzzles, generatedPuzzles,
             settings, tutorialSeen, tourSeen, progressReset, inProgress, progression
    }

    /// Every field decodes independently with a default, so a save written by
    /// ANY app version — older (missing keys) or newer (extra keys) — loads
    /// without wiping the player's progress.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ type: T.Type, _ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)).flatMap { $0 } ?? fallback
        }
        completed = field(Set<String>.self, .completed, [])
        bestTimes = field([String: Int].self, .bestTimes, [:])
        bestScores = field([String: Int].self, .bestScores, [:])
        assists = field([String: AssistTally].self, .assists, [:])
        // Custom puzzles are the one thing promised to survive everything, so
        // decode them element by element: a corrupt entry is dropped, the rest live.
        if let wrapped = try? c.decodeIfPresent([Failable<StoredPuzzle>].self, forKey: .userPuzzles) {
            userPuzzles = (wrapped ?? []).compactMap(\.value)
        } else {
            userPuzzles = []
        }
        if let wrapped = try? c.decodeIfPresent([Failable<StoredPuzzle>].self, forKey: .generatedPuzzles) {
            generatedPuzzles = (wrapped ?? []).compactMap(\.value)
        } else {
            generatedPuzzles = []
        }
        settings = field(GameSettings.self, .settings, GameSettings())
        tutorialSeen = field(Bool.self, .tutorialSeen, false)
        tourSeen = field(Bool.self, .tourSeen, false)
        progressReset = field(Bool.self, .progressReset, false)
        inProgress = field([String: InProgressAttempt].self, .inProgress, [:])
        progression = field(ProgressionState.self, .progression, ProgressionState())
    }
}

/// Single source of truth for player data. `@unchecked Sendable` is safe: all
/// mutation is funneled through the main actor in the apps; the store itself is
/// a value-semantics wrapper over UserDefaults.
public final class PlayerStore: @unchecked Sendable {
    public static let storageKey = "clueweave.save.v1"

    /// The pre-rebrand key. Read once, on first launch under the new name, so a
    /// player who saved under the old brand keeps their progress. Never written to.
    static let legacyStorageKey = "pixelogic.save.v1"

    private let defaults: UserDefaults
    private var cache: SaveData

    /// The save blob, preferring the current key in the destination suite and
    /// adopting an older location if that is all there is. Adoption copies the
    /// blob across and clears the source, so each legacy location matters once.
    ///
    /// Two migrations stack here, and they must run in this order:
    ///  1. the **rebrand** — `pixelogic.save.v1` → `clueweave.save.v1`;
    ///  2. the **App Group** — app-local `UserDefaults.standard` → the shared
    ///     suite, needed because widgets run in their own process and cannot
    ///     see app-local defaults at all.
    ///
    /// A player upgrading straight from the pre-rebrand build hits both, which
    /// is why the fallback stores are searched under *both* keys.
    static func readRaw(_ defaults: UserDefaults, fallbacks: [UserDefaults] = []) -> Data? {
        func adopt(_ data: Data, from source: UserDefaults, key: String) -> Data {
            defaults.set(data, forKey: storageKey)
            if source !== defaults || key != storageKey { source.removeObject(forKey: key) }
            return data
        }
        if let current = defaults.data(forKey: storageKey) { return current }
        if let legacy = defaults.data(forKey: legacyStorageKey) {
            return adopt(legacy, from: defaults, key: legacyStorageKey)
        }
        for source in fallbacks where source !== defaults {
            if let current = source.data(forKey: storageKey) {
                return adopt(current, from: source, key: storageKey)
            }
            if let legacy = source.data(forKey: legacyStorageKey) {
                return adopt(legacy, from: source, key: legacyStorageKey)
            }
        }
        return nil
    }

    /// - Parameters:
    ///   - defaults: where the save lives from now on. Apps pass
    ///     `AppGroup.defaults` so widgets can read it.
    ///   - migratingFrom: older locations to adopt a save from, once. Empty by
    ///     default so a test fixture can never inherit the runner's own state —
    ///     the apps opt in explicitly with `[.standard]`.
    public init(
        defaults: UserDefaults = AppGroup.defaults,
        migratingFrom fallbacks: [UserDefaults] = []
    ) {
        self.defaults = defaults
        if let raw = Self.readRaw(defaults, fallbacks: fallbacks) {
            if let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
                cache = decoded
            } else {
                // Never silently destroy a corrupt save — stash it for recovery.
                defaults.set(raw, forKey: Self.storageKey + ".corrupt")
                cache = SaveData()
            }
        } else {
            cache = SaveData()
        }
    }

    public private(set) var data: SaveData {
        get { cache }
        set {
            cache = newValue
            if let raw = try? JSONEncoder().encode(newValue) {
                defaults.set(raw, forKey: Self.storageKey)
            }
        }
    }

    // MARK: - Settings

    public var settings: GameSettings {
        get { data.settings }
        set { data.settings = newValue }
    }

    public var tutorialSeen: Bool {
        get { data.tutorialSeen }
        set { data.tutorialSeen = newValue }
    }

    public var tourSeen: Bool {
        get { data.tourSeen }
        set { data.tourSeen = newValue }
    }

    // MARK: - Completion / times / scores

    public func isCompleted(_ id: String) -> Bool { data.completed.contains(id) }

    public func markCompleted(_ id: String) {
        var d = data
        d.completed.insert(id)
        d.assists.removeValue(forKey: id)
        d.inProgress.removeValue(forKey: id)
        data = d
    }

    public func bestTime(for id: String) -> Int? { data.bestTimes[id] }

    /// Record a solve time, keeping only the fastest. Returns (best, isNew).
    @discardableResult
    public func recordBestTime(_ id: String, elapsedMs: Int) -> (best: Int, isNew: Bool) {
        var d = data
        if let prev = d.bestTimes[id], prev <= elapsedMs {
            return (prev, false)
        }
        d.bestTimes[id] = elapsedMs
        data = d
        return (elapsedMs, true)
    }

    public func bestScore(for id: String) -> Int? { data.bestScores[id] }

    /// Record a per-puzzle score (0–100), keeping the best. Returns (best, isNew).
    @discardableResult
    public func recordScore(_ id: String, score: Int) -> (best: Int, isNew: Bool) {
        var d = data
        if let prev = d.bestScores[id], prev >= score {
            return (prev, false)
        }
        d.bestScores[id] = score
        data = d
        return (score, true)
    }

    // MARK: - In-progress attempts (quit the app, keep the board)

    public func inProgress(for id: String) -> InProgressAttempt? { data.inProgress[id] }

    public func saveInProgress(_ attempt: InProgressAttempt, for id: String) {
        var d = data
        d.inProgress[id] = attempt
        data = d
    }

    public func clearInProgress(for id: String) {
        guard data.inProgress[id] != nil else { return }
        var d = data
        d.inProgress.removeValue(forKey: id)
        data = d
    }

    // MARK: - Assist ledger (superseded by in-progress attempts; kept for old saves)

    public func assists(for id: String) -> AssistTally { data.assists[id] ?? AssistTally() }

    public func setAssists(_ tally: AssistTally, for id: String) {
        var d = data
        d.assists[id] = tally
        data = d
    }

    public func clearAssists(for id: String) {
        var d = data
        d.assists.removeValue(forKey: id)
        data = d
    }

    // MARK: - Custom puzzles

    public var userPuzzles: [StoredPuzzle] { data.userPuzzles }

    /// Insert or update (same id replaces — no accidental duplicates).
    public func saveUserPuzzle(_ puzzle: StoredPuzzle) {
        var d = data
        if let idx = d.userPuzzles.firstIndex(where: { $0.id == puzzle.id }) {
            // Editing the art invalidates any saved in-progress board for this id —
            // otherwise reopening restores stale marks onto the new solution.
            if d.userPuzzles[idx].solution != puzzle.solution {
                d.inProgress.removeValue(forKey: puzzle.id)
            }
            d.userPuzzles[idx] = puzzle
        } else {
            d.userPuzzles.append(puzzle)
        }
        data = d
    }

    /// Import a shared puzzle. An identical picture that's already in the
    /// collection is reused (no duplicate cards from re-tapping a link).
    @discardableResult
    public func importUserPuzzle(title: String, solution: [[Bool]]) -> String {
        if let existing = userPuzzles.first(where: { $0.solution == solution }) {
            return existing.id
        }
        let id = "u-\(UUID().uuidString.prefix(8))"
        saveUserPuzzle(StoredPuzzle(id: id, title: title, solution: solution))
        return id
    }

    public func deleteUserPuzzles(ids: Set<String>) {
        var d = data
        d.userPuzzles.removeAll { ids.contains($0.id) }
        for id in ids { d.inProgress.removeValue(forKey: id) }
        data = d
    }

    // MARK: - Generated puzzles (separate library, kept across resets)

    public var generatedPuzzles: [StoredPuzzle] { data.generatedPuzzles }

    /// Save a generated puzzle. An identical picture already saved is reused
    /// (no duplicate cards). Returns the id (always prefixed "g-").
    @discardableResult
    public func saveGeneratedPuzzle(title: String, solution: [[Bool]]) -> String {
        if let idx = data.generatedPuzzles.firstIndex(where: { $0.solution == solution }) {
            // Same picture already saved: keep its id but adopt the title the
            // player just previewed, so the saved card matches what they saw.
            if data.generatedPuzzles[idx].title != title {
                var d = data; d.generatedPuzzles[idx].title = title; data = d
            }
            return data.generatedPuzzles[idx].id
        }
        let id = "g-\(UUID().uuidString.prefix(8))"
        var d = data
        d.generatedPuzzles.append(StoredPuzzle(id: id, title: title, solution: solution))
        data = d
        return id
    }

    public func deleteGeneratedPuzzles(ids: Set<String>) {
        var d = data
        d.generatedPuzzles.removeAll { ids.contains($0.id) }
        for id in ids { d.inProgress.removeValue(forKey: id) }
        data = d
    }

    // MARK: - Clueweave Score

    public var clueweaveScore: Int {
        ClueweaveKit.clueweaveScore(
            bestScores: data.bestScores,
            library: library.map {
                PuzzleMeta(
                    id: $0.id,
                    difficulty: $0.difficulty,
                    weightMult: badgeWeightMultiplier(puzzleBadges($0))
                )
            }
        )
    }

    public var wasProgressReset: Bool { data.progressReset }

    /// Danger zone: wipe solved/in-progress state and records. Keeps settings.
    /// Sets a permanent flag so a shared Clueweave Score can disclose the reset.
    public func resetProgress() {
        var d = data
        d.completed = []
        d.bestTimes = [:]
        d.bestScores = [:]
        d.assists = [:]
        d.inProgress = [:]
        d.progressReset = true
        // Progression state IS progress — the working tier and streaks go back
        // to defaults. Settings (including the progression tunables) survive,
        // as do userPuzzles and generatedPuzzles.
        d.progression = ProgressionState()
        data = d
    }

    // MARK: - Progression

    public var progression: ProgressionState {
        get { data.progression }
        set { data.progression = newValue }
    }

    /// Fold a finished attempt's signal into the progression state.
    public func recordSignal(_ signal: Signal, library: [Puzzle]) {
        var d = data
        d.progression = applySignal(
            signal, d.progression, d.settings.progression, library, d.completed)
        data = d
    }

    /// Note a smart-next press: counts toward the spam guard and the first-use prompt.
    public func noteSmartNextUse() {
        var d = data
        d.progression.smartNextUses += 1
        d.progression.spamCount += 1
        data = d
    }

    public func markSmartNextPrompted() {
        var d = data
        d.progression.smartNextPrompted = true
        data = d
    }

    // MARK: - Widgets & complications

    /// The unfinished attempt a Continue widget should offer: the most recently
    /// saved one whose puzzle still exists. `resolve` maps a saved id back to a
    /// puzzle, so the caller decides whether custom/generated art counts.
    public func latestContinue(resolve: (String) -> Puzzle?) -> ContinueSource? {
        data.inProgress
            .compactMap { id, attempt -> (Date, ContinueSource)? in
                guard let puzzle = resolve(id) else { return nil }
                return (
                    attempt.updatedAt ?? .distantPast,
                    ContinueSource(puzzle: puzzle, marks: attempt.grid, elapsedMs: attempt.elapsedMs)
                )
            }
            // Saves written before `updatedAt` existed all tie at .distantPast;
            // breaking those on id keeps the widget stable between refreshes
            // instead of flickering between boards.
            .sorted { a, b in a.0 == b.0 ? a.1.puzzle.id < b.1.puzzle.id : a.0 > b.0 }
            .first?.1
    }

    public func widgetSnapshot(resolve: (String) -> Puzzle?, now: Date = Date()) -> WidgetSnapshot {
        makeWidgetSnapshot(
            library: library,
            completed: data.completed,
            bestScores: data.bestScores,
            progression: data.progression,
            continueFrom: latestContinue(resolve: resolve),
            score: clueweaveScore,
            now: now
        )
    }

    /// Rebuild the snapshot and hand it to the widget processes. Cheap enough to
    /// call at every checkpoint the save itself is written at.
    @discardableResult
    public func publishWidgetSnapshot(resolve: (String) -> Puzzle?, now: Date = Date()) -> WidgetSnapshot {
        let snapshot = widgetSnapshot(resolve: resolve, now: now)
        SnapshotStore.write(snapshot, to: defaults)
        return snapshot
    }
}
