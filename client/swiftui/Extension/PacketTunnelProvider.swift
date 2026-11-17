import Foundation
import NetworkExtension
import os.log
import WireGuardKit

enum TunnelError: Error {
    case configMissing
    case configInvalid
    case dnsResolutionFailure
    case couldNotSetNetworkSettings
    case couldNotStartBackend
    case couldNotDetermineFileDescriptor
}

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var wgAdapter: WireGuardAdapter?

    private static let tunnelLogURL: URL = {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BuildConfig.appGroupIdentifier)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let logsDirectory = container.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        return logsDirectory.appendingPathComponent("tunnel.log")
    }()

    private static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let handle = try? FileHandle(forWritingTo: tunnelLogURL) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: tunnelLogURL)
        }
        NSLog("[Tunnel] \(message)")
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let wgConfigData = providerConfiguration["wireguard"] as? Data else {
            Self.log("Can't start, config missing")
            completionHandler(TunnelError.configMissing)
            return
        }
        do {
            let wgConfig = try JSONDecoder().decode(WGConfig.self, from: wgConfigData)
            let wgConfigStr = wgConfig.str
            let tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: wgConfigStr)
            if tunnelConfiguration.peers.first?.allowedIPs
                .map({ $0.stringRepresentation })
                .joined(separator: ", ") == "0.0.0.0/0, ::/0" {
                if wgConfig.splitTunnelType == 1 {
                    for index in tunnelConfiguration.peers.indices {
                        tunnelConfiguration.peers[index].allowedIPs.removeAll()
                        var allowedIPs = [IPAddressRange]()
                        for allowedIPString in wgConfig.splitTunnelSites {
                            if let allowedIP = IPAddressRange(from: allowedIPString) {
                                allowedIPs.append(allowedIP)
                            }
                        }
                        tunnelConfiguration.peers[index].allowedIPs = allowedIPs
                    }
                } else if wgConfig.splitTunnelType == 2 {
                    for index in tunnelConfiguration.peers.indices {
                        var excludeIPs = [IPAddressRange]()
                        for excludeIPString in wgConfig.splitTunnelSites {
                            if let excludeIP = IPAddressRange(from: excludeIPString) {
                                excludeIPs.append(excludeIP)
                            }
                        }
                        tunnelConfiguration.peers[index].excludeIPs = excludeIPs
                    }
                }
            }
            Self.log("Starting WireGuard tunnel")
            wgAdapter = WireGuardAdapter(with: self) { logLevel, message in
                Self.log("[wg] \(message)")
            }
            wgAdapter?.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
                guard let adapterError else {
                    let interfaceName = self.wgAdapter?.interfaceName ?? "unknown"
                    Self.log("Tunnel interface is \(interfaceName)")
                    completionHandler(nil)
                    return
                }
                switch adapterError {
                case .cannotLocateTunnelFileDescriptor:
                    Self.log("Starting tunnel failed: could not determine file descriptor")
                    completionHandler(TunnelError.couldNotDetermineFileDescriptor)
                case .dnsResolution(let dnsErrors):
                    let hostnames = dnsErrors.map { $0.address }.joined(separator: ", ")
                    Self.log("DNS resolution failed for the following hostnames: \(hostnames)")
                    completionHandler(TunnelError.dnsResolutionFailure)
                case .setNetworkSettings(let error):
                    Self.log("Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
                    completionHandler(TunnelError.couldNotSetNetworkSettings)
                case .startWireGuardBackend(let errorCode):
                    Self.log("Starting tunnel failed with wgTurnOn returning \(errorCode)")
                    completionHandler(TunnelError.couldNotStartBackend)
                case .invalidState:
                    completionHandler(TunnelError.couldNotStartBackend)
                }
            }
        } catch {
            Self.log("Can't parse WG config: \(error)")
            completionHandler(TunnelError.configInvalid)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Self.log("Stopping tunnel: reason: \(reason.rawValue)")
        wgAdapter?.stop { error in
            if let error {
                Self.log("Failed to stop WireGuard adapter: \(error.localizedDescription)")
            }
            completionHandler()
        }
    }
}
