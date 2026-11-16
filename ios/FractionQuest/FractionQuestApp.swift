import SwiftUI
import AVFoundation

@main
struct FractionQuestApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var game = GameController()

    init() {
        // Let the read-aloud voice play out loud even if the device is on silent.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            GameView(game: game)
                .ignoresSafeArea()
                .statusBarHidden(true)
                .background(Color(red: 0.06, green: 0.11, blue: 0.10))
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { game.refreshIfStale() }
            if phase == .background { game.wentToBackground() }
        }
    }
}
