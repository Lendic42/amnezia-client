import Foundation

struct VPNContainer: Codable, Identifiable, Equatable {
    var key: String
    var displayName: String
    var description: String
    var isInstalled: Bool
    var isVpn: Bool
    var isOutdatedAwg: Bool
    var isThirdPartyConfig: Bool
    var lastConfigJSON: String

    var id: String { key }
}

struct VPNServer: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var hostName: String
    var description: String
    var isFromApi: Bool
    var hasWriteAccess: Bool
    var defaultContainerIndex: Int
    var containers: [VPNContainer]
    var dns1: String
    var dns2: String
    var configJSON: String
    var isSubscriptionExpired: Bool
    var isSubscriptionExpiringSoon: Bool

    var defaultContainer: VPNContainer? {
        guard containers.indices.contains(defaultContainerIndex) else { return containers.first }
        return containers[defaultContainerIndex]
    }

    var hasOutdatedAwgContainer: Bool {
        containers.contains { $0.isOutdatedAwg }
    }

    var installedServicesNames: [String] {
        containers.filter { $0.isInstalled && !$0.isVpn }.map { container in
            switch container.key {
            case "amnezia-dns": return "DNS"
            case "amnezia-sftp": return "SFTP"
            default: return container.displayName
            }
        }
    }

    var collapsedDescription: String {
        let protocolName = defaultContainer.map { ContainerMetadata.protocolName(for: $0) } ?? ""
        return protocolName + hostName
    }

    var expandedDescription: String {
        hostName
    }
}

enum ContainerMetadata {
    static func metadata(for key: String) -> (displayName: String, description: String, isVpn: Bool) {
        switch key {
        case "amnezia-awg", "amnezia-awg2":
            return ("AmneziaWG",
                    "AmneziaWG is a special protocol from Amnezia based on WireGuard. It provides high connection speed and ensures stable operation even in the most challenging network conditions.",
                    true)
        case "amnezia-wireguard":
            return ("WireGuard",
                    "WireGuard - popular VPN protocol with high performance, high speed and low power consumption.",
                    true)
        case "amnezia-openvpn":
            return ("OpenVPN",
                    "OpenVPN is the most popular VPN protocol, with flexible configuration options. It uses its own security protocol with SSL/TLS for key exchange.",
                    true)
        case "amnezia-openvpn-cloak":
            return ("OpenVPN over Cloak", "This protocol is no longer supported.", true)
        case "amnezia-shadowsocks":
            return ("OpenVPN over SS", "This protocol is no longer supported.", true)
        case "amnezia-xray":
            return ("XRay",
                    "XRay with REALITY masks VPN traffic as web traffic and protects against active probing. It is highly resistant to detection and offers high speed.",
                    true)
        case "amnezia-ssxray":
            return ("Shadowsocks", "", true)
        case "amnezia-ipsec":
            return ("IPsec",
                    "IKEv2/IPsec -  Modern stable protocol, a bit faster than others, restores connection after signal loss. It has native support on the latest versions of Android and iOS.",
                    true)
        case "amnezia-dns":
            return ("AmneziaDNS", "Replace the current DNS server with your own. This will increase your privacy level.", false)
        case "amnezia-sftp":
            return ("SFTP file sharing service", "Create a file vault on your server to securely store and transfer files.", false)
        case "amnezia-socks5proxy":
            return ("SOCKS5 proxy server", "", false)
        case "amnezia-mtproxy":
            return ("MTProxy (Telegram)", "Telegram MTProto proxy server", false)
        case "amnezia-telemt":
            return ("Telemt (Telegram)", "Telegram MTProto proxy (Telemt, Rust)", false)
        case "amnezia-tproxy":
            return ("TProxy (Telegram WEB)", "Telegram WEB proxy (tproxy-server)", false)
        case "amnezia-torwebsite":
            return ("Website in Tor network", "Deploy a WordPress site on the Tor network in two clicks.", false)
        default:
            return (key, "", false)
        }
    }

    static func protocolName(for container: VPNContainer) -> String {
        var name = container.displayName
        if container.key == "amnezia-awg" && !container.isThirdPartyConfig {
            name = "AmneziaWG Legacy"
        }
        let version = awgVersion(of: container)
        if container.key == "amnezia-awg" || container.key == "amnezia-awg2" {
            return name + version + " | "
        }
        return name + " | "
    }

    static func awgVersion(of container: VPNContainer) -> String {
        guard let data = container.lastConfigJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        return awgVersion(of: json)
    }

    static func awgVersion(of config: [String: Any]) -> String {
        let value = { (key: String) -> String in
            (config[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let hasValue = { (key: String) -> Bool in !value(key).isEmpty }
        let awg3Params = ["HeaderProtectionKey", "ContentPaddingAddition", "RekeyAfterTime",
                          "RekeyTimeout", "RejectAfterTime", "KeepaliveTimeout", "MaxHandshakeAttempts"]
        if awg3Params.contains(where: hasValue) || isToggleEnabled(value("RandomTrailers")) || isToggleEnabled(value("DisableCookies")) {
            return " (version 3.1)"
        }
        let junkSizes = [value("S3"), value("S4")]
        let magicHeaders = [value("H1"), value("H2"), value("H3"), value("H4")]
        if junkSizes.contains(where: { !$0.isEmpty }) || magicHeaders.contains(where: { $0.contains("-") }) {
            return " (version 2)"
        }
        let specialJunk = [value("I1"), value("I2"), value("I3"), value("I4"), value("I5")]
        if specialJunk.contains(where: { !$0.isEmpty }) {
            return " (version 1.5)"
        }
        return ""
    }

    static func isToggleEnabled(_ value: String) -> Bool {
        value == "true" || value == "1"
    }
}

struct SplitTunnelSite: Codable, Identifiable, Equatable {
    var id: String { url }
    var url: String
    var ips: [String]

    var ip: String { ips.first ?? "" }

    init(url: String, ips: [String]) {
        self.url = url
        self.ips = ips
    }

    init(url: String, ip: String) {
        self.url = url
        self.ips = ip.isEmpty ? [] : [ip]
    }

    enum CodingKeys: String, CodingKey {
        case url, ips, ip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        if let list = try? container.decode([String].self, forKey: .ips) {
            ips = list
        } else if let single = try? container.decode(String.self, forKey: .ip) {
            ips = single.isEmpty ? [] : [single]
        } else {
            ips = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(ips, forKey: .ips)
        try container.encode(ip, forKey: .ip)
    }
}
