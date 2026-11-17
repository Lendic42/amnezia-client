import Foundation

enum ImportError: LocalizedError {
    case invalidConfig
    case configFormatVersionNotSupported
    case legacyApiV1NotSupported
    case unsupportedProtocol(String)
    case backupFileUseRestoreInstead

    var errorDescription: String? {
        switch self {
        case .invalidConfig:
            return "Invalid configuration"
        case .configFormatVersionNotSupported:
            return "This configuration format version is not supported. Please update the app."
        case .legacyApiV1NotSupported:
            return "This subscription format is no longer supported. Please get a new key."
        case .unsupportedProtocol(let name):
            return "\(name) is not supported in this build yet"
        case .backupFileUseRestoreInstead:
            return "This is a backup file. Use Restore from backup instead."
        }
    }
}

struct ImportedConfig {
    var server: VPNServer
    var fileName: String
    var displayText: String
    var isNativeWireGuardConfig: Bool
    var maliciousWarningText: String
    var rawKey: String?
}

struct Importer {
    static let defaultSpecialJunk1 = "<r 2><b 0x858000010001000000000669636c6f756403636f6d0000010001c00c000100010000105a00044d583737>"

    static func extractConfigFromQrData(_ data: Data, fileName: String, nextServerName: String) throws -> ImportedConfig {
        if let text = String(data: data, encoding: .utf8) {
            let format = checkConfigFormat(text)
            if format != .invalid {
                return try extractFromDecodedConfig(text, fileName: fileName, nextServerName: nextServerName, rawKey: text)
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], !json.isEmpty {
                return try extractFromDecodedConfig(text, fileName: fileName, nextServerName: nextServerName, rawKey: text)
            }
        }
        if let decompressed = try? VPNKeyDecoder.decompress(data),
           let text = String(data: decompressed, encoding: .utf8) {
            return try extractFromDecodedConfig(text, fileName: fileName, nextServerName: nextServerName, rawKey: text)
        }
        throw ImportError.invalidConfig
    }

    private static func extractConfigFromData(_ data: String, fileName: String, nextServerName: String) throws -> ImportedConfig {
        var config = data
        let format = checkConfigFormat(config)
        if format == .invalid {
            let stripped = config.replacingOccurrences(of: "vpn://", with: "")
            if let decoded = try? VPNKeyDecoder.decode(stripped),
               let text = String(data: decoded, encoding: .utf8) {
                config = text
                return try extractFromDecodedConfig(config, fileName: fileName, nextServerName: nextServerName, rawKey: data)
            }
            throw ImportError.invalidConfig
        }
        return try extractFromDecodedConfig(config, fileName: fileName, nextServerName: nextServerName, rawKey: data)
    }

    private static func extractFromDecodedConfig(_ config: String, fileName: String, nextServerName: String, rawKey: String) throws -> ImportedConfig {
        switch checkConfigFormat(config) {
        case .amnezia:
            return try extractAmneziaConfig(config, fileName: fileName, nextServerName: nextServerName, rawKey: rawKey)
        case .wireGuard, .awg:
            return try extractWireGuardConfig(config, fileName: fileName, nextServerName: nextServerName)
        case .openVpn:
            throw ImportError.unsupportedProtocol("OpenVPN")
        case .xray:
            throw ImportError.unsupportedProtocol("XRay")
        case .backup:
            throw ImportError.backupFileUseRestoreInstead
        case .xraySettings:
            throw ImportError.unsupportedProtocol("XRay settings")
        case .invalid:
            throw ImportError.invalidConfig
        }
    }

    private enum ConfigFormat {
        case amnezia, wireGuard, awg, openVpn, xray, backup, xraySettings, invalid
    }

