import Foundation

/// Which clef(s) to practise.
enum ClefChoice: String, CaseIterable, Codable, Identifiable, Hashable {
    case treble
    case bass
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .treble: return "Treble"
        case .bass: return "Bass"
        case .both: return "Both"
        }
    }

    var clefs: [Clef] {
        switch self {
        case .treble: return [.treble]
        case .bass: return [.bass]
        case .both: return [.treble, .bass]
        }
    }
}

/// Note ranges per clef.
///
/// Beginner:     treble c1–g2 (C4–G5, steps -2…9),  bass F–c1 (F2–C4, steps -1…10)
///               → the only ledger line is the one through c1.
/// Intermediate: treble a–c3  (A3–C6, steps -4…12), bass C–e1 (C2–E4, steps -4…12)
///               → two ledger lines below and two above the staff.
enum RangePreset: String, CaseIterable, Codable, Identifiable, Hashable {
    case beginner
    case intermediate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        }
    }

    func bounds(for clef: Clef) -> (low: Note, high: Note) {
        switch (self, clef) {
        case (.beginner, .treble): return (Note(.c, 4), Note(.g, 5))
        case (.beginner, .bass): return (Note(.f, 2), Note(.c, 4))
        case (.intermediate, .treble): return (Note(.a, 3), Note(.c, 6))
        case (.intermediate, .bass): return (Note(.c, 2), Note(.e, 4))
        }
    }

    /// All notes in the range for a clef, ascending.
    func notes(for clef: Clef) -> [Note] {
        let b = bounds(for: clef)
        return Note.notes(from: b.low, to: b.high)
    }

    /// e.g. "c1–g2"
    func summary(for clef: Clef) -> String {
        let b = bounds(for: clef)
        return "\(b.low.czechName)–\(b.high.czechName)"
    }
}

/// How the player answers.
enum AnswerMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case letters
    case piano

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letters: return "Letters"
        case .piano: return "Piano"
        }
    }
}

/// Game modes.
enum GameMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case practice
    case sprint
    case streak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practice: return "Practice"
        case .sprint: return "Sprint"
        case .streak: return "Streak"
        }
    }

    var subtitle: String {
        switch self {
        case .practice: return "Endless. Accuracy and average time."
        case .sprint: return "60 seconds. +1 correct, −1 wrong."
        case .streak: return "How many in a row before a slip?"
        }
    }

    var symbolName: String {
        switch self {
        case .practice: return "infinity"
        case .sprint: return "timer"
        case .streak: return "flame"
        }
    }
}

/// One question: a note shown on a specific clef.
struct Prompt: Hashable, Codable {
    let clef: Clef
    let note: Note

    /// Storage key, e.g. "treble:C4".
    var key: String { "\(clef.rawValue):\(note.id)" }

    /// Parses a key produced by `key`.
    init?(key: String) {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let clef = Clef(rawValue: String(parts[0])) else { return nil }
        let noteID = String(parts[1])
        guard let first = noteID.first,
              let letter = Letter.allCases.first(where: { $0.uppercaseName == String(first) }),
              let octave = Int(noteID.dropFirst()) else { return nil }
        self.clef = clef
        self.note = Note(letter, octave)
    }

    init(clef: Clef, note: Note) {
        self.clef = clef
        self.note = note
    }
}
