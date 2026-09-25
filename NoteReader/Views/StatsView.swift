import SwiftUI

/// Mastery grid per clef plus a "slowest notes" list.
struct StatsView: View {
    @EnvironmentObject private var stats: StatsStore

    private enum Mastery {
        case unseen, learning, okay, strong

        var color: Color {
            switch self {
            case .unseen: return Theme.card
            case .learning: return Theme.wrong
            case .okay: return Theme.amber
            case .strong: return Theme.correct
            }
        }

        var foreground: Color {
            self == .unseen ? Theme.secondary : .white
        }
    }

    private static func mastery(_ s: NoteStats?) -> Mastery {
        guard let s = s, s.attempts > 0 else { return .unseen }
        if s.accuracy >= 0.85 && s.averageMs <= 2500 { return .strong }
        if s.accuracy >= 0.6 { return .okay }
        return .learning
    }

    private struct SlowEntry: Identifiable {
        let prompt: Prompt
        let stats: NoteStats
        var id: String { prompt.key }
    }

    private var slowest: [SlowEntry] {
        stats.data.notes.compactMap { key, value -> SlowEntry? in
            guard value.attempts >= 2, let prompt = Prompt(key: key) else { return nil }
            return SlowEntry(prompt: prompt, stats: value)
        }
        .sorted { $0.stats.averageMs > $1.stats.averageMs }
        .prefix(6)
        .map { $0 }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                ForEach(Clef.allCases) { clef in
                    clefGrid(clef)
                }
                slowestCard
                legend
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        HStack {
            summaryItem("Answers", "\(stats.data.totalAttempts)")
            Divider().frame(height: 36)
            summaryItem("Accuracy", stats.data.totalAttempts == 0 ? "–" : Formatting.percent(stats.data.overallAccuracy))
            Divider().frame(height: 36)
            summaryItem("Notes seen", "\(stats.data.notes.count)")
        }
        .card()
    }

    private func summaryItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.display(24))
                .monospacedDigit()
                .foregroundColor(Theme.ink)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func clefGrid(_ clef: Clef) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(clef.title) clef")
                .font(Theme.display(20))
                .foregroundColor(Theme.ink)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(RangePreset.intermediate.notes(for: clef)) { note in
                    let prompt = Prompt(clef: clef, note: note)
                    let entry = stats.stats(for: prompt)
                    let mastery = StatsView.mastery(entry)
                    VStack(spacing: 2) {
                        Text(note.czechName)
                            .font(Theme.noteFont(16))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(entry.map { Formatting.percent($0.accuracy) } ?? "–")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                    }
                    .foregroundColor(mastery.foreground)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(mastery.color)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(mastery == .unseen ? Theme.cardBorder : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
        .card()
    }

    private var slowestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Slowest notes")
                .font(Theme.display(20))
                .foregroundColor(Theme.ink)
            if slowest.isEmpty {
                Text("Play a few rounds and your slowest notes will show up here.")
                    .font(.footnote)
                    .foregroundColor(Theme.secondary)
            } else {
                ForEach(slowest) { entry in
                    HStack {
                        Text(entry.prompt.note.czechName)
                            .font(Theme.noteFont(20))
                            .foregroundColor(Theme.ink)
                            .frame(width: 44, alignment: .leading)
                        Text(entry.prompt.clef.title)
                            .font(.footnote)
                            .foregroundColor(Theme.secondary)
                        Spacer()
                        Text(Formatting.percent(entry.stats.accuracy))
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundColor(Theme.secondary)
                        Text(Formatting.seconds(entry.stats.averageMs))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(Theme.ink)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
        .card()
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(Theme.correct, "Strong")
            legendItem(Theme.amber, "Getting there")
            legendItem(Theme.wrong, "Needs work")
        }
        .font(.caption)
        .foregroundColor(Theme.secondary)
        .frame(maxWidth: .infinity)
    }

    private func legendItem(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}
