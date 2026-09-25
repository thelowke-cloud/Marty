import SwiftUI

/// End-of-run summary for Sprint and Streak (and Practice when closed).
struct ResultsView: View {
    @ObservedObject var session: GameSession
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    private var title: String {
        switch session.mode {
        case .sprint: return "Time's up!"
        case .streak: return "Streak over"
        case .practice: return "Nice practice"
        }
    }

    private var headline: (value: String, label: String) {
        switch session.mode {
        case .sprint: return ("\(session.score)", "points")
        case .streak: return ("\(session.bestStreakInRun)", "in a row")
        case .practice: return ("\(session.correctCount)", "correct")
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(title)
                .font(Theme.display(34))
                .foregroundColor(Theme.ink)

            VStack(spacing: 4) {
                Text(headline.value)
                    .font(Theme.display(72, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Theme.accent)
                Text(headline.label)
                    .font(.headline)
                    .foregroundColor(Theme.secondary)
            }

            if session.isNewBest {
                Label("New personal best!", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.correct))
            } else if let best = session.personalBest {
                Text("Personal best: \(best)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.secondary)
            }

            VStack(spacing: 12) {
                statRow("Correct", "\(session.correctCount)")
                statRow("Wrong", "\(session.wrongCount)")
                statRow("Accuracy", Formatting.percent(session.accuracy))
                statRow("Average time", Formatting.seconds(session.averageMs))
            }
            .card()

            Spacer()

            VStack(spacing: 10) {
                Button("Play again", action: onPlayAgain)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Home", action: onHome)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(20)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundColor(Theme.ink)
        }
        .font(.body)
    }
}
