import Foundation
import NetworkExtension

enum ConnectionState: String {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case disconnecting
    case preparing

    var text: String {
        switch self {
        case .disconnected: return "Connect"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting..."
        case .disconnecting: return "Disconnecting..."
        case .preparing: return "Preparing..."
        }
    }

    var isConnected: Bool { self == .connected }
    var isInProgress: Bool { self == .connecting || self == .reconnecting || self == .disconnecting || self == .preparing }
}

protocol AmneziaCore: AnyObject {
    var connectionState: ConnectionState { get }
    var lastConnectionError: String { get }
    var hasServers: Bool { get }
    var defaultServer: VPNServer? { get }
    var servers: [VPNServer] { get }
    var defaultServerId: String? { get set }
    var settings: SettingsStore { get }
    var splitTunneling: SplitTunnelingStore { get }
    var serverStore: ServerStore { get }

    func toggleConnection()
    func connect()
    func disconnect()
    func clearLastConnectionError()
    func setDefaultServer(id: String)
    func setDefaultContainer(serverId: String, containerIndex: Int)
    func removeServer(id: String)
    func renameServer(id: String, name: String)
    func importConfig(_ imported: ImportedConfig)
    func refreshTunnelStatus()
    func observeConnectionState(_ handler: @escaping (ConnectionState) -> Void)
}

final class LocalCore: AmneziaCore {
    let serverStore: ServerStore
    let settings: SettingsStore
    let splitTunneling: SplitTunnelingStore

    private var stateHandlers: [(ConnectionState) -> Void] = []
    private let tunnelController: TunnelController
    private var statusTimer: Timer?

    private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            guard oldValue != connectionState else { return }
            for handler in stateHandlers {
                handler(connectionState)
            }
        }
    }

    var lastConnectionError: String = ""

    func clearLastConnectionError() {
        lastConnectionError = ""
    }

    var hasServers: Bool { !serverStore.servers.isEmpty }
    var defaultServer: VPNServer? { serverStore.defaultServer }
    var servers: [VPNServer] { serverStore.servers }

    var defaultServerId: String? {
        get { serverStore.defaultServerId }
        set { serverStore.defaultServerId = newValue }
    }

    init(defaults: UserDefaults = UserDefaults(suiteName: BuildConfig.appGroupIdentifier) ?? .standard) {
        self.serverStore = ServerStore(defaults: defaults)
        self.settings = SettingsStore(defaults: defaults)
        self.splitTunneling = SplitTunnelingStore(defaults: defaults)
        self.settings.checkLoggingExpiry()
        self.tunnelController = TunnelController()
        self.tunnelController.onStatusChange = { [weak self] status in
            self?.applyTunnelStatus(status)
        }
        refreshTunnelStatus()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshTunnelStatus()
        }
    }

    func observeConnectionState(_ handler: @escaping (ConnectionState) -> Void) {
        stateHandlers.append(handler)
        handler(connectionState)
    }

    func toggleConnection() {
        if connectionState.isConnected || connectionState == .connecting {
            disconnect()
        } else {
            connect()
        }
    }

    func connect() {
        guard let server = defaultServer else { return }
        guard let container = server.defaultContainer, container.isInstalled else {
            lastConnectionError = "No installed VPN containers on this server"
            return
        }
        guard WGConfigBuilder.isWireGuardContainer(container) else {
            lastConnectionError = "This protocol is not supported in this build yet"
            return
        }
        guard let wgConfigData = WGConfigBuilder.buildWGConfigJSON(server: server, settings: settings, splitTunneling: splitTunneling) else {
            lastConnectionError = "Invalid configuration"
            return
        }
        connectionState = .preparing
        tunnelController.startTunnel(wgConfigData: wgConfigData, serverAddress: server.hostName) { [weak self] error in
            guard let self else { return }
            if let error {
                self.lastConnectionError = error
                self.connectionState = .disconnected
            } else {
                self.connectionState = .connecting
                self.refreshTunnelStatus()
            }
        }
    }

    func disconnect() {
        connectionState = .disconnecting
        tunnelController.stopTunnel { [weak self] _ in
            self?.connectionState = .disconnected
            self?.refreshTunnelStatus()
        }
    }

    func setDefaultServer(id: String) {
        serverStore.defaultServerId = id
    }

    func setDefaultContainer(serverId: String, containerIndex: Int) {
        guard var server = serverStore.servers.first(where: { $0.id == serverId }),
              server.containers.indices.contains(containerIndex) else { return }
        server.defaultContainerIndex = containerIndex
        serverStore.update(server)
    }

    func removeServer(id: String) {
        serverStore.remove(serverId: id)
    }

    func renameServer(id: String, name: String) {
        guard var server = serverStore.servers.first(where: { $0.id == id }) else { return }
        server.name = name
        serverStore.update(server)
    }

    func importConfig(_ imported: ImportedConfig) {
        serverStore.add(imported.server)
    }

    func refreshTunnelStatus() {
        tunnelController.loadStatus { [weak self] status in
            self?.applyTunnelStatus(status)
        }
    }

    private func applyTunnelStatus(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            connectionState = .connected
        case .connecting:
            if connectionState != .connected {
                connectionState = .connecting
            }
        case .reasserting:
            connectionState = .reconnecting
        case .disconnecting:
            connectionState = .disconnecting
        case .disconnected, .invalid:
            if connectionState != .preparing {
                connectionState = .disconnected
            }
        @unknown default:
            break
        }
    }
}

final class TunnelController {
    var onStatusChange: ((NEVPNStatus) -> Void)?

    func startTunnel(wgConfigData: Data, serverAddress: String, completion: @escaping (String?) -> Void) {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences { error in
            if let error {
                completion(error.localizedDescription)
                return
            }
            let tunnelProtocol = NETunnelProviderProtocol()
            tunnelProtocol.providerBundleIdentifier = BuildConfig.networkExtensionBundleIdentifier
            tunnelProtocol.serverAddress = serverAddress
            tunnelProtocol.providerConfiguration = ["wireguard": wgConfigData]
            tunnelProtocol.disconnectOnSleep = false
            manager.protocolConfiguration = tunnelProtocol
            manager.isEnabled = true
            manager.saveToPreferences { saveError in
                if let saveError {
                    completion(saveError.localizedDescription)
                    return
                }
                manager.loadFromPreferences { _ in
                    do {
                        try manager.connection.startVPNTunnel()
                        completion(nil)
                    } catch {
                        completion(error.localizedDescription)
                    }
                }
            }
        }
    }

    func stopTunnel(completion: @escaping (Bool) -> Void) {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences { _ in
            manager.connection.stopVPNTunnel()
            completion(true)
        }
    }

    func loadStatus(completion: @escaping (NEVPNStatus) -> Void) {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences { _ in
            completion(manager.connection.status)
        }
    }
}
