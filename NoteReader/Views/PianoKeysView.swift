import SwiftUI

/// One white key per note in range (octave-exact), with decorative black keys.
struct PianoKeysView: View {
    let notes: [Note]
    let showLabels: Bool
    let feedback: GameSession.Feedback?
    let enabled: Bool
    let onTap: (Note) -> Void

    private let spacing: CGFloat = 2
    private let height: CGFloat = 176

    var body: some View {
        GeometryReader { geo in
            let count = max(notes.count, 1)
            let available = geo.size.width - CGFloat(count - 1) * spacing
            let keyWidth = max(34, floor(available / CGFloat(count)))
            let totalWidth = keyWidth * CGFloat(count) + CGFloat(count - 1) * spacing
            let blackWidth = keyWidth * 0.62
            let blackHeight = height * 0.58

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: spacing) {
                        ForEach(notes) { note in
                            whiteKey(note, width: keyWidth)
                        }
                    }
                    ForEach(Array(notes.enumerated()), id: \.element) { index, note in
                        if note.letter.hasBlackKeyAbove && index < notes.count - 1 {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Theme.blackKey)
                                .frame(width: blackWidth, height: blackHeight)
                                .offset(x: CGFloat(index + 1) * (keyWidth + spacing) - spacing / 2 - blackWidth / 2, y: 0)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .frame(width: totalWidth, height: height)
                .frame(minWidth: geo.size.width)
            }
        }
        .frame(height: height)
    }

    private func whiteKey(_ note: Note, width: CGFloat) -> some View {
        let state = keyState(for: note)
        return Button {
            onTap(note)
        } label: {
            ZStack(alignment: .bottom) {
                UnevenRoundedCorners(radius: 8)
                    .fill(state.background)
                UnevenRoundedCorners(radius: 8)
                    .stroke(Theme.keyBorder, lineWidth: 1)
                if showLabels {
                    Text(note.czechName)
                        .font(Theme.noteFont(min(18, width * 0.42)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(state.foreground)
                        .padding(.bottom, 10)
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.15), value: feedback)
    }

    private struct KeyState {
        let background: Color
        let foreground: Color
    }

    private func keyState(for note: Note) -> KeyState {
        if let feedback = feedback {
            if note == feedback.expected.note {
                return feedback.correct
                    ? KeyState(background: Theme.correct, foreground: .white)
                    : KeyState(background: Theme.keyHint, foreground: Theme.correct)
            }
            if !feedback.correct && note == feedback.answered {
                return KeyState(background: Theme.wrong, foreground: .white)
            }
        }
        return KeyState(background: Theme.whiteKey, foreground: Theme.ink)
    }
}

/// Rectangle with rounded bottom corners only (piano key shape).
struct UnevenRoundedCorners: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
