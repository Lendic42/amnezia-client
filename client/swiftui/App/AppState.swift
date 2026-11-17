import SwiftUI
import Combine

final class AppState: ObservableObject {
    let core: AmneziaCore

    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastConnectionError: String = ""
    @Published var servers: [VPNServer] = []
    @Published var defaultServerId: String?
    @Published var selectedTab: AppTab = .home
    @Published var snackbarMessage: String?

    private var snackbarTimer: Timer?

    init(core: AmneziaCore) {
        self.core = core
        core.observeConnectionState { [weak self] state in
            DispatchQueue.main.async {
                self?.connectionState = state
            }
        }
        refresh()
    }

    var defaultServer: VPNServer? {
        servers.first { $0.id == defaultServerId } ?? servers.first
    }

    var hasServers: Bool { !servers.isEmpty }

    var showShareTab: Bool {
        defaultServer?.hasWriteAccess == true
    }

    func refresh() {
        servers = core.servers
        defaultServerId = core.defaultServerId
        connectionState = core.connectionState
        lastConnectionError = core.lastConnectionError
    }

    func toggleConnection() {
        core.toggleConnection()
        if !core.lastConnectionError.isEmpty {
            showSnackbar(core.lastConnectionError)
            core.clearLastConnectionError()
        }
        refresh()
    }

    func setDefaultServer(id: String) {
        core.setDefaultServer(id: id)
        refresh()
    }

    func setDefaultContainer(serverId: String, containerIndex: Int) {
        core.setDefaultContainer(serverId: serverId, containerIndex: containerIndex)
        refresh()
    }

    func removeServer(id: String) {
        core.removeServer(id: id)
        refresh()
    }

    func renameServer(id: String, name: String) {
        core.renameServer(id: id, name: name)
        refresh()
    }

    func importConfig(_ imported: ImportedConfig) {
        core.importConfig(imported)
        refresh()
    }

    func showSnackbar(_ message: String) {
        snackbarMessage = message
        snackbarTimer?.invalidate()
        snackbarTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.snackbarMessage = nil
        }
    }

    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showSnackbar("Copied to clipboard")
    }
}

enum AppTab: Int {
    case home
    case share
    case settings
    case add
}
