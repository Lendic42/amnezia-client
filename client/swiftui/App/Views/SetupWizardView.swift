import SwiftUI
import UniformTypeIdentifiers

struct SetupWizardView: View {
    @EnvironmentObject var appState: AppState
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                Spacer()
                Image("amneziaLogo")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 153, height: 131)
                    .foregroundColor(AmneziaTheme.textPrimary)
                Spacer()
                AmneziaButton(title: "Let's get started") {
                    navigationPath.append(WizardDestination.configSource)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(AmneziaTheme.bgBase)
            .navigationDestination(for: WizardDestination.self) { destination in
                switch destination {
                case .configSource:
                    ConfigSourceView(navigationPath: $navigationPath)
                case .textKey:
                    TextKeyView(navigationPath: $navigationPath)
                case .qrReader:
                    QrReaderView(navigationPath: $navigationPath)
                case .viewConfig(let imported):
                    ViewConfigView(navigationPath: $navigationPath, imported: imported)
                }
            }
        }
    }
}

enum WizardDestination: Hashable {
    case configSource
    case textKey
    case qrReader
    case viewConfig(ImportedConfig)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .configSource: hasher.combine(0)
        case .textKey: hasher.combine(1)
        case .qrReader: hasher.combine(2)
        case .viewConfig(let imported): hasher.combine(3); hasher.combine(imported.server.id)
        }
    }

    static func == (lhs: WizardDestination, rhs: WizardDestination) -> Bool {
        switch (lhs, rhs) {
        case (.configSource, .configSource), (.textKey, .textKey), (.qrReader, .qrReader):
            return true
        case (.viewConfig(let a), .viewConfig(let b)):
            return a.server.id == b.server.id
        default:
            return false
        }
    }
}

extension ImportedConfig: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(server.id)
    }

    static func == (lhs: ImportedConfig, rhs: ImportedConfig) -> Bool {
        lhs.server.id == rhs.server.id
    }
}

