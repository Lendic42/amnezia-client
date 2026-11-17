import SwiftUI

struct AboutView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var versionTaps = 0

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: "About AmneziaVPN", onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Image("amneziaLogo")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 153, height: 131)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                    HStack {
                        Text("Version \(BuildConfig.appVersion)")
                            .font(AmneziaTheme.Font.body)
                            .foregroundColor(AmneziaTheme.textPrimary)
                            .onTapGesture {
                                versionTaps += 1
                                if versionTaps >= 10 && !appState.core.settings.isDevModeEnabled {
                                    appState.core.settings.isDevModeEnabled = true
                                    appState.showSnackbar("Developer mode enabled")
                                    versionTaps = 0
                                }
                            }
                        Button(action: {
                            appState.copyToClipboard(BuildConfig.appVersion)
                        }) {
                            AmneziaIcon(name: "copy", size: 24)
                                .foregroundColor(AmneziaTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy version")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    Text("Support Amnezia")
                        .font(AmneziaTheme.Font.h2)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                    Text("Amnezia is a free and open-source application. You can support the developers if you like it.")
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Text("Contacts")
                        .font(AmneziaTheme.Font.h3)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    AmneziaListItem(title: "Telegram group", subtitle: "To discuss features", iconName: "telegram", showChevron: true) {
                        openUrl("https://telegram.me/amnezia_vpn_en")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Amnezia Hub Telegram Bot", subtitle: "Ask us anything", iconName: "telegram", showChevron: true) {
                        openUrl("https://telegram.me/amneziahub_bot?start=utm_ioIdiSEUDN")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "support@amnezia.org", subtitle: "For reviews and bug reports", iconName: "mail", showChevron: true) {
                        openUrl("mailto:support@amnezia.org")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "GitHub", subtitle: "Discover the source code", iconName: "github", showChevron: true) {
                        openUrl("https://github.com/amnezia-vpn/amnezia-client")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Website", subtitle: "Visit official website", iconName: "globe-2", showChevron: true) {
                        openUrl("https://amnezia.org")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Check for updates", showChevron: true) {
                        appState.showSnackbar("Update check is coming in a later build")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Privacy Policy", showChevron: true) {
                        openUrl("https://amnezia.org/policy")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                }
                .padding(.bottom, 32)
            }
            Spacer()
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
    }

    private func openUrl(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
