import SwiftUI

@main
struct DOACBorderApp: App {
    @StateObject private var updates = UpdateManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Without this, the window can get stuck at a stale/too-small size
        // (e.g. from macOS window-frame restoration) and clip content added
        // since -- always resize the window to fit ContentView's ideal size.
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updates.checkForUpdates() }
            }
        }
    }
}