struct ConfigSourceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @State private var keyText = ""
    @State private var showFilePicker = false
    @State private var showMoreMenu = false
    @State private var showExportLogs = false
    @State private var exportData: Data?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AmneziaNavigationBar(title: "Connection", onBack: { dismiss() })
                Button(action: { showMoreMenu = true }) {
                    AmneziaIcon(name: "more-vertical", size: 24)
                        .foregroundColor(AmneziaTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            Text("Insert the key, add a configuration file or scan the QR-code")
                .font(AmneziaTheme.Font.body)
                .foregroundColor(AmneziaTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Insert key")
                        .font(AmneziaTheme.Font.h3)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    HStack(spacing: 8) {
                        AmneziaTextField(placeholder: "vpn://...", text: $keyText)
                        if keyText.isEmpty {
                            Button(action: {
                                if let pasted = UIPasteboard.general.string {
                                    keyText = pasted
                                }
                            }) {
                                Text("Insert")
                                    .font(AmneziaTheme.Font.button)
                                    .foregroundColor(AmneziaTheme.textPrimary)
                                    .frame(height: 48)
                                    .padding(.horizontal, 16)
                                    .background(AmneziaTheme.bgSurfaceAlt)
                                    .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    AmneziaButton(title: "Continue") {
                        continueWithKey(keyText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Other connection options")
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                    AmneziaListItem(title: "VPN by Amnezia",
                                    subtitle: "The easiest way to connect to the VPN",
                                    showChevron: true) {
                        appState.showSnackbar("Amnezia Premium is coming in a later build")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Self-hosted VPN",
                                    subtitle: "Configure Amnezia VPN on your own server",
                                    showChevron: true) {
                        appState.showSnackbar("Self-hosted setup is coming in a later build")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Restore from backup", showChevron: true) {
                        appState.showSnackbar("Backup and restore is coming in a later build")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "File with connection settings", showChevron: true) {
                        showFilePicker = true
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "QR code", iconName: "qr-code", showChevron: true) {
                        navigationPath.append(WizardDestination.qrReader)
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    AmneziaListItem(title: "Restore purchases", showChevron: true) {
                        appState.showSnackbar("Amnezia Premium is coming in a later build")
                    }
                    Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                }
                .padding(.bottom, 32)
            }
            Spacer()
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(contentTypes: [UTType(filenameExtension: "vpn") ?? .data,
                                          UTType(filenameExtension: "conf") ?? .data,
                                          UTType(filenameExtension: "ovpn") ?? .data,
                                          UTType.json]) { url in
                importFile(url)
            }
        }
        .confirmationDialog("Settings", isPresented: $showMoreMenu) {
            Button(appState.core.settings.isLoggingEnabled ? "Disable logs" : "Enable logs") {
                let enabled = !appState.core.settings.isLoggingEnabled
                appState.core.settings.isLoggingEnabled = enabled
                if enabled {
                    appState.core.settings.loggingEnabledSince = Date()
                }
            }
            Button("Export client logs") {
                if let data = Logger.shared.contents(stream: .app).data(using: .utf8) {
                    exportData = data
                    showExportLogs = true
                }
            }
            Button("Support tag") {
                appState.copyToClipboard(appState.core.settings.installationUuid)
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showExportLogs) {
            if let exportData {
                ShareSheet(data: exportData, fileName: "app.log")
            }
        }
    }

    private func continueWithKey(_ key: String) {
        do {
            let imported = try Importer.extractConfigFromData(key, fileName: "", nextServerName: appState.core.serverStore.nextAvailableServerName())
            navigationPath.append(WizardDestination.viewConfig(imported))
        } catch {
            appState.showSnackbar(error.localizedDescription)
        }
    }

    private func importFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            appState.showSnackbar("Could not read file")
            return
        }
        do {
            let imported = try Importer.extractConfigFromData(text, fileName: url.lastPathComponent, nextServerName: appState.core.serverStore.nextAvailableServerName())
            navigationPath.append(WizardDestination.viewConfig(imported))
        } catch {
            appState.showSnackbar(error.localizedDescription)
        }
    }
}

struct TextKeyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @State private var keyText = ""

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: "Connection key", onBack: { dismiss() })
            Text("A line that starts with vpn://...")
                .font(AmneziaTheme.Font.body)
                .foregroundColor(AmneziaTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Key")
                        .font(AmneziaTheme.Font.h3)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    HStack(spacing: 8) {
                        AmneziaTextField(placeholder: "vpn://...", text: $keyText)
                        if keyText.isEmpty {
                            Button(action: {
                                if let pasted = UIPasteboard.general.string {
                                    keyText = pasted
                                }
                            }) {
                                Text("Insert")
                                    .font(AmneziaTheme.Font.button)
                                    .foregroundColor(AmneziaTheme.textPrimary)
                                    .frame(height: 48)
                                    .padding(.horizontal, 16)
                                    .background(AmneziaTheme.bgSurfaceAlt)
                                    .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            AmneziaButton(title: "Continue") {
                do {
                    let imported = try Importer.extractConfigFromData(keyText, fileName: "", nextServerName: appState.core.serverStore.nextAvailableServerName())
                    navigationPath.append(WizardDestination.viewConfig(imported))
                } catch {
                    appState.showSnackbar(error.localizedDescription)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
    }
}

struct ViewConfigView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @State var imported: ImportedConfig
    @State private var showContent = false
    @State private var obfuscationEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: "New connection", onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !imported.fileName.isEmpty {
                        Text(imported.fileName)
                            .font(AmneziaTheme.Font.h3)
                            .foregroundColor(AmneziaTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                    if !imported.maliciousWarningText.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            AmneziaIcon(name: "alert-triangle", size: 24)
                                .foregroundColor(AmneziaTheme.statusWarning)
                            Text(imported.maliciousWarningText)
                                .font(AmneziaTheme.Font.small)
                                .foregroundColor(AmneziaTheme.textPrimary)
                        }
                        .padding(12)
                        .background(AmneziaTheme.statusWarning.opacity(0.12))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    Button(action: { showContent.toggle() }) {
                        Text(showContent ? "Collapse content" : "Show content")
                            .font(AmneziaTheme.Font.button)
                            .foregroundColor(AmneziaTheme.accentLight)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    if showContent {
                        Text(imported.displayText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AmneziaTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AmneziaTheme.bgSurfaceAlt)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .textSelection(.enabled)
                    }
                    if imported.isNativeWireGuardConfig {
                        HStack(spacing: 12) {
                            AmneziaSwitch(isOn: $obfuscationEnabled)
                            Text("Enable WireGuard obfuscation. It may be useful if WireGuard is blocked on your provider.")
                                .font(AmneziaTheme.Font.body)
                                .foregroundColor(AmneziaTheme.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        AmneziaIcon(name: "alert-triangle", size: 24)
                            .foregroundColor(AmneziaTheme.statusWarning)
                        Text("Use connection codes only from sources you trust. Codes from public sources may have been created to intercept your data.")
                            .font(AmneziaTheme.Font.small)
                            .foregroundColor(AmneziaTheme.textPrimary)
                    }
                    .padding(12)
                    .background(AmneziaTheme.statusWarning.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
                .padding(.bottom, 32)
            }
            AmneziaButton(title: "Connect") {
                var final = imported
                if imported.isNativeWireGuardConfig && obfuscationEnabled {
                    final = Importer.processNativeWireGuardConfig(imported)
                }
                appState.importConfig(final)
                appState.setDefaultServer(id: final.server.id)
                appState.selectedTab = .home
                navigationPath = NavigationPath()
                appState.toggleConnection()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
    }
}
