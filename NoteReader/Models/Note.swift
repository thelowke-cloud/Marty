import Foundation

/// The seven natural letters. Czech naming: H is used instead of B.
enum Letter: Int, CaseIterable, Codable, Hashable {
    case c = 0
    case d
    case e
    case f
    case g
    case a
    case h

    /// Semitone offset from C within an octave.
    var semitone: Int {
        switch self {
        case .c: return 0
        case .d: return 2
        case .e: return 4
        case .f: return 5
        case .g: return 7
        case .a: return 9
        case .h: return 11
        }
    }

    var lowercaseName: String {
        switch self {
        case .c: return "c"
        case .d: return "d"
        case .e: return "e"
        case .f: return "f"
        case .g: return "g"
        case .a: return "a"
        case .h: return "h"
        }
    }

    var uppercaseName: String { lowercaseName.uppercased() }

    /// Whether a black key sits immediately to the right of this white key on a piano.
    var hasBlackKeyAbove: Bool {
        switch self {
        case .e, .h: return false
        default: return true
        }
    }
}

/// A natural (white-key) note with an octave in scientific pitch notation.
/// Middle C is `Note(.c, 4)`, which is Czech `c1` (jednočárková oktáva).
///
/// Czech octave names used by `czechName`:
///   octave 2  → velká:         C  D  E  F  G  A  H
///   octave 3  → malá:          c  d  e  f  g  a  h
///   octave 4  → jednočárková:  c1 d1 e1 f1 g1 a1 h1   (middle C = c1)
///   octave 5  → dvoučárková:   c2 d2 e2 f2 g2 a2 h2
///   octave 6  → tříčárková:    c3 …
struct Note: Hashable, Codable, Comparable, Identifiable {
    let letter: Letter
    /// Scientific octave number (C4 = middle C).
    let octave: Int

    init(_ letter: Letter, _ octave: Int) {
        self.letter = letter
        self.octave = octave
    }

    /// Builds a note from a diatonic index (octave * 7 + letter). Returns nil only for absurd values.
    init?(diatonicIndex: Int) {
        guard diatonicIndex >= 0, diatonicIndex < 7 * 12 else { return nil }
        let octave = diatonicIndex / 7
        guard let letter = Letter(rawValue: diatonicIndex % 7) else { return nil }
        self.init(letter, octave)
    }

    /// Stable identifier, e.g. "C4", "H3". Used as a storage key.
    var id: String { "\(letter.uppercaseName)\(octave)" }

    /// MIDI note number (C4 = 60, A4 = 69).
    var midi: Int { (octave + 1) * 12 + letter.semitone }

    /// Position on the diatonic (white-key) ladder. Adjacent white keys differ by 1.
    var diatonicIndex: Int { octave * 7 + letter.rawValue }

    /// Equal-tempered frequency in Hz (A4 = 440).
    var frequency: Double { 440.0 * pow(2.0, Double(midi - 69) / 12.0) }

    /// Czech, octave-aware name: "C", "c", "c1", "c2" …
    var czechName: String {
        switch octave {
        case ..<2:
            // kontra (C1) and below: written with a number in Czech (C1, C2 …)
            return letter.uppercaseName + String(2 - octave)
        case 2:
            return letter.uppercaseName
        case 3:
            return letter.lowercaseName
        default:
            return letter.lowercaseName + String(octave - 3)
        }
    }

    /// Czech octave name, for stats and hints.
    var czechOctaveName: String {
        switch octave {
        case ..<2: return "kontra"
        case 2: return "velká"
        case 3: return "malá"
        case 4: return "jednočárková"
        case 5: return "dvoučárková"
        case 6: return "tříčárková"
        default: return "čtyřčárková"
        }
    }

    static func < (lhs: Note, rhs: Note) -> Bool {
        lhs.diatonicIndex < rhs.diatonicIndex
    }

    /// All natural notes from `low` to `high` inclusive, ascending.
    static func notes(from low: Note, to high: Note) -> [Note] {
        guard low <= high else { return [] }
        return (low.diatonicIndex...high.diatonicIndex).compactMap { Note(diatonicIndex: $0) }
    }
}