    private static func checkConfigFormat(_ config: String) -> ConfigFormat {
        if config.contains("Servers/serversList") {
            return .backup
        }
        if config.contains("containers") || config.contains("api_key") || config.contains("auth_data")
            || (config.contains("hostName") && config.contains("userName") && config.contains("password")) {
            return .amnezia
        }
        if config.contains("[Interface]") && config.contains("[Peer]") {
            return .wireGuard
        }
        if config.contains("inbounds") && config.contains("outbounds") {
            return .xray
        }
        if config.contains("client") && (config.contains("dev tun") || config.contains("dev tap")) {
            return .openVpn
        }
        if let data = config.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["serverConfig"] is [String: Any] {
            return .xraySettings
        }
        return .invalid
    }

    private static func extractAmneziaConfig(_ config: String, fileName: String, nextServerName: String, rawKey: String) throws -> ImportedConfig {
        guard let data = config.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidConfig
        }
        let formatVersion = json["format_version"] as? Int ?? 0
        if formatVersion > 1 {
            throw ImportError.configFormatVersionNotSupported
        }
        let configVersion = json["config_version"] as? Int ?? 0
        let isFromApi = configVersion == 1 || configVersion == 2
        if isFromApi {
            let apiEndpoint = json["apiEndpoint"] as? String ?? ""
            if configVersion == 1 && (apiEndpoint.contains("prem_v1") || apiEndpoint.contains("free_v2")) {
                throw ImportError.legacyApiV1NotSupported
            }
        }
        var containers = json["containers"] as? [[String: Any]] ?? []
        for i in containers.indices {
            var container = containers[i]
            let containerKey = container["container"] as? String ?? ""
            if containerKey == "amnezia-awg" || containerKey == "amnezia-awg2" || containerKey == "amnezia-wireguard" {
                let protoKey = containerKey == "amnezia-wireguard" ? "wireguard" : "awg"
                if var protoConfig = container[protoKey] as? [String: Any],
                   var lastConfigString = protoConfig["last_config"] as? String,
                   var lastConfig = (try? JSONSerialization.jsonObject(with: Data(lastConfigString.utf8)) as? [String: Any]) ?? nil {
                    if (lastConfig["mtu"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lastConfig["mtu"] = "1280"
                    }
                    if let updated = try? JSONSerialization.data(withJSONObject: lastConfig),
                       let updatedString = String(data: updated, encoding: .utf8) {
                        lastConfigString = updatedString
                    }
                    protoConfig["last_config"] = lastConfigString
                    container[protoKey] = protoConfig
                    containers[i] = container
                }
            }
        }
        json["containers"] = containers
        let server = buildServer(from: json, nextServerName: nextServerName, isFromApi: isFromApi)
        let warning = maliciousWarningText(for: containers)
        let displayData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        let displayText = displayData.flatMap { String(data: $0, encoding: .utf8) } ?? config
        return ImportedConfig(server: server, fileName: fileName, displayText: displayText,
                              isNativeWireGuardConfig: false, maliciousWarningText: warning, rawKey: rawKey)
    }

