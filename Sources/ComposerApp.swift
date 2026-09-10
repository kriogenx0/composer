import SwiftUI

@main
struct ComposerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear { AudioEngine.shared.start() }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Progression") { state.regenerate() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Playback") {
                Button("Play / Stop") {
                    state.isPlaying ? state.stopPlayback() : state.playProgression()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }
}
