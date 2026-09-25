import UIKit

/// UIKit feedback generators are main-actor isolated; call these from the main actor
/// (or hop with `Task { @MainActor in ... }`).
@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()

    /// Light tap for a correct answer.
    static func light() {
        impact.prepare()
        impact.impactOccurred()
    }

    /// Error buzz for a wrong answer.
    static func error() {
        notification.prepare()
        notification.notificationOccurred(.error)
    }
}
