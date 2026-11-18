import Foundation
import NetworkExtension

struct CoreError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

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

struct ImportPreview: Hashable {
    var fileName: String
    var displayText: String
    var isNativeWireGuardConfig: Bool
    var maliciousWarningText: String
}

enum NativeExportFormat {
    case wireGuard
    case awg
    case openVpn
    case xray
}

enum DockerContainerIndex {
    static func index(forKey key: String) -> Int {
        switch key {
        case "amnezia-awg": return 1
        case "amnezia-awg2": return 2
        case "amnezia-wireguard": return 3
        case "amnezia-openvpn": return 4
        case "amnezia-openvpn-cloak": return 5
        case "amnezia-shadowsocks": return 6
        case "amnezia-ipsec": return 7
        case "amnezia-xray": return 8
        case "amnezia-ssxray": return 9
        case "amnezia-torwebsite": return 10
        case "amnezia-dns": return 11
        case "amnezia-sftp": return 12
        case "amnezia-socks5proxy": return 13
        case "amnezia-mtproxy": return 14
        case "amnezia-telemt": return 15
        case "amnezia-tproxy": return 16
        default: return 0
        }
    }
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
    var onImportPreview: ((ImportPreview) -> Void)? { get set }

    func toggleConnection()
    func clearLastConnectionError()
    func setDefaultServer(id: String)
    func setDefaultContainer(serverId: String, containerIndex: Int)
    func removeServer(id: String)
    func renameServer(id: String, name: String)
    func refreshServers()
    func observeConnectionState(_ handler: @escaping (ConnectionState) -> Void)
    func extractConfig(data: String) -> ImportPreview?
    func importExtractedConfig(processObfuscation: Bool, completion: @escaping (Result<String, CoreError>) -> Void)
    func startQrDecoding()
    func parseQrCodeChunk(_ code: String) -> Bool
    var qrProgressValue: Double { get }
    var qrProgressString: String { get }
    func validateServerConfig(id: String, completion: @escaping (String?) -> Void)
    func exportConnectionKey(serverId: String, containerIndex: Int, clientName: String, completion: @escaping (Result<String, CoreError>) -> Void)
    func exportNativeConfig(serverId: String, containerIndex: Int, format: NativeExportFormat, clientName: String, completion: @escaping (Result<String, CoreError>) -> Void)
    func exportFullAccessKey(serverId: String, completion: @escaping (Result<String, CoreError>) -> Void)
    func exportVpnKey(serverId: String, completion: @escaping (Result<String, CoreError>) -> Void)
}

final class AmneziaCoreAdapter: AmneziaCore {
    let settings: SettingsStore
    let splitTunneling: SplitTunnelingStore
    var onImportPreview: ((ImportPreview) -> Void)?

    private let bridge: AmneziaCoreBridge?
    private var cachedServers: [VPNServer] = []
    private var stateHandlers: [(ConnectionState) -> Void] = []
    private var statusTimer: Timer?
    private var lastImportErrorCode: Int = 0
    private var pendingImportCompletion: ((Result<String, CoreError>) -> Void)?
    private var pendingImportBeforeIds: Set<String> = []

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

    var hasServers: Bool { !cachedServers.isEmpty }
    var defaultServer: VPNServer? {
        if let id = defaultServerId {
            return cachedServers.first { $0.id == id }
        }
        return cachedServers.first
    }
    var servers: [VPNServer] { cachedServers }

    var defaultServerId: String? {
        get {
            guard let id = bridge?.defaultServerId(), !id.isEmpty else { return nil }
            return id
        }
        set {
            if let newValue {
                bridge?.setDefaultServer(newValue)
            }
            refreshServers()
        }
    }

