import Foundation
import Combine

/// Drives one run of a game mode. Must be used from the main thread.
final class GameSession: ObservableObject {
    enum Phase: Equatable {
        case playing
        case feedback
        case finished
    }

    struct Feedback: Equatable {
        let correct: Bool
        let answered: Note
        let expected: Prompt
        let ms: Int
    }

    static let sprintDuration: TimeInterval = 60
    static let correctDelay: TimeInterval = 0.45
    static let wrongDelay: TimeInterval = 1.3

    let mode: GameMode
    let clefChoice: ClefChoice
    let range: RangePreset

    @Published private(set) var prompt: Prompt
    @Published private(set) var isRetry: Bool
    @Published private(set) var phase: Phase = .playing
    @Published private(set) var feedback: Feedback?
    @Published private(set) var correctCount = 0
    @Published private(set) var wrongCount = 0
    /// Sprint score (+1 / −1).
    @Published private(set) var score = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreakInRun = 0
    @Published private(set) var totalMs = 0
    @Published private(set) var lastResponseMs: Int?
    @Published private(set) var timeRemaining: TimeInterval = GameSession.sprintDuration
    @Published private(set) var isNewBest = false
    /// Personal best after this run has been submitted (sprint score or streak).
    @Published private(set) var personalBest: Int?

    private let settings: AppSettings
    private let stats: StatsStore
    private let synth: ToneSynth
    private let pool: [Prompt]
    private var picker: NotePicker
    private var shownAt = Date()
    private var sprintEnd: Date?
    private var timer: Timer?
    private var advanceWork: DispatchWorkItem?
    private var started = false

    init(mode: GameMode, settings: AppSettings, stats: StatsStore, synth: ToneSynth) {
        self.mode = mode
        self.settings = settings
        self.stats = stats
        self.synth = synth
        self.clefChoice = settings.clefChoice
        self.range = settings.range

        let pool = settings.clefChoice.clefs.flatMap { clef in
            settings.range.notes(for: clef).map { Prompt(clef: clef, note: $0) }
        }
        self.pool = pool

        var picker = NotePicker(weights: stats.data.weights)
        let first = picker.next(from: pool, stats: stats)
        self.picker = picker
        self.prompt = first?.prompt ?? Prompt(clef: .treble, note: Note(.c, 4))
        self.isRetry = first?.isRetry ?? false
    }

    deinit {
        timer?.invalidate()
        advanceWork?.cancel()
    }

    // MARK: - Derived values

    var attempts: Int { correctCount + wrongCount }

    var accuracy: Double {
        attempts == 0 ? 0 : Double(correctCount) / Double(attempts)
    }

    var averageMs: Int {
        attempts == 0 ? 0 : totalMs / attempts
    }

    /// Answer choices for the current prompt (its clef and the chosen range).
    var answerNotes: [Note] {
        range.notes(for: prompt.clef)
    }

    // MARK: - Lifecycle

    /// Starts the clock. Safe to call more than once.
    func start() {
        guard !started else { return }
        started = true
        shownAt = Date()
        if mode == .sprint {
            let end = Date().addingTimeInterval(GameSession.sprintDuration)
            sprintEnd = end
            timeRemaining = GameSession.sprintDuration
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    /// Ends the run early (user closed the screen). Does not change `phase`.
    func stop() {
        timer?.invalidate()
        timer = nil
        advanceWork?.cancel()
        advanceWork = nil
        stats.saveWeights(picker.weights)
        // A streak reached before quitting still counts; an abandoned sprint does not.
        if mode == .streak && phase != .finished {
            stats.submitStreak(bestStreakInRun, clefChoice: clefChoice, range: range)
        }
    }

    // MARK: - Answering

    func answer(_ note: Note) {
        guard phase == .playing else { return }
        let elapsed = Int(Date().timeIntervalSince(shownAt) * 1000)
        let correct = note == prompt.note
        let current = prompt

        stats.record(prompt: current, correct: correct, ms: elapsed)
        totalMs += elapsed
        lastResponseMs = elapsed

        if correct {
            correctCount += 1
            streak += 1
            bestStreakInRun = max(bestStreakInRun, streak)
            score += 1
            picker.registerHit(current)
        } else {
            wrongCount += 1
            streak = 0
            score -= 1
            picker.registerMiss(current)
        }
        stats.saveWeights(picker.weights)

        feedback = Feedback(correct: correct, answered: note, expected: current, ms: elapsed)
        phase = .feedback

        if settings.soundOn {
            synth.play(note: current.note)
        }
        if settings.hapticsOn {
            Task { @MainActor in
                if correct { Haptics.light() } else { Haptics.error() }
            }
        }

        let delay = correct ? GameSession.correctDelay : GameSession.wrongDelay
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.mode == .streak && !correct {
                self.finish()
            } else {
                self.advance()
            }
        }
        advanceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func advance() {
        guard phase == .feedback else { return }
        if let pick = picker.next(from: pool, stats: stats) {
            prompt = pick.prompt
            isRetry = pick.isRetry
        }
        feedback = nil
        phase = .playing
        shownAt = Date()
    }

    private func tick() {
        guard let end = sprintEnd, phase != .finished else { return }
        let remaining = max(0, end.timeIntervalSinceNow)
        timeRemaining = remaining
        if remaining <= 0 {
            finish()
        }
    }

    private func finish() {
        guard phase != .finished else { return }
        timer?.invalidate()
        timer = nil
        advanceWork?.cancel()
        advanceWork = nil
        phase = .finished
        stats.saveWeights(picker.weights)
        submitResults()
    }

    private func submitResults() {
        switch mode {
        case .sprint:
            isNewBest = stats.submitSprint(score: score, clefChoice: clefChoice, range: range)
            personalBest = stats.sprintBest(clefChoice: clefChoice, range: range)
        case .streak:
            isNewBest = stats.submitStreak(bestStreakInRun, clefChoice: clefChoice, range: range)
            personalBest = stats.streakBest(clefChoice: clefChoice, range: range)
        case .practice:
            isNewBest = false
            personalBest = nil
        }
    }
}
