import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var stats: StatsStore
    @State private var activeMode: GameMode?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    setupCard
                    modeCards
                    linksRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $activeMode) { mode in
            GameView(mode: mode)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Note Reader")
                    .font(Theme.display(40))
                    .foregroundColor(Theme.ink)
                Text("Read notes faster, one at a time.")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondary)
            }
            StaffView(clef: settings.clefChoice == .bass ? .bass : .treble,
                      note: settings.clefChoice == .bass ? Note(.d, 3) : Note(.g, 4))
                .frame(height: 120)
                .card(padding: 10)
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Clef")
                PillPicker(options: ClefChoice.allCases, selection: $settings.clefChoice) { $0.title }
            }
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Range")
                PillPicker(options: RangePreset.allCases, selection: $settings.range) { $0.title }
            }
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Answer with")
                PillPicker(options: AnswerMode.allCases, selection: $settings.answerMode) { $0.title }
            }
            Text(settings.rangeSummary)
                .font(.footnote)
                .foregroundColor(Theme.secondary)
        }
        .card()
    }

    private var modeCards: some View {
        VStack(spacing: 10) {
            ForEach(GameMode.allCases) { mode in
                Button {
                    activeMode = mode
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mode.symbolName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Theme.accentSoft))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.title)
                                .font(Theme.display(22))
                                .foregroundColor(Theme.ink)
                            Text(mode.subtitle)
                                .font(.footnote)
                                .foregroundColor(Theme.secondary)
                                .multilineTextAlignment(.leading)
                            if let best = bestText(for: mode) {
                                Text(best)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Theme.correct)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Theme.secondary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func bestText(for mode: GameMode) -> String? {
        switch mode {
        case .practice:
            return nil
        case .sprint:
            if let best = stats.sprintBest(clefChoice: settings.clefChoice, range: settings.range) {
                return "Best: \(best) points"
            }
            return nil
        case .streak:
            if let best = stats.streakBest(clefChoice: settings.clefChoice, range: settings.range), best > 0 {
                return "Best: \(best) in a row"
            }
            return nil
        }
    }

    private var linksRow: some View {
        HStack(spacing: 10) {
            NavigationLink {
                StatsView()
            } label: {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            .buttonStyle(SecondaryButtonStyle())

            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}