    init(defaults: UserDefaults = UserDefaults(suiteName: BuildConfig.appGroupIdentifier) ?? .standard) {
        self.settings = SettingsStore(defaults: defaults)
        self.splitTunneling = SplitTunnelingStore(defaults: defaults)
        self.settings.checkLoggingExpiry()
        self.bridge = AmneziaCoreBootstrap.createBridge()
        if let bridge {
            bridge.setConnectionStateChangedHandler { [weak self] in
                DispatchQueue.main.async {
                    self?.refreshConnectionState()
                }
            }
            bridge.setConnectionErrorHandler { [weak self] code in
                DispatchQueue.main.async {
                    self?.lastConnectionError = bridge.errorMessage(forCode: code)
                    self?.refreshConnectionState()
                }
            }
            bridge.setNoInstalledContainersHandler { [weak self] in
                DispatchQueue.main.async {
                    self?.lastConnectionError = "No installed VPN containers on this server"
                    self?.refreshConnectionState()
                }
            }
            bridge.setImportFinishedHandler { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.refreshServers()
                    let newId = self.cachedServers.map { $0.id }.first { !self.pendingImportBeforeIds.contains($0) }
                    let completion = self.pendingImportCompletion
                    self.pendingImportCompletion = nil
                    self.pendingImportBeforeIds = []
                    completion?(.success(newId ?? self.defaultServerId ?? ""))
                }
            }
            bridge.setImportErrorHandler { [weak self] code, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.lastImportErrorCode = code
                    let completion = self.pendingImportCompletion
                    self.pendingImportCompletion = nil
                    self.pendingImportBeforeIds = []
                    if let completion {
                        completion(.failure(CoreError(message: bridge.errorMessage(forCode: code))))
                    } else {
                        self.lastConnectionError = bridge.errorMessage(forCode: code)
                    }
                }
            }
            bridge.setQrDecodingFinishedHandler { [weak self] in
                DispatchQueue.main.async {
                    guard let self, let preview = self.makeImportPreview() else { return }
                    self.onImportPreview?(preview)
                }
            }
        } else {
            lastConnectionError = "Core unavailable"
        }
        refreshServers()
        refreshConnectionState()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshConnectionState()
        }
    }

    func observeConnectionState(_ handler: @escaping (ConnectionState) -> Void) {
        stateHandlers.append(handler)
        handler(connectionState)
    }

    func toggleConnection() {
        bridge?.toggleConnection()
        refreshConnectionState()
    }

    func setDefaultServer(id: String) {
        bridge?.setDefaultServer(id)
        refreshServers()
    }

    func setDefaultContainer(serverId: String, containerIndex: Int) {
        guard let bridge,
              let server = cachedServers.first(where: { $0.id == serverId }),
              server.containers.indices.contains(containerIndex) else { return }
        bridge.setDefaultContainer(serverId, containerIndex: DockerContainerIndex.index(forKey: server.containers[containerIndex].key))
        refreshServers()
    }

    func removeServer(id: String) {
        bridge?.removeServer(id)
        refreshServers()
    }

    func renameServer(id: String, name: String) {
        bridge?.editServerName(id, name: name)
        refreshServers()
    }

    func refreshServers() {
        guard let bridge else {
            cachedServers = []
            return
        }
        var servers: [VPNServer] = []
        for index in 0..<bridge.getServersCount() {
            let id = bridge.serverId(at: index)
            guard !id.isEmpty,
                  let data = bridge.serverJson(id).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  var server = AmneziaCoreAdapter.buildServer(id: id, json: json) else { continue }
            server.isSubscriptionExpired = bridge.isServerSubscriptionExpired(id)
            server.isSubscriptionExpiringSoon = bridge.isServerSubscriptionExpiringSoon(id)
            servers.append(server)
        }
        cachedServers = servers
    }

    func extractConfig(data: String) -> ImportPreview? {
        guard let bridge else { return nil }
        lastImportErrorCode = 0
        guard bridge.extractConfig(fromData: data) else {
            lastConnectionError = lastImportErrorCode == 0 ? "Invalid configuration" : bridge.errorMessage(forCode: lastImportErrorCode)
            return nil
        }
        return makeImportPreview()
    }

    func importExtractedConfig(processObfuscation: Bool, completion: @escaping (Result<String, CoreError>) -> Void) {
        guard let bridge else {
            completion(.failure(CoreError(message: "Core unavailable")))
            return
        }
        if processObfuscation {
            bridge.processNativeWireGuardConfig()
        }
        pendingImportCompletion = completion
        pendingImportBeforeIds = Set(cachedServers.map { $0.id })
        bridge.importConfig()
    }

    func startQrDecoding() {
        bridge?.startDecodingQr()
    }

    func parseQrCodeChunk(_ code: String) -> Bool {
        bridge?.parseQrCodeChunk(code) ?? false
    }

    var qrProgressValue: Double {
        bridge?.qrCodeScanProgressBarValue() ?? 0
    }

    var qrProgressString: String {
        bridge?.qrCodeScanProgressString() ?? ""
    }

    func validateServerConfig(id: String, completion: @escaping (String?) -> Void) {
        guard let bridge else {
            completion("Core unavailable")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let code = bridge.validateAndUpdateConfig(id)
            DispatchQueue.main.async {
                if code == 0 {
                    self.refreshServers()
                    completion(nil)
                } else {
                    completion(bridge.errorMessage(forCode: code))
                }
            }
        }
    }

    func exportConnectionKey(serverId: String, containerIndex: Int, clientName: String, completion: @escaping (Result<String, CoreError>) -> Void) {
        runExport(completion: completion) { bridge in
            bridge.connectionConfig(serverId, containerIndex: containerIndex, clientName: clientName)
        }
    }

    func exportNativeConfig(serverId: String, containerIndex: Int, format: NativeExportFormat, clientName: String, completion: @escaping (Result<String, CoreError>) -> Void) {
        runExport(completion: completion) { bridge in
            switch format {
            case .wireGuard:
                return bridge.wireGuardConfig(serverId, clientName: clientName)
            case .awg:
                return bridge.awgConfig(serverId, containerIndex: containerIndex, clientName: clientName)
            case .openVpn:
                return bridge.openVpnConfig(serverId, clientName: clientName)
            case .xray:
                return bridge.xrayConfig(serverId, clientName: clientName)
            }
        }
    }

    func exportFullAccessKey(serverId: String, completion: @escaping (Result<String, CoreError>) -> Void) {
        runExport(completion: completion) { bridge in
            bridge.fullAccessConfig(serverId)
        }
    }

    func exportVpnKey(serverId: String, completion: @escaping (Result<String, CoreError>) -> Void) {
        runExport(completion: completion) { bridge in
            bridge.prepareVpnKeyExport(serverId)
        }
    }

    private func runExport(completion: @escaping (Result<String, CoreError>) -> Void, produce: @escaping (AmneziaCoreBridge) -> String) {
        guard let bridge else {
            completion(.failure(CoreError(message: "Core unavailable")))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let value = produce(bridge)
            let error = bridge.getLastExportError()
            DispatchQueue.main.async {
                if value.isEmpty {
                    completion(.failure(CoreError(message: error == 0 ? "Export failed" : bridge.errorMessage(forCode: error))))
                } else {
                    completion(.success(value))
                }
            }
        }
    }

    private func refreshConnectionState() {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch manager.connection.status {
                case .connected:
                    self.connectionState = .connected
                case .connecting:
                    self.connectionState = .connecting
                case .reasserting:
                    self.connectionState = .reconnecting
                case .disconnecting:
                    self.connectionState = .disconnecting
                case .disconnected, .invalid:
                    self.connectionState = (self.bridge?.isConnectionInProgress == true) ? .preparing : .disconnected
                @unknown default:
                    break
                }
            }
        }
    }

    private func makeImportPreview() -> ImportPreview? {
        guard let bridge else { return nil }
        return ImportPreview(fileName: bridge.importedConfigFileName(),
                             displayText: bridge.importedConfig(),
                             isNativeWireGuardConfig: bridge.isNativeWireGuardConfig(),
                             maliciousWarningText: bridge.maliciousWarningText())
    }

    private static func buildServer(id: String, json: [String: Any]) -> VPNServer? {
        let containersJson = json["containers"] as? [[String: Any]] ?? []
        var containers: [VPNContainer] = []
        for containerJson in containersJson {
            let key = containerJson["container"] as? String ?? ""
            let protoKey = containerProtoKey(for: key)
            let protoConfig = containerJson[protoKey] as? [String: Any] ?? [:]
            let lastConfig = protoConfig["last_config"] as? String ?? ""
            let metadata = ContainerMetadata.metadata(for: key)
            let isThirdParty = protoConfig["isThirdPartyConfig"] as? Bool ?? false
            let isOutdatedAwg = key == "amnezia-awg"
            let isInstalled = protoConfig["isInstalled"] as? Bool ?? (!lastConfig.isEmpty)
            containers.append(VPNContainer(key: key, displayName: metadata.displayName, description: metadata.description,
                                           isInstalled: isInstalled, isVpn: metadata.isVpn, isOutdatedAwg: isOutdatedAwg,
                                           isThirdPartyConfig: isThirdParty, lastConfigJSON: lastConfig))
        }
        let defaultContainerKey = json["defaultContainer"] as? String ?? containers.first?.key ?? ""
        let defaultIndex = containers.firstIndex(where: { $0.key == defaultContainerKey }) ?? 0
        let configVersion = json["config_version"] as? Int ?? 0
        let isFromApi = configVersion == 1 || configVersion == 2
        let userName = json["userName"] as? String ?? ""
        let password = json["password"] as? String ?? ""
        let hasWriteAccess = !userName.isEmpty && !password.isEmpty
        let configData = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let configJSON = configData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        var name = json["description"] as? String ?? ""
        if name.isEmpty {
            name = json["hostName"] as? String ?? ""
        }
        if name.isEmpty {
            name = "Server"
        }
        return VPNServer(id: id, name: name, hostName: json["hostName"] as? String ?? "",
                         description: "", isFromApi: isFromApi, hasWriteAccess: hasWriteAccess,
                         defaultContainerIndex: defaultIndex, containers: containers,
                         dns1: json["dns1"] as? String ?? "", dns2: json["dns2"] as? String ?? "",
                         configJSON: configJSON,
                         isSubscriptionExpired: false, isSubscriptionExpiringSoon: false)
    }

    private static func containerProtoKey(for containerKey: String) -> String {
        switch containerKey {
        case "amnezia-awg", "amnezia-awg2": return "awg"
        case "amnezia-wireguard": return "wireguard"
        case "amnezia-openvpn", "amnezia-openvpn-cloak": return "openvpn"
        case "amnezia-xray": return "xray"
        case "amnezia-ssxray": return "ssxray"
        case "amnezia-ipsec": return "ikev2"
        case "amnezia-dns": return "dns"
        case "amnezia-sftp": return "sftp"
        case "amnezia-socks5proxy": return "socks5proxy"
        case "amnezia-mtproxy": return "mtproxy"
        case "amnezia-telemt": return "telemt"
        case "amnezia-tproxy": return "tproxy"
        case "amnezia-torwebsite": return "torwebsite"
        default: return ""
        }
    }
}
