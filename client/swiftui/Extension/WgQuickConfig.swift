import Foundation
import WireGuardKit

enum WgQuickParseError: Error {
    case invalidLine(String)
    case noInterface
    case multipleInterfaces
    case interfaceHasNoPrivateKey
    case interfaceHasInvalidPrivateKey(String)
    case interfaceHasInvalidListenPort(String)
    case interfaceHasInvalidAddress(String)
    case interfaceHasInvalidDNS(String)
    case interfaceHasInvalidMTU(String)
    case interfaceHasUnrecognizedKey(String)
    case interfaceHasInvalidCustomParam(String)
    case interfaceHasInvalidHeaderProtectionKey(String)
    case peerHasNoPublicKey
    case peerHasInvalidPublicKey(String)
    case peerHasInvalidPreSharedKey(String)
    case peerHasInvalidAllowedIP(String)
    case peerHasInvalidEndpoint(String)
    case peerHasUnrecognizedKey(String)
    case multiplePeersWithSamePublicKey
    case multipleEntriesForKey(String)
}

extension TunnelConfiguration {
    private enum ParserState {
        case inInterfaceSection
        case inPeerSection
        case notInASection
    }

    convenience init(fromWgQuickConfig wgQuickConfig: String) throws {
        var interfaceConfiguration: InterfaceConfiguration?
        var peerConfigurations = [PeerConfiguration]()

        let lines = wgQuickConfig.split { $0.isNewline }

        var parserState = ParserState.notInASection
        var attributes = [String: String]()

        for (lineIndex, line) in lines.enumerated() {
            var trimmedLine: String
            if let commentRange = line.range(of: "#") {
                trimmedLine = String(line[..<commentRange.lowerBound])
            } else {
                trimmedLine = String(line)
            }

            trimmedLine = trimmedLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedLine = trimmedLine.lowercased()

            if !trimmedLine.isEmpty {
                if let equalsIndex = trimmedLine.firstIndex(of: "=") {
                    let keyWithCase = trimmedLine[..<equalsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = keyWithCase.lowercased()
                    let value = trimmedLine[trimmedLine.index(equalsIndex, offsetBy: 1)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    let keysWithMultipleEntriesAllowed: Set<String> = ["address", "allowedips", "dns"]
                    if let presentValue = attributes[key] {
                        if keysWithMultipleEntriesAllowed.contains(key) {
                            attributes[key] = presentValue + "," + value
                        } else {
                            throw WgQuickParseError.multipleEntriesForKey(keyWithCase)
                        }
                    } else {
                        attributes[key] = value
                    }
                    let interfaceSectionKeys: Set<String> = [
                        "privatekey",
                        "listenport",
                        "address",
                        "dns",
                        "mtu",
                        "jc",
                        "jmin",
                        "jmax",
                        "s1",
                        "s2",
                        "s3",
                        "s4",
                        "h1",
                        "h2",
                        "h3",
                        "h4",
                        "i1",
                        "i2",
                        "i3",
                        "i4",
                        "i5",
                        "headerprotectionkey",
                        "contentpaddingaddition",
                        "rekeyaftertime",
                        "rekeytimeout",
                        "rejectaftertime",
                        "keepalivetimeout",
                        "maxhandshakeattempts",
                        "randomtrailers",
                        "disablecookies",
                    ]
                    let peerSectionKeys: Set<String> = ["publickey", "presharedkey", "allowedips", "endpoint", "persistentkeepalive"]
                    if parserState == .inInterfaceSection {
                        guard interfaceSectionKeys.contains(key) else {
                            throw WgQuickParseError.interfaceHasUnrecognizedKey(keyWithCase)
                        }
                    } else if parserState == .inPeerSection {
                        guard peerSectionKeys.contains(key) else {
                            throw WgQuickParseError.peerHasUnrecognizedKey(keyWithCase)
                        }
                    }
                } else if lowercasedLine != "[interface]" && lowercasedLine != "[peer]" {
                    throw WgQuickParseError.invalidLine(String(line))
                }
            }

            let isLastLine = lineIndex == lines.count - 1

            if isLastLine || lowercasedLine == "[interface]" || lowercasedLine == "[peer]" {
                if parserState == .inInterfaceSection {
                    let interface = try TunnelConfiguration.collate(interfaceAttributes: attributes)
                    guard interfaceConfiguration == nil else { throw WgQuickParseError.multipleInterfaces }
                    interfaceConfiguration = interface
                } else if parserState == .inPeerSection {
                    let peer = try TunnelConfiguration.collate(peerAttributes: attributes)
                    peerConfigurations.append(peer)
                }
            }

            if lowercasedLine == "[interface]" {
                parserState = .inInterfaceSection
                attributes.removeAll()
            } else if lowercasedLine == "[peer]" {
                parserState = .inPeerSection
                attributes.removeAll()
            }
        }

        let peerPublicKeysArray = peerConfigurations.map { $0.publicKey }
        let peerPublicKeysSet = Set<PublicKey>(peerPublicKeysArray)
        if peerPublicKeysArray.count != peerPublicKeysSet.count {
            throw WgQuickParseError.multiplePeersWithSamePublicKey
        }

        if let interfaceConfiguration = interfaceConfiguration {
            self.init(name: nil, interface: interfaceConfiguration, peers: peerConfigurations)
        } else {
            throw WgQuickParseError.noInterface
        }
    }

    private static func splitList(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func collate(interfaceAttributes attributes: [String: String]) throws -> InterfaceConfiguration {
        guard let privateKeyString = attributes["privatekey"] else {
            throw WgQuickParseError.interfaceHasNoPrivateKey
        }
        guard let privateKey = PrivateKey(base64Key: privateKeyString) else {
            throw WgQuickParseError.interfaceHasInvalidPrivateKey(privateKeyString)
        }
        var interface = InterfaceConfiguration(privateKey: privateKey)
        if let listenPortString = attributes["listenport"] {
            guard let listenPort = UInt16(listenPortString) else {
                throw WgQuickParseError.interfaceHasInvalidListenPort(listenPortString)
            }
            interface.listenPort = listenPort
        }
        if let addressesString = attributes["address"] {
            var addresses = [IPAddressRange]()
            for addressString in splitList(addressesString) {
                guard let address = IPAddressRange(from: addressString) else {
                    throw WgQuickParseError.interfaceHasInvalidAddress(addressString)
                }
                addresses.append(address)
            }
            interface.addresses = addresses
        }
        if let dnsString = attributes["dns"] {
            var dnsServers = [DNSServer]()
            var dnsSearch = [String]()
            for dnsServerString in splitList(dnsString) {
                if let dnsServer = DNSServer(from: dnsServerString) {
                    dnsServers.append(dnsServer)
                } else {
                    dnsSearch.append(dnsServerString)
                }
            }
            interface.dns = dnsServers
            interface.dnsSearch = dnsSearch
        }
        if let mtuString = attributes["mtu"] {
            guard let mtu = UInt16(mtuString) else {
                throw WgQuickParseError.interfaceHasInvalidMTU(mtuString)
            }
            interface.mtu = mtu
        }
        if let junkPacketCountString = attributes["jc"] {
            guard let junkPacketCount = UInt16(junkPacketCountString) else {
                throw WgQuickParseError.interfaceHasInvalidCustomParam(junkPacketCountString)
            }
            interface.junkPacketCount = junkPacketCount
        }
        if let junkPacketMinSizeString = attributes["jmin"] {
            guard let junkPacketMinSize = UInt16(junkPacketMinSizeString) else {
                throw WgQuickParseError.interfaceHasInvalidCustomParam(junkPacketMinSizeString)
            }
            interface.junkPacketMinSize = junkPacketMinSize
        }
        if let junkPacketMaxSizeString = attributes["jmax"] {
            guard let junkPacketMaxSize = UInt16(junkPacketMaxSizeString) else {
                throw WgQuickParseError.interfaceHasInvalidCustomParam(junkPacketMaxSizeString)
            }
            interface.junkPacketMaxSize = junkPacketMaxSize
        }
        if let initPacketJunkSizeString = attributes["s1"] {
            guard let initPacketJunkSize = UInt16(initPacketJunkSizeString) else {
                throw WgQuickParseError.interfaceHasInvalidCustomParam(initPacketJunkSizeString)
            }
            interface.initPacketJunkSize = initPacketJunkSize
        }
        if let responsePacketJunkSizeString = attributes["s2"] {
            guard let responsePacketJunkSize = UInt16(responsePacketJunkSizeString) else {
                throw WgQuickParseError.interfaceHasInvalidCustomParam(responsePacketJunkSizeString)
            }
            interface.responsePacketJunkSize = responsePacketJunkSize
        }
        if let cookieReplyPacketJunkSizeString = attributes["s3"] {
            guard let cookieReplyPacketJunkSize = UInt16(cookieReplyPacketJunkSizeString) else {
                throw WgQuickParseError.interfaceHasInvalidCustomParam(cookieReplyPacketJunkSizeString)
            }
            interface.cookieReplyPacketJunkSize = cookieReplyPacketJunkSize
        }
        if let transportPacketJunkSizeString = attributes["s4"] {
            guard let transportPacketJunkSize = UInt16(transportPacketJunkSizeString) else {
                throw WgQuickParseError.interfaceHasInvalidCustomParam(transportPacketJunkSizeString)
            }
            interface.transportPacketJunkSize = transportPacketJunkSize
        }
        if let initPacketMagicHeaderString = attributes["h1"] {
            interface.initPacketMagicHeader = initPacketMagicHeaderString
        }
        if let responsePacketMagicHeaderString = attributes["h2"] {
            interface.responsePacketMagicHeader = responsePacketMagicHeaderString
        }
        if let underloadPacketMagicHeaderString = attributes["h3"] {
            interface.underloadPacketMagicHeader = underloadPacketMagicHeaderString
        }
        if let transportPacketMagicHeaderString = attributes["h4"] {
            interface.transportPacketMagicHeader = transportPacketMagicHeaderString
        }
        if let specialJunk1String = attributes["i1"] {
            interface.specialJunk1 = specialJunk1String
        }
        if let specialJunk2String = attributes["i2"] {
            interface.specialJunk2 = specialJunk2String
        }
        if let specialJunk3String = attributes["i3"] {
            interface.specialJunk3 = specialJunk3String
        }
        if let specialJunk4String = attributes["i4"] {
            interface.specialJunk4 = specialJunk4String
        }
        if let specialJunk5String = attributes["i5"] {
            interface.specialJunk5 = specialJunk5String
        }
        if let headerProtectionKeyString = attributes["headerprotectionkey"], !headerProtectionKeyString.isEmpty {
            guard let headerProtectionKey = PrivateKey(base64Key: headerProtectionKeyString) else {
                throw WgQuickParseError.interfaceHasInvalidHeaderProtectionKey(headerProtectionKeyString)
            }
            interface.headerProtectionKey = headerProtectionKey
        }
        if let contentPaddingAdditionString = attributes["contentpaddingaddition"], !contentPaddingAdditionString.isEmpty {
            interface.contentPaddingAddition = contentPaddingAdditionString
        }
        if let rekeyAfterTimeString = attributes["rekeyaftertime"], !rekeyAfterTimeString.isEmpty {
            interface.rekeyAfterTime = rekeyAfterTimeString
        }
        if let rekeyTimeoutString = attributes["rekeytimeout"], !rekeyTimeoutString.isEmpty {
            interface.rekeyTimeout = rekeyTimeoutString
        }
        if let rejectAfterTimeString = attributes["rejectaftertime"], !rejectAfterTimeString.isEmpty {
            interface.rejectAfterTime = rejectAfterTimeString
        }
        if let keepaliveTimeoutString = attributes["keepalivetimeout"], !keepaliveTimeoutString.isEmpty {
            interface.keepaliveTimeout = keepaliveTimeoutString
        }
        if let maxHandshakeAttemptsString = attributes["maxhandshakeattempts"], !maxHandshakeAttemptsString.isEmpty {
            interface.maxHandshakeAttempts = maxHandshakeAttemptsString
        }
        if let randomTrailersString = attributes["randomtrailers"], !randomTrailersString.isEmpty {
            interface.randomTrailers = randomTrailersString
        }
        if let disableCookiesString = attributes["disablecookies"], !disableCookiesString.isEmpty {
            interface.disableCookies = disableCookiesString
        }
        return interface
    }

    private static func collate(peerAttributes attributes: [String: String]) throws -> PeerConfiguration {
        guard let publicKeyString = attributes["publickey"] else {
            throw WgQuickParseError.peerHasNoPublicKey
        }
        guard let publicKey = PublicKey(base64Key: publicKeyString) else {
            throw WgQuickParseError.peerHasInvalidPublicKey(publicKeyString)
        }
        var peer = PeerConfiguration(publicKey: publicKey)
        if let preSharedKeyString = attributes["presharedkey"] {
            guard let preSharedKey = PreSharedKey(base64Key: preSharedKeyString) else {
                throw WgQuickParseError.peerHasInvalidPreSharedKey(preSharedKeyString)
            }
            peer.preSharedKey = preSharedKey
        }
        if let allowedIPsString = attributes["allowedips"] {
            var allowedIPs = [IPAddressRange]()
            for allowedIPString in splitList(allowedIPsString) {
                guard let allowedIP = IPAddressRange(from: allowedIPString) else {
                    throw WgQuickParseError.peerHasInvalidAllowedIP(allowedIPString)
                }
                allowedIPs.append(allowedIP)
            }
            peer.allowedIPs = allowedIPs
        }
        if let endpointString = attributes["endpoint"] {
            guard let endpoint = Endpoint(from: endpointString) else {
                throw WgQuickParseError.peerHasInvalidEndpoint(endpointString)
            }
            peer.endpoint = endpoint
        }
        if let persistentKeepAliveString = attributes["persistentkeepalive"], !persistentKeepAliveString.isEmpty {
            peer.persistentKeepAlive = persistentKeepAliveString
        }
        return peer
    }
}
