import Foundation

/// Chooses the next prompt.
///
/// - Weighted random: each prompt has a repetition weight 1…3 (miss = +1, hit = −1),
///   boosted further by poor accuracy or slow answers in the persisted stats.
/// - A missed prompt is re-queued so it comes back after two other prompts.
/// - The same prompt is never shown twice in a row.
struct NotePicker {
    static let minWeight = 1
    static let maxWeight = 3
    /// How many other prompts are shown before a missed prompt returns.
    static let retryGap = 2

    struct Pick: Equatable {
        let prompt: Prompt
        let isRetry: Bool
    }

    private struct Retry {
        let prompt: Prompt
        let dueIndex: Int
    }

    private(set) var weights: [String: Int]
    private(set) var lastPrompt: Prompt?
    private var retryQueue: [Retry] = []
    private var index = 0

    init(weights: [String: Int] = [:]) {
        self.weights = weights.mapValues { min(max($0, NotePicker.minWeight), NotePicker.maxWeight) }
    }

    /// Picks the next prompt from `pool`. Returns nil only for an empty pool.
    mutating func next(from pool: [Prompt], stats: StatsStore?) -> Pick? {
        guard !pool.isEmpty else { return nil }
        index += 1

        // 1. A due retry (never the same prompt twice in a row).
        if let position = retryQueue.firstIndex(where: { $0.dueIndex <= index && $0.prompt != lastPrompt }) {
            let retry = retryQueue.remove(at: position)
            lastPrompt = retry.prompt
            return Pick(prompt: retry.prompt, isRetry: true)
        }

        // 2. Weighted random among everything except the previous prompt.
        var candidates = pool.filter { $0 != lastPrompt }
        if candidates.isEmpty { candidates = pool }

        let weighted = candidates.map { ($0, effectiveWeight(for: $0, stats: stats)) }
        let total = weighted.reduce(0.0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<max(total, 0.0001))
        var chosen = candidates[0]
        for (prompt, weight) in weighted {
            if roll < weight {
                chosen = prompt
                break
            }
            roll -= weight
        }

        // If a queued retry happened to come up naturally, drop it from the queue.
        retryQueue.removeAll { $0.prompt == chosen }
        lastPrompt = chosen
        return Pick(prompt: chosen, isRetry: false)
    }

    /// Call after a wrong answer for `prompt`.
    mutating func registerMiss(_ prompt: Prompt) {
        let current = weights[prompt.key] ?? NotePicker.minWeight
        weights[prompt.key] = min(NotePicker.maxWeight, current + 1)
        retryQueue.removeAll { $0.prompt == prompt }
        retryQueue.append(Retry(prompt: prompt, dueIndex: index + NotePicker.retryGap + 1))
    }

    /// Call after a correct answer for `prompt`.
    mutating func registerHit(_ prompt: Prompt) {
        let current = weights[prompt.key] ?? NotePicker.minWeight
        weights[prompt.key] = max(NotePicker.minWeight, current - 1)
    }

    private func effectiveWeight(for prompt: Prompt, stats: StatsStore?) -> Double {
        var weight = Double(weights[prompt.key] ?? NotePicker.minWeight)
        if let s = stats?.stats(for: prompt), s.attempts >= 2 {
            // Missed notes: up to +2. Slow notes (> 2.5 s): +1.
            weight += (1.0 - s.accuracy) * 2.0
            if s.averageMs > 2500 { weight += 1.0 }
        }
        return max(weight, 0.1)
    }
}
