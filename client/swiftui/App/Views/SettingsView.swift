import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                AmneziaNavigationBar(title: "Settings")
                ScrollView {
                    VStack(spacing: 0) {
                        AmneziaListItem(title: "Servers", iconName: "server", showChevron: true) {
                            navigationPath.append(SettingsDestination.servers)
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Connection", iconName: "globe-2", showChevron: true) {
                            navigationPath.append(SettingsDestination.connection)
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Application", iconName: "settings", showChevron: true) {
                            navigationPath.append(SettingsDestination.application)
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Backup", iconName: "archive-restore", showChevron: true) {
                            appState.showSnackbar("Backup and restore is coming in a later build")
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "About AmneziaVPN", iconName: "info", showChevron: true) {
                            navigationPath.append(SettingsDestination.about)
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        if appState.core.settings.isDevModeEnabled {
                            AmneziaListItem(title: "Dev console", iconName: "bug", showChevron: true) {
                                appState.showSnackbar("Developer console is coming in a later build")
                            }
                            Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        }
                    }
                }
                Spacer()
            }
            .background(AmneziaTheme.bgBase)
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .servers:
                    ServersListView()
                case .connection:
                    ConnectionView()
                case .application:
                    ApplicationView()
                case .about:
                    AboutView()
                }
            }
        }
    }
}

enum SettingsDestination: Hashable {
    case servers
    case connection
    case application
    case about
}

struct ServersListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                AmneziaNavigationBar(title: "Servers", onBack: { dismiss() })
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(appState.servers) { server in
                            HStack(spacing: 12) {
                                Button(action: {
                                    appState.setDefaultServer(id: server.id)
                                }) {
                                    HStack(spacing: 12) {
                                        AmneziaRadioButton(isSelected: server.id == appState.defaultServerId)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(server.name)
                                                .font(AmneziaTheme.Font.body)
                                                .foregroundColor(AmneziaTheme.textPrimary)
                                            Text(server.collapsedDescription)
                                                .font(AmneziaTheme.Font.small)
                                                .foregroundColor(AmneziaTheme.textTertiary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button(action: {
                                    navigationPath.append(server.id)
                                }) {
                                    AmneziaIcon(name: "chevron-right", size: 24)
                                        .foregroundColor(AmneziaTheme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        }
                    }
                    .padding(.top, 12)
                }
                Spacer()
            }
            .background(AmneziaTheme.bgBase)
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { serverId in
                ServerInfoView(serverId: serverId)
            }
        }
    }
}
