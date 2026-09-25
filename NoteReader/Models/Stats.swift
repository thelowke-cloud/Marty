import Foundation
import Combine

/// Per-note statistics.
struct NoteStats: Codable, Equatable {
    var attempts: Int = 0
    var correct: Int = 0
    var totalMs: Int = 0

    var accuracy: Double {
        attempts == 0 ? 0 : Double(correct) / Double(attempts)
    }

    var averageMs: Int {
        attempts == 0 ? 0 : totalMs / attempts
    }

    mutating func record(correct wasCorrect: Bool, ms: Int) {
        attempts += 1
        if wasCorrect { correct += 1 }
        totalMs += max(0, ms)
    }
}

/// Everything persisted between launches (except settings).
struct StatsData: Codable, Equatable {
    /// Keyed by `Prompt.key` ("treble:C4").
    var notes: [String: NoteStats] = [:]
    /// Keyed by "<clefChoice>-<range>".
    var sprintBests: [String: Int] = [:]
    /// Keyed by "<clefChoice>-<range>".
    var streakBests: [String: Int] = [:]
    /// Repetition weights (1…3), keyed by `Prompt.key`.
    var weights: [String: Int] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case notes, sprintBests, streakBests, weights
    }

    // Tolerant decoding so an older/newer file never crashes the app.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notes = (try? c.decodeIfPresent([String: NoteStats].self, forKey: .notes)) ?? [:]
        sprintBests = (try? c.decodeIfPresent([String: Int].self, forKey: .sprintBests)) ?? [:]
        streakBests = (try? c.decodeIfPresent([String: Int].self, forKey: .streakBests)) ?? [:]
        weights = (try? c.decodeIfPresent([String: Int].self, forKey: .weights)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(notes, forKey: .notes)
        try c.encode(sprintBests, forKey: .sprintBests)
        try c.encode(streakBests, forKey: .streakBests)
        try c.encode(weights, forKey: .weights)
    }

    var totalAttempts: Int { notes.values.reduce(0) { $0 + $1.attempts } }
    var totalCorrect: Int { notes.values.reduce(0) { $0 + $1.correct } }
    var overallAccuracy: Double {
        totalAttempts == 0 ? 0 : Double(totalCorrect) / Double(totalAttempts)
    }
}

/// Owns `StatsData` and persists it as JSON in `UserDefaults`.
final class StatsStore: ObservableObject {
    @Published private(set) var data: StatsData

    private let defaults: UserDefaults
    private let storageKey = "notereader.stats.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(StatsData.self, from: raw) {
            data = decoded
        } else {
            data = StatsData()
        }
    }

    static func bestKey(clefChoice: ClefChoice, range: RangePreset) -> String {
        "\(clefChoice.rawValue)-\(range.rawValue)"
    }

    func stats(for prompt: Prompt) -> NoteStats? {
        data.notes[prompt.key]
    }

    func record(prompt: Prompt, correct: Bool, ms: Int) {
        var entry = data.notes[prompt.key] ?? NoteStats()
        entry.record(correct: correct, ms: ms)
        data.notes[prompt.key] = entry
        save()
    }

    func saveWeights(_ weights: [String: Int]) {
        guard weights != data.weights else { return }
        data.weights = weights
        save()
    }

    func sprintBest(clefChoice: ClefChoice, range: RangePreset) -> Int? {
        data.sprintBests[StatsStore.bestKey(clefChoice: clefChoice, range: range)]
    }

    func streakBest(clefChoice: ClefChoice, range: RangePreset) -> Int? {
        data.streakBests[StatsStore.bestKey(clefChoice: clefChoice, range: range)]
    }

    /// Returns true when `score` is a new personal best.
    @discardableResult
    func submitSprint(score: Int, clefChoice: ClefChoice, range: RangePreset) -> Bool {
        let key = StatsStore.bestKey(clefChoice: clefChoice, range: range)
        let previous = data.sprintBests[key]
        if previous == nil || score > (previous ?? Int.min) {
            data.sprintBests[key] = score
            save()
            return true
        }
        return false
    }

    /// Returns true when `streak` is a new personal best.
    @discardableResult
    func submitStreak(_ streak: Int, clefChoice: ClefChoice, range: RangePreset) -> Bool {
        let key = StatsStore.bestKey(clefChoice: clefChoice, range: range)
        let previous = data.streakBests[key] ?? 0
        if streak > previous {
            data.streakBests[key] = streak
            save()
            return true
        }
        return false
    }

    func reset() {
        data = StatsData()
        save()
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: storageKey)
    }
}