    private static func extractWireGuardConfig(_ config: String, fileName: String, nextServerName: String) throws -> ImportedConfig {
        var configMap: [String: String] = [:]
        for line in config.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") { continue }
            if let separatorIndex = trimmed.firstIndex(of: "="), separatorIndex != trimmed.startIndex {
                let key = String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(trimmed[trimmed.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                configMap[key] = value
            }
        }
        guard let endpoint = configMap["Endpoint"], !endpoint.isEmpty,
              let hostName = endpointHost(endpoint), !hostName.isEmpty,
              let privateKey = configMap["PrivateKey"], !privateKey.isEmpty,
              let address = configMap["Address"], !address.isEmpty,
              let publicKey = configMap["PublicKey"], !publicKey.isEmpty else {
            throw ImportError.invalidConfig
        }
        let port = endpointPort(endpoint) ?? 51820
        var lastConfig: [String: Any] = [:]
        lastConfig["config"] = config
        lastConfig["hostName"] = hostName
        lastConfig["port"] = port
        lastConfig["client_priv_key"] = privateKey
        lastConfig["client_ip"] = address
        if let psk = configMap["PresharedKey"] ?? configMap["PreSharedKey"], !psk.isEmpty {
            lastConfig["psk_key"] = psk
        }
        lastConfig["server_pub_key"] = publicKey
        if let mtu = configMap["MTU"], !mtu.isEmpty {
            lastConfig["mtu"] = mtu
        }
        if let keepalive = configMap["PersistentKeepalive"], !keepalive.isEmpty {
            lastConfig["persistent_keep_alive"] = keepalive
        }
        let allowedIps = (configMap["AllowedIPs"] ?? "").components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        lastConfig["allowed_ips"] = allowedIps
        let awgKeys = ["Jc", "Jmin", "Jmax", "S1", "S2", "S3", "S4", "H1", "H2", "H3", "H4",
                       "I1", "I2", "I3", "I4", "I5", "HeaderProtectionKey", "ContentPaddingAddition",
                       "RekeyAfterTime", "RekeyTimeout", "RejectAfterTime", "KeepaliveTimeout",
                       "MaxHandshakeAttempts", "RandomTrailers", "DisableCookies"]
        let hasAwgKeys = awgKeys.contains { !(configMap[$0] ?? "").isEmpty }
        var protoKey = "wireguard"
        var containerKey = "amnezia-wireguard"
        if hasAwgKeys {
            for key in awgKeys where !(configMap[key] ?? "").isEmpty {
                lastConfig[key] = configMap[key]
            }
            protoKey = "awg"
            containerKey = "amnezia-awg"
        }
        if lastConfig["mtu"] == nil {
            lastConfig["mtu"] = "1280"
        }
        let lastConfigData = try JSONSerialization.data(withJSONObject: lastConfig)
        let lastConfigString = String(data: lastConfigData, encoding: .utf8) ?? ""
        var protoConfig: [String: Any] = [:]
        protoConfig["last_config"] = lastConfigString
        protoConfig["isThirdPartyConfig"] = true
        protoConfig["port"] = port
        protoConfig["transportProto"] = "udp"
        let container: [String: Any] = ["container": containerKey, protoKey: protoConfig]
        var json: [String: Any] = [:]
        json["containers"] = [container]
        json["defaultContainer"] = containerKey
        json["description"] = nextServerName
        json["hostName"] = hostName
        if let regex = try? NSRegularExpression(pattern: #"DNS = (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"#),
           let match = regex.firstMatch(in: config, range: NSRange(config.startIndex..., in: config)),
           match.numberOfRanges == 3,
           let firstRange = Range(match.range(at: 1), in: config),
           let secondRange = Range(match.range(at: 2), in: config) {
            json["dns1"] = String(config[firstRange])
            json["dns2"] = String(config[secondRange])
        }
        let server = buildServer(from: json, nextServerName: nextServerName, isFromApi: false)
        return ImportedConfig(server: server, fileName: fileName, displayText: config,
                              isNativeWireGuardConfig: !hasAwgKeys, maliciousWarningText: "", rawKey: nil)
    }

    private static func endpointHost(_ endpoint: String) -> String? {
        let cleaned = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("[") {
            return cleaned.components(separatedBy: "]").first?.dropFirst().description
        }
        return cleaned.components(separatedBy: ":").first
    }

    private static func endpointPort(_ endpoint: String) -> Int? {
        let parts = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ":")
        if parts.count >= 2, let port = Int(parts.last ?? "") {
            return port
        }
        return nil
    }

    static func processNativeWireGuardConfig(_ imported: ImportedConfig) -> ImportedConfig {
        var result = imported
        guard var server = Optional(imported.server),
              let containerIndex = server.containers.firstIndex(where: { $0.key == "amnezia-wireguard" }),
              var lastConfig = (try? JSONSerialization.jsonObject(with: Data(server.containers[containerIndex].lastConfigJSON.utf8)) as? [String: Any]) ?? nil else {
            return imported
        }
        lastConfig["Jc"] = String(Int.random(in: 4..<7))
        lastConfig["Jmin"] = "10"
        lastConfig["Jmax"] = "50"
        lastConfig["S1"] = "0"
        lastConfig["S2"] = "0"
        lastConfig["H1"] = "1"
        lastConfig["H2"] = "2"
        lastConfig["H3"] = "3"
        lastConfig["H4"] = "4"
        lastConfig["S3"] = "0"
        lastConfig["S4"] = "0"
        lastConfig["I1"] = defaultSpecialJunk1
        lastConfig["isObfuscationEnabled"] = true
        if let data = try? JSONSerialization.data(withJSONObject: lastConfig),
           let updated = String(data: data, encoding: .utf8) {
            server.containers[containerIndex].lastConfigJSON = updated
            result.server = server
        }
        return result
    }

    private static func buildServer(from json: [String: Any], nextServerName: String, isFromApi: Bool) -> VPNServer {
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
        let name = (json["description"] as? String ?? "").isEmpty ? nextServerName : (json["description"] as? String ?? nextServerName)
        let userName = json["userName"] as? String ?? ""
        let password = json["password"] as? String ?? ""
        let hasWriteAccess = !userName.isEmpty && !password.isEmpty
        let configData = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let configJSON = configData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return VPNServer(id: UUID().uuidString, name: name, hostName: json["hostName"] as? String ?? "",
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

    private static func maliciousWarningText(for containers: [[String: Any]]) -> String {
        let dangerousTags = ["up", "tls-verify", "ipchange", "client-connect", "route-up",
                             "route-pre-down", "client-disconnect", "down", "learn-address", "auth-user-pass-verify"]
        for container in containers where (container["container"] as? String ?? "") == "amnezia-openvpn" {
            guard let protoConfig = container["openvpn"] as? [String: Any],
                  let lastConfig = protoConfig["last_config"] as? String,
                  let lastConfigJson = try? JSONSerialization.jsonObject(with: Data(lastConfig.utf8)) as? [String: Any],
                  let ovpnText = lastConfigJson["config"] as? String else {
                continue
            }
            var maliciousLines: [String] = []
            for rawLine in ovpnText.components(separatedBy: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                let command = line.components(separatedBy: " ").first ?? ""
                if dangerousTags.contains(command.lowercased()) {
                    maliciousLines.append(rawLine)
                }
            }
            var text = "This configuration contains an OpenVPN setup. OpenVPN configurations can include malicious scripts, so only add it if you fully trust the provider of this config. "
            if !maliciousLines.isEmpty {
                text += "\nIn the imported configuration, potentially dangerous lines were found:"
                for line in maliciousLines {
                    text += "\n" + line
                }
            }
            return text
        }
        return ""
    }
}

struct QrChunkAssembler {
    private var chunks: [Int: Data] = [:]
    private var expectedCount: Int?

    var scannedCount: Int { chunks.count }
    var totalCount: Int { expectedCount ?? 0 }
    var isComplete: Bool {
        guard let expected = expectedCount, expected > 0 else { return false }
        return chunks.count == expected
    }

    mutating func feed(_ text: String) -> Data? {
        guard let streamData = Data(base64URLDecoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              streamData.count >= 4,
              streamData[0] == 0x07, streamData[1] == 0xC0 else {
            return nil
        }
        let count = Int(streamData[2])
        let chunkId = Int(streamData[3])
        guard count > 0, chunkId < count, streamData.count >= 8 else { return nil }
        let length = Int(streamData[4]) << 24 | Int(streamData[5]) << 16 | Int(streamData[6]) << 8 | Int(streamData[7])
        guard streamData.count >= 8 + length else { return nil }
        let payload = streamData.subdata(in: 8..<(8 + length))
        if expectedCount == nil {
            expectedCount = count
        }
        chunks[chunkId] = payload
        guard isComplete else { return nil }
        var assembled = Data()
        for i in 0..<count {
            guard let chunk = chunks[i] else { return nil }
            assembled.append(chunk)
        }
        return assembled
    }

    mutating func reset() {
        chunks.removeAll()
        expectedCount = nil
    }
}
