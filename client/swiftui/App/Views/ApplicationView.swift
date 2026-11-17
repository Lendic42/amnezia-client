import SwiftUI

struct ApplicationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    @State private var allowScreenshots = true
    @State private var autoUpdateCheck = true
    @State private var showResetConfirm = false

    private var isConnected: Bool {
        appState.connectionState.isConnected || appState.connectionState.isInProgress
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                AmneziaNavigationBar(title: "Application", onBack: { dismiss() })
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text("Allow application screenshots")
                                .font(AmneziaTheme.Font.body)
                                .foregroundColor(AmneziaTheme.textPrimary)
                            Spacer()
                            AmneziaSwitch(isOn: $allowScreenshots)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check for updates automatically")
                                    .font(AmneziaTheme.Font.body)
                                    .foregroundColor(AmneziaTheme.textPrimary)
                                Text("Check for a new app version at startup")
                                    .font(AmneziaTheme.Font.small)
                                    .foregroundColor(AmneziaTheme.textTertiary)
                            }
                            Spacer()
                            AmneziaSwitch(isOn: $autoUpdateCheck)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Language", subtitle: "English", showChevron: true) {
                            appState.showSnackbar("Language selection is coming in a later build")
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Logging",
                                        subtitle: appState.core.settings.isLoggingEnabled ? "Enabled" : "Disabled",
                                        showChevron: true) {
                            navigationPath.append("logging")
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Reset settings and remove all data from the application",
                                        isDestructive: true,
                                        showChevron: true) {
                            if isConnected {
                                appState.showSnackbar("Cannot reset settings during active connection")
                            } else {
                                showResetConfirm = true
                            }
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    }
                    .padding(.top, 12)
                }
                Spacer()
            }
            .background(AmneziaTheme.bgBase)
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { destination in
                if destination == "logging" {
                    LoggingView()
                }
            }
            .onAppear {
                allowScreenshots = appState.core.settings.isScreenshotsEnabled
                autoUpdateCheck = appState.core.settings.isAutoUpdateCheckEnabled
            }
            .onChange(of: allowScreenshots) { _, newValue in
                appState.core.settings.isScreenshotsEnabled = newValue
            }
            .onChange(of: autoUpdateCheck) { _, newValue in
                appState.core.settings.isAutoUpdateCheckEnabled = newValue
            }
            .alert("Reset settings and remove all data from the application?", isPresented: $showResetConfirm) {
                Button("Continue") {
                    appState.core.settings.resetAll()
                    appState.refresh()
                    appState.showSnackbar("Settings have been reset")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All settings will be reset to default. All installed AmneziaVPN services will still remain on the server.")
            }
        }
    }
}
