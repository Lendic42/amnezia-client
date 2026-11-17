import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShareView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var selectedFormat = ShareFormat.amnezia
    @State private var selectedServerId: String?
    @State private var showServerPicker = false
    @State private var qrPage = 0
    @State private var exportData: Data?
    @State private var exportFileName = ""
    @State private var showExporter = false

    private var server: VPNServer? {
        if let selectedServerId {
            return appState.servers.first { $0.id == selectedServerId }
        }
        return appState.defaultServer
    }

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: "Share VPN Access")
            AmneziaSegmentedControl(options: ["Connection", "Users"], selection: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            if selectedTab == 0 {
                connectionTab
            } else {
                usersTab
            }
            Spacer()
        }
        .background(AmneziaTheme.bgBase)
        .onAppear {
            selectedServerId = appState.defaultServerId
        }
        .sheet(isPresented: $showExporter) {
            if let exportData {
                ShareSheet(data: exportData, fileName: exportFileName)
            }
        }
    }

    private var connectionTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Share VPN access without the ability to manage the server")
                    .font(AmneziaTheme.Font.body)
                    .foregroundColor(AmneziaTheme.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                Button(action: { showServerPicker = true }) {
                    HStack(spacing: 8) {
                        Text(server?.name ?? "")
                            .font(AmneziaTheme.Font.button)
                            .foregroundColor(AmneziaTheme.textPrimary)
                        AmneziaIcon(name: "chevron-down", size: 24)
                            .foregroundColor(AmneziaTheme.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(AmneziaTheme.bgSurfaceAlt)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .confirmationDialog("Server", isPresented: $showServerPicker) {
                    ForEach(appState.servers) { candidate in
                        Button(candidate.name) {
                            selectedServerId = candidate.id
                            qrPage = 0
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
                Text("Connection format")
                    .font(AmneziaTheme.Font.h3)
                    .foregroundColor(AmneziaTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                ForEach(ShareFormat.allCases) { format in
                    Button(action: {
                        if format == .openVpn || format == .xray {
                            appState.showSnackbar("\(format.name) export is coming in a later build")
                            return
                        }
                        selectedFormat = format
                        qrPage = 0
                    }) {
                        HStack(spacing: 12) {
                            AmneziaRadioButton(isSelected: selectedFormat == format)
                            Text(format.name)
                                .font(AmneziaTheme.Font.body)
                                .foregroundColor(AmneziaTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if let qrStrings = qrStrings, !qrStrings.isEmpty {
                    TabView(selection: $qrPage) {
                        ForEach(qrStrings.indices, id: \.self) { index in
                            if let image = QRImageGenerator.image(for: qrStrings[index], size: 240) {
                                Image(uiImage: image)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 240, height: 240)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 280)
                    .padding(.top, 16)
                    if qrStrings.count > 1 {
                        Text("QR code \(qrPage + 1) of \(qrStrings.count)")
                            .font(AmneziaTheme.Font.small)
                            .foregroundColor(AmneziaTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                if let shareText = shareText {
                    Text(shareText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .lineLimit(3)
                        .padding(12)
                        .background(AmneziaTheme.bgSurfaceAlt)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .onTapGesture {
                            appState.copyToClipboard(shareText)
                        }
                }
                AmneziaButton(title: selectedFormat.saveCaption) {
                    saveConfig()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Share full access to the server and VPN")
                        .font(AmneziaTheme.Font.h3)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                    Text("Use for your own devices, or share with those you trust to manage the server.")
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    AmneziaButton(title: "Share", style: .secondary) {
                        appState.showSnackbar("Sharing full access is coming in a later build")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var usersTab: some View {
        VStack {
            Spacer()
            Text("User management is coming in a later build")
                .font(AmneziaTheme.Font.body)
                .foregroundColor(AmneziaTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var shareText: String? {
        guard let server else { return nil }
        switch selectedFormat {
        case .amnezia:
            return amneziaKey(for: server)
        case .wireGuard, .awg:
            return WGConfigBuilder.buildNativeConf(server: server, settings: appState.core.settings)
        case .openVpn, .xray:
            return nil
        }
    }

    private var qrStrings: [String]? {
        guard let server else { return nil }
        switch selectedFormat {
        case .amnezia:
            guard let json = shareJSON(for: server) else { return nil }
            return VPNKeyEncoder.qrChunks(json: json)
        case .wireGuard, .awg:
            guard let conf = WGConfigBuilder.buildNativeConf(server: server, settings: appState.core.settings) else { return nil }
            return [conf]
        case .openVpn, .xray:
            return nil
        }
    }

    private func shareJSON(for server: VPNServer) -> String? {
        guard var json = (try? JSONSerialization.jsonObject(with: Data(server.configJSON.utf8)) as? [String: Any]) ?? nil else {
            return nil
        }
        let (dns1, dns2) = WGConfigBuilder.effectiveDnsPair(server: server, settings: appState.core.settings)
        json["dns1"] = dns1
        json["dns2"] = dns2
        json.removeValue(forKey: "userName")
        json.removeValue(forKey: "password")
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private func amneziaKey(for server: VPNServer) -> String? {
        guard let json = shareJSON(for: server) else { return nil }
        return try? VPNKeyEncoder.encode(json: json)
    }

    private func saveConfig() {
        guard let server else { return }
        switch selectedFormat {
        case .amnezia:
            guard let key = amneziaKey(for: server),
                  let data = key.data(using: .utf8) else { return }
            exportData = data
            exportFileName = "Connection to \(server.name).vpn"
            showExporter = true
        case .wireGuard:
            guard let conf = WGConfigBuilder.buildNativeConf(server: server, settings: appState.core.settings),
                  let data = conf.data(using: .utf8) else { return }
            exportData = data
            exportFileName = "WireGuard config to \(server.name).conf"
            showExporter = true
        case .awg:
            guard let conf = WGConfigBuilder.buildNativeConf(server: server, settings: appState.core.settings),
                  let data = conf.data(using: .utf8) else { return }
            exportData = data
            exportFileName = "AmneziaWG config to \(server.name).conf"
            showExporter = true
        case .openVpn, .xray:
            break
        }
    }
}

enum ShareFormat: CaseIterable, Identifiable {
    case amnezia
    case openVpn
    case wireGuard
    case awg
    case xray

    var id: Self { self }

    var name: String {
        switch self {
        case .amnezia: return "For the AmneziaVPN app"
        case .openVpn: return "OpenVPN native format"
        case .wireGuard: return "WireGuard native format"
        case .awg: return "AmneziaWG native format"
        case .xray: return "XRay native format"
        }
    }

    var saveCaption: String {
        switch self {
        case .amnezia: return "Save AmneziaVPN config"
        case .openVpn: return "Save OpenVPN config"
        case .wireGuard: return "Save WireGuard config"
        case .awg: return "Save AmneziaWG config"
        case .xray: return "Save XRay config"
        }
    }
}

enum QRImageGenerator {
    static func image(for string: String, size: CGFloat) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "L"
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
