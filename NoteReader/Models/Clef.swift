import Foundation

/// Staff clefs.
///
/// Staff steps: 0 = bottom line, 1 = first space, 2 = second line, … 8 = top line.
/// Negative steps are below the staff, steps above 8 are above it.
/// Even steps sit on a line (or ledger line), odd steps in a space.
///
/// Full table (Czech name, scientific name):
///
/// TREBLE (bottom line = e1 / E4)          BASS (bottom line = G / G2)
///  step  note              placement        step  note             placement
///   -5   g   (G3)   hangs below ledger 2      -4   C   (C2)   on ledger line 2 (below)
///   -4   a   (A3)   on ledger line 2 (below)  -3   D   (D2)   between ledger 2 and 1
///   -3   h   (H3)   between ledger 2 and 1    -2   E   (E2)   on ledger line 1 (below)
///   -2   c1  (C4)   on ledger line 1 (below)  -1   F   (F2)   just below line 1
///   -1   d1  (D4)   just below line 1          0   G   (G2)   line 1
///    0   e1  (E4)   line 1                     1   A   (A2)   space 1
///    1   f1  (F4)   space 1                    2   H   (H2)   line 2
///    2   g1  (G4)   line 2                     3   c   (C3)   space 2
///    3   a1  (A4)   space 2                    4   d   (D3)   line 3
///    4   h1  (H4)   line 3                     5   e   (E3)   space 3
///    5   c2  (C5)   space 3                    6   f   (F3)   line 4
///    6   d2  (D5)   line 4                     7   g   (G3)   space 4
///    7   e2  (E5)   space 4                    8   a   (A3)   line 5
///    8   f2  (F5)   line 5                     9   h   (H3)   just above line 5
///    9   g2  (G5)   just above line 5         10   c1  (C4)   on ledger line 1 (above)
///   10   a2  (A5)   on ledger line 1 (above)  11   d1  (D4)   between ledger 1 and 2
///   11   h2  (H5)   between ledger 1 and 2    12   e1  (E4)   on ledger line 2 (above)
///   12   c3  (C6)   on ledger line 2 (above)  13   f1  (F4)   sits above ledger 2
///   13   d3  (D6)   sits above ledger 2
///
/// Ledger lines: for step s < 0 draw lines at -2, -4, … while >= s.
///               for step s > 8 draw lines at 10, 12, … while <= s.
enum Clef: String, CaseIterable, Codable, Identifiable, Hashable {
    case treble
    case bass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .treble: return "Treble"
        case .bass: return "Bass"
        }
    }

    /// The note sitting on the bottom staff line.
    var bottomLineNote: Note {
        switch self {
        case .treble: return Note(.e, 4)
        case .bass: return Note(.g, 2)
        }
    }

    /// Staff step of `note` relative to the bottom line (see table above).
    func staffStep(for note: Note) -> Int {
        note.diatonicIndex - bottomLineNote.diatonicIndex
    }

    /// Inverse of `staffStep(for:)`.
    func note(atStaffStep step: Int) -> Note? {
        Note(diatonicIndex: bottomLineNote.diatonicIndex + step)
    }

    /// Ledger line steps required to draw a note at `step`.
    static func ledgerSteps(for step: Int) -> [Int] {
        var result: [Int] = []
        if step < 0 {
            var s = -2
            while s >= step {
                result.append(s)
                s -= 2
            }
        } else if step > 8 {
            var s = 10
            while s <= step {
                result.append(s)
                s += 2
            }
        }
        return result
    }
}
