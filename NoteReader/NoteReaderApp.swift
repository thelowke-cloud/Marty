import SwiftUI

@main
struct NoteReaderApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var stats = StatsStore()
    @StateObject private var synth = ToneSynth()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(settings)
                .environmentObject(stats)
                .environmentObject(synth)
                .tint(Theme.accent)
        }
    }
}
