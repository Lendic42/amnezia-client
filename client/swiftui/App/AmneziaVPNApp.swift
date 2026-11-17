import SwiftUI

@main
struct AmneziaVPNApp: App {
    @StateObject private var appState: AppState

    init() {
        let core = LocalCore()
        if core.settings.isLoggingEnabled {
            Logger.shared.log("AmneziaVPN started")
        }
        _appState = StateObject(wrappedValue: AppState(core: core))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
