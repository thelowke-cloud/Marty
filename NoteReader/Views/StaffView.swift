import SwiftUI

/// Five-line staff with a clef, an optional whole note and its ledger lines.
/// Drawn with `Canvas`; note placement comes from `Clef.staffStep(for:)`.
struct StaffView: View {
    let clef: Clef
    let note: Note?
    var ink: Color = Theme.ink

    var body: some View {
        Canvas { context, size in
            // One staff space in points. Leaves room for two ledger lines each way and the clef.
            let space = min(size.height / 11.0, 26)
            let bottomY = size.height / 2 + 2 * space
            let left = space * 0.6
            let right = size.width - space * 0.6
            let lineWidth = max(1.0, space * 0.075)

            func y(step: Int) -> CGFloat {
                bottomY - CGFloat(step) * space / 2
            }

            // Staff lines
            var lines = Path()
            for i in 0..<5 {
                let yy = bottomY - CGFloat(i) * space
                lines.move(to: CGPoint(x: left, y: yy))
                lines.addLine(to: CGPoint(x: right, y: yy))
            }
            context.stroke(lines, with: .color(ink), lineWidth: lineWidth)

            // Clef
            let clefX = left + space * 1.9
            switch clef {
            case .treble:
                StaffView.drawTrebleClef(in: &context, centerX: clefX, bottomY: bottomY, space: space, color: ink)
            case .bass:
                StaffView.drawBassClef(in: &context, centerX: clefX, bottomY: bottomY, space: space, color: ink)
            }

            // Note
            if let note = note {
                let step = clef.staffStep(for: note)
                let noteX = left + (right - left) * 0.64
                let noteY = y(step: step)

                // Ledger lines
                var ledgers = Path()
                for ledgerStep in Clef.ledgerSteps(for: step) {
                    let ly = y(step: ledgerStep)
                    ledgers.move(to: CGPoint(x: noteX - space * 1.15, y: ly))
                    ledgers.addLine(to: CGPoint(x: noteX + space * 1.15, y: ly))
                }
                context.stroke(ledgers, with: .color(ink), lineWidth: lineWidth * 1.15)

                // Whole-note head: outer ellipse minus a tilted inner ellipse (even-odd fill).
                let outerW = space * 1.55
                let outerH = space * 1.02
                let innerW = space * 0.86
                let innerH = space * 0.62
                var head = Path()
                head.addEllipse(in: CGRect(x: noteX - outerW / 2, y: noteY - outerH / 2, width: outerW, height: outerH))
                var inner = Path()
                inner.addEllipse(in: CGRect(x: -innerW / 2, y: -innerH / 2, width: innerW, height: innerH))
                let transform = CGAffineTransform(translationX: noteX, y: noteY).rotated(by: -0.55)
                head.addPath(inner.applying(transform))
                context.fill(head, with: .color(ink), style: FillStyle(eoFill: true))
            }
        }
    }

    // MARK: - Clef glyphs (stylised Bézier paths, drawn in staff-space units)

    /// Converts staff-space coordinates (u = spaces right of `centerX`, v = spaces above the bottom line).
    private static func point(_ u: CGFloat, _ v: CGFloat, centerX: CGFloat, bottomY: CGFloat, space: CGFloat) -> CGPoint {
        CGPoint(x: centerX + u * space, y: bottomY - v * space)
    }

    static func drawTrebleClef(in context: inout GraphicsContext, centerX: CGFloat, bottomY: CGFloat, space: CGFloat, color: Color) {
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            point(u, v, centerX: centerX, bottomY: bottomY, space: space)
        }
        var path = Path()
        // Bottom hook
        path.move(to: p(-0.15, -1.05))
        path.addCurve(to: p(0.5, -1.45), control1: p(-0.25, -1.55), control2: p(0.25, -1.7))
        path.addCurve(to: p(0.75, -0.6), control1: p(0.8, -1.3), control2: p(0.92, -0.95))
        // Stem up through the staff
        path.addCurve(to: p(0.55, 5.9), control1: p(0.6, 1.5), control2: p(1.05, 4.2))
        // Top loop, coming back down on the left
        path.addCurve(to: p(-0.05, 4.05), control1: p(0.35, 6.75), control2: p(-0.05, 5.55))
        // Descending sweep to the right
        path.addCurve(to: p(1.0, 2.15), control1: p(-0.05, 3.15), control2: p(0.75, 2.75))
        // Around the bottom of the spiral
        path.addCurve(to: p(0.25, 0.1), control1: p(1.25, 1.55), control2: p(1.05, 0.15))
        // Up the left side
        path.addCurve(to: p(-0.78, 1.15), control1: p(-0.45, 0.05), control2: p(-0.88, 0.6))
        // Over the top of the spiral
        path.addCurve(to: p(0.2, 2.02), control1: p(-0.72, 1.8), control2: p(-0.3, 2.1))
        // Inward curl to the G line
        path.addCurve(to: p(0.55, 1.2), control1: p(0.75, 1.95), control2: p(0.85, 1.4))
        path.addCurve(to: p(0.12, 0.98), control1: p(0.4, 1.02), control2: p(0.25, 0.94))

        let style = StrokeStyle(lineWidth: max(1.5, space * 0.2), lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(color), style: style)
        // Small ball at the bottom hook
        let r = space * 0.22
        let hook = p(-0.15, -1.05)
        context.fill(Path(ellipseIn: CGRect(x: hook.x - r, y: hook.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
    }

    static func drawBassClef(in context: inout GraphicsContext, centerX: CGFloat, bottomY: CGFloat, space: CGFloat, color: Color) {
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            point(u - 0.4, v, centerX: centerX, bottomY: bottomY, space: space)
        }
        var path = Path()
        path.move(to: p(0.05, 3.0))
        path.addCurve(to: p(0.6, 4.05), control1: p(0.05, 3.6), control2: p(0.25, 4.05))
        path.addCurve(to: p(1.3, 3.0), control1: p(1.05, 4.05), control2: p(1.3, 3.55))
        path.addCurve(to: p(-0.2, 0.15), control1: p(1.3, 1.6), control2: p(0.55, 0.7))
        let style = StrokeStyle(lineWidth: max(1.5, space * 0.2), lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(color), style: style)

        // Starting blob on the F line and the two dots
        let blobR = space * 0.3
        let start = p(0.15, 3.0)
        context.fill(Path(ellipseIn: CGRect(x: start.x - blobR, y: start.y - blobR, width: 2 * blobR, height: 2 * blobR)), with: .color(color))
        let dotR = space * 0.16
        for v in [3.5, 2.5] as [CGFloat] {
            let c = p(1.75, v)
            context.fill(Path(ellipseIn: CGRect(x: c.x - dotR, y: c.y - dotR, width: 2 * dotR, height: 2 * dotR)), with: .color(color))
        }
    }
}
