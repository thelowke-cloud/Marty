import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var stats: StatsStore
    @State private var showResetConfirm = false

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Clef")
                        PillPicker(options: ClefChoice.allCases, selection: $settings.clefChoice) { $0.title }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Range")
                        PillPicker(options: RangePreset.allCases, selection: $settings.range) { $0.title }
                        Text(rangeExplanation)
                            .font(.footnote)
                            .foregroundColor(Theme.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Answer with")
                        PillPicker(options: AnswerMode.allCases, selection: $settings.answerMode) { $0.title }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Letter labels on piano keys", isOn: $settings.pianoLabels)
                    Divider()
                    Toggle("Sound", isOn: $settings.soundOn)
                    Text("Silent switch mutes sounds. Your music keeps playing.")
                        .font(.footnote)
                        .foregroundColor(Theme.secondary)
                    Divider()
                    Toggle("Haptics", isOn: $settings.hapticsOn)
                }
                .tint(Theme.accent)
                .foregroundColor(Theme.ink)
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset stats and personal bests", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(Theme.wrong)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .card()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Note Reader \(version)")
                    Text("Czech note names (h instead of b). Middle C is c1.")
                }
                .font(.footnote)
                .foregroundColor(Theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset all stats?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { stats.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Per-note statistics, sprint scores and best streaks will be deleted.")
        }
    }

    private var rangeExplanation: String {
        switch settings.range {
        case .beginner:
            return "Treble c1–g2, bass F–c1. Only the c1 ledger line."
        case .intermediate:
            return "Treble a–c3, bass C–e1. Two ledger lines above and below."
        }
    }
}
