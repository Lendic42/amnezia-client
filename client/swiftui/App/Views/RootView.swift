import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .share:
                    ShareView()
                case .settings:
                    SettingsView()
                case .add:
                    SetupWizardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                if let message = appState.snackbarMessage {
                    AmneziaSnackbar(message: message)
                        .padding(.bottom, 12)
                }
                tabBar
            }
        }
        .background(AmneziaTheme.bgBase)
        .preferredColorScheme(.dark)
    }

    private var tabBar: some View {
        HStack(spacing: 18) {
            tabButton(icon: "home", tab: .home)
            if appState.showShareTab {
                tabButton(icon: "share-2", tab: .share)
            }
            tabButton(icon: "settings-2", tab: .settings)
            tabButton(icon: "plus", tab: .add)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(AmneziaTheme.bgSurfaceAlt)
        .overlay(
            Rectangle()
                .fill(AmneziaTheme.borderSoft)
                .frame(height: 1),
            alignment: .top
        )
    }

    private func tabButton(icon: String, tab: AppTab) -> some View {
        Button(action: { appState.selectedTab = tab }) {
            AmneziaIcon(name: icon, size: 24)
                .foregroundColor(appState.selectedTab == tab ? AmneziaTheme.accentLight : AmneziaTheme.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
