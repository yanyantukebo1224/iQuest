import SwiftUI
import UIKit

@main
struct iQuestApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            GameLauncherView()
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                .onChange(of: scenePhase) { _, phase in
                    // Keep the display awake while iQuest is in the foreground.
                    // Restore the system default when the app is backgrounded.
                    UIApplication.shared.isIdleTimerDisabled = (phase == .active)
                }
        }
    }
}
