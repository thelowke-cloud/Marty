import SwiftUI

/// One button per note in range, Czech names, rows by octave with columns aligned c→h.
struct AnswerLettersView: View {
    let notes: [Note]
    let feedback: GameSession.Feedback?
    let enabled: Bool
    let onTap: (Note) -> Void

    private var rows: [[Letter: Note]] {
        let octaves = Array(Set(notes.map { $0.octave })).sorted()
        return octaves.map { octave in
            var row: [Letter: Note] = [:]
            for note in notes where note.octave == octave {
                row[note.letter] = note
            }
            return row
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Letter.allCases, id: \.self) { letter in
                        if let note = row[letter] {
                            letterButton(note)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 56)
                        }
                    }
                }
            }
        }
    }

    private func letterButton(_ note: Note) -> some View {
        let state = buttonState(for: note)
        return Button {
            onTap(note)
        } label: {
            Text(note.czechName)
                .font(Theme.noteFont(22))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(state.foreground)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(state.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(state.border, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.15), value: feedback)
    }

    private struct ButtonState {
        let background: Color
        let foreground: Color
        let border: Color
    }

    private func buttonState(for note: Note) -> ButtonState {
        if let feedback = feedback {
            if note == feedback.expected.note {
                return ButtonState(background: Theme.correct, foreground: .white, border: Theme.correct)
            }
            if !feedback.correct && note == feedback.answered {
                return ButtonState(background: Theme.wrong, foreground: .white, border: Theme.wrong)
            }
        }
        return ButtonState(background: Theme.card, foreground: Theme.ink, border: Theme.cardBorder)
    }
}
