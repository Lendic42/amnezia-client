import Foundation

struct WGConfigBuilder {
    static func buildWGConfigJSON(server: VPNServer, settings: SettingsStore, splitTunneling: SplitTunnelingStore) -> Data? {
        guard let container = server.defaultContainer,
              let lastConfig = (try? JSONSerialization.jsonObject(with: Data(container.lastConfigJSON.utf8)) as? [String: Any]) ?? nil else {
            return nil
        }
        let (dns1, dns2) = effectiveDnsPair(server: server, settings: settings)
        let mtu = (lastConfig["mtu"] as? String ?? "").isEmpty ? "1280" : (lastConfig["mtu"] as? String ?? "1280")
        let splitState = splitTunneling.state
        var config: [String: Any] = [:]
        for key in ["Jc", "Jmin", "Jmax", "S1", "S2", "S3", "S4", "H1", "H2", "H3", "H4",
                    "I1", "I2", "I3", "I4", "I5", "HeaderProtectionKey", "ContentPaddingAddition",
                    "RekeyAfterTime", "RekeyTimeout", "RejectAfterTime", "KeepaliveTimeout",
                    "MaxHandshakeAttempts", "RandomTrailers", "DisableCookies"] {
            if let value = lastConfig[key] as? String, !value.isEmpty {
                config[key] = value
            }
        }
        config["dns1"] = dns1
        config["dns2"] = dns2
        config["mtu"] = mtu
        config["hostName"] = server.hostName
        config["port"] = lastConfig["port"] as? Int ?? 51820
        config["client_ip"] = lastConfig["client_ip"] as? String ?? ""
        config["client_priv_key"] = lastConfig["client_priv_key"] as? String ?? ""
        config["server_pub_key"] = lastConfig["server_pub_key"] as? String ?? ""
        if let psk = lastConfig["psk_key"] as? String, !psk.isEmpty {
            config["psk_key"] = psk
        }
        if let allowedIps = lastConfig["allowed_ips"] as? [String], !allowedIps.isEmpty {
            config["allowed_ips"] = allowedIps
        } else {
            config["allowed_ips"] = ["0.0.0.0/0", "::/0"]
        }
        if let keepalive = lastConfig["persistent_keep_alive"] as? String, !keepalive.isEmpty {
            config["persistent_keep_alive"] = keepalive
        }
        config["splitTunnelType"] = splitState.isEnabled ? splitState.routeMode.rawValue : 0
        config["splitTunnelSites"] = splitState.sites.flatMap { $0.ips.isEmpty ? [$0.url] : $0.ips }
        return try? JSONSerialization.data(withJSONObject: config)
    }

    static func effectiveDnsPair(server: VPNServer, settings: SettingsStore) -> (String, String) {
        let hasDnsContainer = server.containers.contains { $0.key == "amnezia-dns" && $0.isInstalled }
        var dns1 = server.dns1
        if dns1.isEmpty || !isValidIPv4(dns1) {
            dns1 = (settings.useAmneziaDns && hasDnsContainer) ? SettingsStore.amneziaDnsIp : settings.primaryDns
        }
        var dns2 = server.dns2
        if dns2.isEmpty || !isValidIPv4(dns2) {
            dns2 = settings.secondaryDns
        }
        return (dns1, dns2)
    }

    private static func isValidIPv4(_ value: String) -> Bool {
        let parts = value.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let number = Int(part), number >= 0, number <= 255 else { return false }
            return String(number) == part || part.hasPrefix("0")
        }
    }

    static func buildNativeConf(server: VPNServer, settings: SettingsStore) -> String? {
        guard let container = server.defaultContainer,
              let lastConfig = (try? JSONSerialization.jsonObject(with: Data(container.lastConfigJSON.utf8)) as? [String: Any]) ?? nil else {
            return nil
        }
        let isAwg = container.key == "amnezia-awg" || container.key == "amnezia-awg2"
        let (dns1, dns2) = effectiveDnsPair(server: server, settings: settings)
        let mtu = (lastConfig["mtu"] as? String ?? "").isEmpty ? "1280" : (lastConfig["mtu"] as? String ?? "1280")
        var lines: [String] = []
        lines.append("[Interface]")
        lines.append("PrivateKey = \(lastConfig["client_priv_key"] as? String ?? "")")
        lines.append("Address = \(lastConfig["client_ip"] as? String ?? "")")
        lines.append("DNS = \(dns2.isEmpty ? dns1 : "\(dns1), \(dns2)")")
        lines.append("MTU = \(mtu)")
        if isAwg {
            for key in ["Jc", "Jmin", "Jmax", "S1", "S2", "S3", "S4", "H1", "H2", "H3", "H4",
                        "I1", "I2", "I3", "I4", "I5"] {
                if let value = lastConfig[key] as? String, !value.isEmpty {
                    lines.append("\(key) = \(value)")
                }
            }
        }
        lines.append("")
        lines.append("[Peer]")
        lines.append("PublicKey = \(lastConfig["server_pub_key"] as? String ?? "")")
        if let psk = lastConfig["psk_key"] as? String, !psk.isEmpty {
            lines.append("PresharedKey = \(psk)")
        }
        if let allowedIps = lastConfig["allowed_ips"] as? [String], !allowedIps.isEmpty {
            lines.append("AllowedIPs = \(allowedIps.joined(separator: ", "))")
        } else {
            lines.append("AllowedIPs = 0.0.0.0/0, ::/0")
        }
        lines.append("Endpoint = \(server.hostName):\(lastConfig["port"] as? Int ?? 51820)")
        if let keepalive = lastConfig["persistent_keep_alive"] as? String, !keepalive.isEmpty {
            lines.append("PersistentKeepalive = \(keepalive)")
        }
        return lines.joined(separator: "\n")
    }

    static func isWireGuardContainer(_ container: VPNContainer?) -> Bool {
        guard let container else { return false }
        return container.key == "amnezia-awg" || container.key == "amnezia-awg2" || container.key == "amnezia-wireguard"
    }
}
