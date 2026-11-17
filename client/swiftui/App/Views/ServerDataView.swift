import SwiftUI

struct ServerDataView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let server: VPNServer
    @State private var confirm: ConfirmAction?

    private var isConnected: Bool {
        appState.connectionState.isConnected || appState.connectionState.isInProgress
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if server.hasWriteAccess {
                    AmneziaListItem(title: "Check the server for previously installed Amnezia services",
                                    subtitle: "Add them to the application if they were not displayed",
                                    showChevron: true) {
                        appState.showSnackbar("Scanning the server is coming in a later build")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Update server packages",
                                    subtitle: "Install system updates with the distribution's package manager",
                                    showChevron: true) {
                        confirm = .updatePackages
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Reboot server", showChevron: true) {
                        if isConnected {
                            appState.showSnackbar("Cannot reboot server during active connection")
                        } else {
                            confirm = .reboot
                        }
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                }
                AmneziaListItem(title: "Remove server from application", isDestructive: true, showChevron: true) {
                    if isConnected {
                        appState.showSnackbar("Cannot remove server during active connection")
                    } else {
                        confirm = .remove
                    }
                }
                Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                if server.hasWriteAccess {
                    AmneziaListItem(title: "Clear server from Amnezia software", isDestructive: true, showChevron: true) {
                        if isConnected {
                            appState.showSnackbar("Cannot clear server from Amnezia software during active connection")
                        } else {
                            confirm = .clear
                        }
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                }
                if server.isFromApi {
                    AmneziaListItem(title: "Reset API config", isDestructive: true, showChevron: true) {
                        if isConnected {
                            appState.showSnackbar("Cannot reset API config during active connection")
                        } else {
                            confirm = .resetApi
                        }
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                }
            }
            .padding(.top, 24)
        }
        .alert(item: $confirm) { action in
            Alert(
                title: Text(action.headerText),
                message: Text(action.descriptionText),
                primaryButton: .default(Text(action.yesButtonText)) {
                    perform(action)
                },
                secondaryButton: .cancel(Text(action.noButtonText))
            )
        }
    }

    private func perform(_ action: ConfirmAction) {
        switch action {
        case .updatePackages, .reboot, .clear, .resetApi:
            appState.showSnackbar("Server management over SSH is coming in a later build")
        case .remove:
            appState.removeServer(id: server.id)
            dismiss()
        }
    }

    private enum ConfirmAction: Identifiable {
        case updatePackages
        case reboot
        case remove
        case clear
        case resetApi

        var id: String { headerText }

        var headerText: String {
            switch self {
            case .updatePackages: return "Do you want to update packages on the server?"
            case .reboot: return "Do you want to reboot the server?"
            case .remove: return "Do you want to remove the server from application?"
            case .clear: return "Do you want to clear server from Amnezia software?"
            case .resetApi: return "Do you want to reset API config?"
            }
        }

        var descriptionText: String {
            switch self {
            case .updatePackages: return "The update may take several minutes. Amnezia services on the server may restart briefly. The server will not be rebooted."
            case .reboot: return "The reboot process may take approximately 30 seconds. Are you sure you wish to proceed?"
            case .remove: return "All installed AmneziaVPN services will still remain on the server."
            case .clear: return "All users whom you shared a connection with will no longer be able to connect to it."
            case .resetApi: return ""
            }
        }

        var yesButtonText: String {
            switch self {
            case .updatePackages, .reboot, .remove, .clear, .resetApi: return "Continue"
            }
        }

        var noButtonText: String { "Cancel" }
    }
}
