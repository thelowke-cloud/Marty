import SwiftUI

/// Full-screen game. Wraps `GameRunView` so "Play again" can start a fresh session.
struct GameView: View {
    let mode: GameMode
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var synth: ToneSynth
    @Environment(\.dismiss) private var dismiss
    @State private var runID = 0

    var body: some View {
        GameRunView(
            mode: mode,
            settings: settings,
            stats: stats,
            synth: synth,
            onPlayAgain: { runID += 1 },
            onHome: { dismiss() }
        )
        .id(runID)
    }
}

struct GameRunView: View {
    @StateObject private var session: GameSession
    @ObservedObject private var settings: AppSettings
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    init(mode: GameMode,
         settings: AppSettings,
         stats: StatsStore,
         synth: ToneSynth,
         onPlayAgain: @escaping () -> Void,
         onHome: @escaping () -> Void) {
        _session = StateObject(wrappedValue: GameSession(mode: mode, settings: settings, stats: stats, synth: synth))
        _settings = ObservedObject(wrappedValue: settings)
        self.onPlayAgain = onPlayAgain
        self.onHome = onHome
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if session.phase == .finished {
                ResultsView(session: session, onPlayAgain: onPlayAgain, onHome: onHome)
                    .transition(.opacity)
            } else {
                VStack(spacing: 14) {
                    topBar
                    staffCard
                    feedbackLine
                    Spacer(minLength: 0)
                    answerArea
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.phase)
        .onAppear { session.start() }
        .onDisappear { session.stop() }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                onHome()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            statusView

            Spacer()

            // Balances the close button so the status stays centred.
            Color.clear.frame(width: 40, height: 40)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch session.mode {
        case .practice:
            VStack(spacing: 2) {
                Text("Practice")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.secondary)
                HStack(spacing: 10) {
                    statPill("\(session.correctCount)/\(session.attempts)")
                    statPill(Formatting.percent(session.accuracy))
                    statPill(Formatting.seconds(session.averageMs))
                }
            }
        case .sprint:
            VStack(spacing: 2) {
                Text(Formatting.clock(session.timeRemaining))
                    .font(Theme.display(34))
                    .monospacedDigit()
                    .foregroundColor(session.timeRemaining <= 10 ? Theme.wrong : Theme.ink)
                Text("Score \(session.score)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.secondary)
            }
        case .streak:
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.accent)
                    Text("\(session.streak)")
                        .font(Theme.display(34))
                        .monospacedDigit()
                        .foregroundColor(Theme.ink)
                }
                Text("Streak")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.secondary)
            }
        }
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundColor(Theme.ink)
    }

    private var flashColor: Color? {
        guard session.phase == .feedback, let feedback = session.feedback else { return nil }
        return feedback.correct ? Theme.correct : Theme.wrong
    }

    private var staffCard: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(session.prompt.clef.title) clef")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.secondary)
                Spacer()
                if session.isRetry && session.phase == .playing {
                    Label("Again", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.accent)
                }
            }
            StaffView(clef: session.prompt.clef, note: session.prompt.note)
                .frame(height: 230)
                .id(session.prompt)
        }
        .card(padding: 14)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill((flashColor ?? .clear).opacity(flashColor == nil ? 0 : 0.14))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(flashColor ?? .clear, lineWidth: flashColor == nil ? 0 : 2.5)
        )
        .animation(.easeOut(duration: 0.2), value: session.phase)
    }

    private var feedbackLine: some View {
        Group {
            if let feedback = session.feedback, session.phase == .feedback {
                if feedback.correct {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Correct")
                            .fontWeight(.semibold)
                        Text("·")
                        Text(Formatting.seconds(feedback.ms))
                            .monospacedDigit()
                    }
                    .foregroundColor(Theme.correct)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("It was")
                        Text(feedback.expected.note.czechName)
                            .font(Theme.noteFont(22))
                        Text("·")
                        Text(Formatting.seconds(feedback.ms))
                            .monospacedDigit()
                    }
                    .foregroundColor(Theme.wrong)
                }
            } else if session.isRetry {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Again — this one tripped you up")
                        .fontWeight(.semibold)
                }
                .foregroundColor(Theme.accent)
            } else if let last = session.lastResponseMs {
                Text("Last answer \(Formatting.seconds(last))")
                    .foregroundColor(Theme.secondary)
            } else {
                Text("Which note is this?")
                    .foregroundColor(Theme.secondary)
            }
        }
        .font(.body)
        .frame(maxWidth: .infinity, minHeight: 32)
    }

    @ViewBuilder
    private var answerArea: some View {
        let enabled = session.phase == .playing
        switch settings.answerMode {
        case .letters:
            AnswerLettersView(
                notes: session.answerNotes,
                feedback: session.feedback,
                enabled: enabled,
                onTap: { session.answer($0) }
            )
        case .piano:
            PianoKeysView(
                notes: session.answerNotes,
                showLabels: settings.pianoLabels,
                feedback: session.feedback,
                enabled: enabled,
                onTap: { session.answer($0) }
            )
        }
    }
}
