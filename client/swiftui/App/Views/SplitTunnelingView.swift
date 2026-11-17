import SwiftUI
import UniformTypeIdentifiers

struct SplitTunnelingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled = false
    @State private var routeModeIndex = 0
    @State private var newSiteText = ""
    @State private var isResolving = false
    @State private var siteToRemove: SplitTunnelSite?
    @State private var showClearConfirm = false
    @State private var showMoreMenu = false
    @State private var showImporter = false
    @State private var importReplaces = false
    @State private var exportData: Data?
    @State private var showExporter = false

    private var store: SplitTunnelingStore { appState.core.splitTunneling }
    private var state: SplitTunnelingStore.State { store.state }
    private var isConnected: Bool {
        appState.connectionState.isConnected || appState.connectionState.isInProgress
    }

    private let routeModes = [
        (segmentName: "Via VPN", description: "Only the sites listed here will be accessed through the VPN"),
        (segmentName: "Directly", description: "Addresses from the list should not be accessed via VPN")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AmneziaNavigationBar(title: "Split tunneling", onBack: { dismiss() })
                Button(action: { showMoreMenu = true }) {
                    AmneziaIcon(name: "more-vertical", size: 24)
                        .foregroundColor(AmneziaTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .disabled(isConnected)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("Split tunneling")
                            .font(AmneziaTheme.Font.body)
                            .foregroundColor(AmneziaTheme.textPrimary)
                        Spacer()
                        AmneziaSwitch(isOn: $isEnabled)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .disabled(isConnected)
                    AmneziaSegmentedControl(options: routeModes.map { $0.segmentName }, selection: $routeModeIndex)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .disabled(isConnected)
                    Text(routeModes[routeModeIndex].description)
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    HStack(spacing: 8) {
                        AmneziaTextField(placeholder: "website or IP", text: $newSiteText)
                        Button(action: addSite) {
                            if isResolving {
                                ProgressView()
                                    .frame(width: 48, height: 48)
                            } else {
                                Text("Add")
                                    .font(AmneziaTheme.Font.button)
                                    .foregroundColor(AmneziaTheme.textPrimary)
                                    .frame(width: 48, height: 48)
                                    .background(AmneziaTheme.bgSurfaceAlt)
                                    .cornerRadius(14)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(newSiteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnected || isResolving)
                    }
                    .padding(.horizontal, 16)
                    ForEach(state.sites) { site in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.url)
                                    .font(AmneziaTheme.Font.body)
                                    .foregroundColor(AmneziaTheme.textPrimary)
                                if !site.ip.isEmpty {
                                    Text(site.ip)
                                        .font(AmneziaTheme.Font.small)
                                        .foregroundColor(AmneziaTheme.textTertiary)
                                }
                            }
                            Spacer()
                            Button(action: { siteToRemove = site }) {
                                AmneziaIcon(name: "trash", size: 24)
                                    .foregroundColor(AmneziaTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .disabled(isConnected)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    }
                }
            }
            Spacer()
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
        .onAppear {
            isEnabled = state.isEnabled
            routeModeIndex = state.routeMode == .directly ? 1 : 0
            if isConnected {
                appState.showSnackbar("Cannot change split tunneling settings during active connection")
            }
        }
        .onChange(of: isEnabled) { newValue in
            var current = store.state
            current.isEnabled = newValue
            store.state = current
        }
        .onChange(of: routeModeIndex) { newValue in
            var current = store.state
            current.routeMode = newValue == 1 ? .directly : .viaVpn
            store.state = current
        }
        .alert(item: $siteToRemove) { site in
            Alert(
                title: Text("Remove \(site.url)?"),
                primaryButton: .default(Text("Continue")) {
                    store.removeSite(url: site.url)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
        .alert("Clear site list?", isPresented: $showClearConfirm) {
            Button("Continue") {
                store.removeAllSites()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All sites will be removed from list.")
        }
        .confirmationDialog("Additional options", isPresented: $showMoreMenu) {
            Button("Add imported sites to existing ones") {
                importReplaces = false
                showImporter = true
            }
            Button("Replace site list") {
                importReplaces = true
                showImporter = true
            }
            Button("Save site list") {
                exportSites()
            }
            Button("Clear site list", role: .destructive) {
                showClearConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImporter) {
            DocumentPicker(contentTypes: [UTType.json]) { url in
                importSites(from: url)
            }
        }
        .sheet(isPresented: $showExporter) {
            if let exportData {
                ShareSheet(data: exportData, fileName: "sites.json")
            }
        }
    }

    private func addSite() {
        let input = newSiteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if isIPAddress(input) {
            store.addSite(url: input, ips: [input])
            newSiteText = ""
            return
        }
        isResolving = true
        resolveHost(input) { ips in
            DispatchQueue.main.async {
                self.isResolving = false
                self.store.addSite(url: input, ips: ips)
                self.newSiteText = ""
            }
        }
    }

    private func isIPAddress(_ value: String) -> Bool {
        var addr = in_addr()
        if inet_pton(AF_INET, value, &addr) == 1 { return true }
        var addr6 = in6_addr()
        return inet_pton(AF_INET6, value, &addr6) == 1
    }

    private func resolveHost(_ host: String, completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(host, nil, &hints, &result)
            var ips: [String] = []
            if status == 0, let result {
                var cursor: UnsafeMutablePointer<addrinfo>? = result
                while let node = cursor {
                    var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(node.pointee.ai_addr, node.pointee.ai_addrlen, &buffer, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST) == 0 {
                        ips.append(String(cString: buffer))
                    }
                    cursor = node.pointee.ai_next
                }
                freeaddrinfo(result)
            }
            completion(ips)
        }
    }

    private func exportSites() {
        let sites = state.sites.map { site -> [String: Any] in
            ["url": site.url, "ips": site.ips, "ip": site.ip]
        }
        if let data = try? JSONSerialization.data(withJSONObject: sites, options: [.prettyPrinted]) {
            exportData = data
            showExporter = true
        }
    }

    private func importSites(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            appState.showSnackbar("Could not read sites file")
            return
        }
        let sites = json.compactMap { item -> SplitTunnelSite? in
            guard let siteUrl = item["url"] as? String, !siteUrl.isEmpty else { return nil }
            if let ips = item["ips"] as? [String] {
                return SplitTunnelSite(url: siteUrl, ips: ips)
            }
            if let ip = item["ip"] as? String {
                return SplitTunnelSite(url: siteUrl, ip: ip)
            }
            return SplitTunnelSite(url: siteUrl, ips: [])
        }
        store.importSites(sites, replace: importReplaces)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let data: Data
    let fileName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
