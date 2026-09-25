import Foundation
import Combine

/// User settings, persisted in `UserDefaults`.
final class AppSettings: ObservableObject {
    private enum Key {
        static let clefChoice = "settings.clefChoice"
        static let range = "settings.range"
        static let answerMode = "settings.answerMode"
        static let pianoLabels = "settings.pianoLabels"
        static let soundOn = "settings.soundOn"
        static let hapticsOn = "settings.hapticsOn"
    }

    @Published var clefChoice: ClefChoice {
        didSet { defaults.set(clefChoice.rawValue, forKey: Key.clefChoice) }
    }
    @Published var range: RangePreset {
        didSet { defaults.set(range.rawValue, forKey: Key.range) }
    }
    @Published var answerMode: AnswerMode {
        didSet { defaults.set(answerMode.rawValue, forKey: Key.answerMode) }
    }
    @Published var pianoLabels: Bool {
        didSet { defaults.set(pianoLabels, forKey: Key.pianoLabels) }
    }
    @Published var soundOn: Bool {
        didSet { defaults.set(soundOn, forKey: Key.soundOn) }
    }
    @Published var hapticsOn: Bool {
        didSet { defaults.set(hapticsOn, forKey: Key.hapticsOn) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        clefChoice = ClefChoice(rawValue: defaults.string(forKey: Key.clefChoice) ?? "") ?? .treble
        range = RangePreset(rawValue: defaults.string(forKey: Key.range) ?? "") ?? .beginner
        answerMode = AnswerMode(rawValue: defaults.string(forKey: Key.answerMode) ?? "") ?? .letters
        pianoLabels = defaults.object(forKey: Key.pianoLabels) as? Bool ?? true
        soundOn = defaults.object(forKey: Key.soundOn) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Key.hapticsOn) as? Bool ?? true
    }

    /// e.g. "Treble c1–g2 · Bass F–c1"
    var rangeSummary: String {
        clefChoice.clefs
            .map { "\($0.title) \(range.summary(for: $0))" }
            .joined(separator: " · ")
    }
}
