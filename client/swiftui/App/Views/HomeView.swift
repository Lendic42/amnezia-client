import SwiftUI

struct HomeInfoButton: View {
    let text: String
    var leftIcon: String? = nil
    var rightIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 8) {
                if let leftIcon {
                    AmneziaIcon(name: leftIcon, size: 24)
                        .foregroundColor(AmneziaTheme.textSecondary)
                }
                Text(text)
                    .font(AmneziaTheme.Font.body)
                    .foregroundColor(AmneziaTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let rightIcon {
                    AmneziaIcon(name: rightIcon, size: 24)
                        .foregroundColor(AmneziaTheme.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(AmneziaTheme.bgSurfaceAlt)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showServersSheet = false
    @State private var showContainersSheet = false
    @State private var showSplitTunnelingDrawer = false
    @State private var navigationPath = NavigationPath()

    private var defaultServer: VPNServer? { appState.defaultServer }
    private var isSplitTunnelingEnabled: Bool {
        appState.core.splitTunneling.state.isEnabled
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                mainContent
                collapsedBar
            }
            .background(AmneziaTheme.bgBase)
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .logging:
                    LoggingView()
                case .splitTunneling:
                    SplitTunnelingView()
                case .serverInfo(let serverId):
                    ServerInfoView(serverId: serverId)
                }
            }
            .sheet(isPresented: $showServersSheet) {
                serversSheet
                    .presentationDetents([.fraction(0.77)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showContainersSheet) {
                containersSheet
                    .presentationDetents([.fraction(0.9)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSplitTunnelingDrawer) {
                splitTunnelingDrawer
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if appState.core.settings.isLoggingEnabled {
                HomeInfoButton(text: "Logging enabled") {
                    navigationPath.append(HomeDestination.logging)
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 16)
            AmneziaConnectButton(state: appState.connectionState) {
                appState.toggleConnection()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            Spacer(minLength: 16)
            HomeInfoButton(
                text: isSplitTunnelingEnabled ? "Split tunneling enabled" : "Split tunneling disabled",
                leftIcon: "split-tunneling",
                rightIcon: "chevron-down"
            ) {
                showSplitTunnelingDrawer = true
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private var collapsedBar: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(AmneziaTheme.textTertiary)
                .frame(width: 36, height: 5)
                .padding(.top, 16)
            if let server = defaultServer {
                serverSummary(server: server, expanded: false)
            } else {
                Text("No servers")
                    .font(AmneziaTheme.Font.h3)
                    .foregroundColor(AmneziaTheme.textTertiary)
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AmneziaTheme.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AmneziaTheme.borderSoft, lineWidth: 1)
                )
        )
        .onTapGesture {
            showServersSheet = true
        }
    }

    private func serverSummary(server: VPNServer, expanded: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(server.name)
                    .font(AmneziaTheme.Font.h1)
                    .foregroundColor(AmneziaTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !expanded {
                    AmneziaIcon(name: "chevron-down", size: 24)
                        .foregroundColor(AmneziaTheme.textPrimary)
                }
            }
            .padding(.top, 16)
            Button(action: {
                if server.isFromApi {
                    showServersSheet = false
                    navigationPath.append(HomeDestination.serverInfo(serverId: server.id))
                }
            }) {
                HStack(spacing: 8) {
                    Text(server.collapsedDescription)
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if server.isFromApi {
                        AmneziaIcon(name: expanded ? "chevron-down" : "chevron-right", size: 24)
                            .foregroundColor(AmneziaTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(!server.isFromApi)
            .padding(.top, 6)
            if server.hasOutdatedAwgContainer {
                HStack(spacing: 8) {
                    AmneziaIcon(name: "alert-triangle", size: 24)
                        .foregroundColor(AmneziaTheme.statusWarning)
                    Text("AmneziaWG 2.0 is outdated and no longer supported. Continued use requires a fresh installation of the AmneziaWG 3.1 container.")
                        .font(AmneziaTheme.Font.small)
                        .foregroundColor(AmneziaTheme.textPrimary)
                }
                .padding(12)
                .background(AmneziaTheme.statusWarning.opacity(0.12))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {
                Spacer().frame(height: 16)
            }
            if server.isFromApi {
                HomeInfoButton(text: "AmneziaWG", leftIcon: "arrow-left-right", rightIcon: "chevron-down") {
                    appState.showSnackbar("Protocol selection is coming in a later build")
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var serversSheet: some View {
        VStack(spacing: 0) {
            if let server = defaultServer {
                serverSummary(server: server, expanded: true)
            }
            if !(defaultServer?.isFromApi ?? true) {
                Button(action: { showContainersSheet = true }) {
                    HStack(spacing: 8) {
                        Text(defaultServer?.defaultContainer?.displayName ?? "")
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
                .padding(.top, 16)
            }
            HStack {
                Text("Servers")
                    .font(AmneziaTheme.Font.body)
                    .foregroundColor(AmneziaTheme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(appState.servers) { server in
                        serverRow(server: server)
                        Divider()
                            .background(AmneziaTheme.borderSoft)
                            .padding(.leading, 16)
                    }
                }
                .padding(.top, 12)
            }
        }
        .background(AmneziaTheme.bgSurface)
    }

    private func serverRow(server: VPNServer) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                appState.setDefaultServer(id: server.id)
                showServersSheet = false
            }) {
                HStack(spacing: 12) {
                    AmneziaRadioButton(isSelected: server.id == appState.defaultServerId)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(AmneziaTheme.Font.body)
                            .foregroundColor(AmneziaTheme.textPrimary)
                        Text(server.collapsedDescription)
                            .font(AmneziaTheme.Font.small)
                            .foregroundColor(AmneziaTheme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: {
                showServersSheet = false
                navigationPath.append(HomeDestination.serverInfo(serverId: server.id))
            }) {
                AmneziaIcon(name: "chevron-right", size: 24)
                    .foregroundColor(AmneziaTheme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }

    private var containersSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { showContainersSheet = false }) {
                    AmneziaIcon(name: "arrow-left", size: 24)
                        .foregroundColor(AmneziaTheme.textPrimary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Text("VPN protocol")
                .font(AmneziaTheme.Font.h2)
                .foregroundColor(AmneziaTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            Text("Select an installed protocol or add a new one")
                .font(AmneziaTheme.Font.body)
                .foregroundColor(AmneziaTheme.textTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(containersForSheet) { container in
                        containerRow(container: container)
                        Divider()
                            .background(AmneziaTheme.borderSoft)
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(AmneziaTheme.bgSurface)
    }

    private var containersForSheet: [VPNContainer] {
        guard let server = defaultServer else { return [] }
        var list = server.containers.filter { $0.isVpn }.sorted { $0.isInstalled && !$1.isInstalled }
        if server.hasWriteAccess {
            let knownKeys = ["amnezia-awg2", "amnezia-wireguard", "amnezia-openvpn", "amnezia-xray", "amnezia-ipsec"]
            for key in knownKeys where !list.contains(where: { $0.key == key }) {
                let metadata = ContainerMetadata.metadata(for: key)
                list.append(VPNContainer(key: key, displayName: metadata.displayName, description: metadata.description,
                                         isInstalled: false, isVpn: true, isOutdatedAwg: false,
                                         isThirdPartyConfig: false, lastConfigJSON: ""))
            }
        }
        return list
    }

    private func containerRow(container: VPNContainer) -> some View {
        Button(action: {
            guard container.isInstalled else {
                appState.showSnackbar("Installing new protocols is coming in a later build")
                return
            }
            if let server = defaultServer,
               let index = server.containers.firstIndex(where: { $0.key == container.key }) {
                appState.setDefaultContainer(serverId: server.id, containerIndex: index)
            }
            showContainersSheet = false
        }) {
            HStack(spacing: 12) {
                AmneziaRadioButton(isSelected: defaultServer?.defaultContainer?.key == container.key)
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.displayName)
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textPrimary)
                    if !container.description.isEmpty {
                        Text(container.description)
                            .font(AmneziaTheme.Font.small)
                            .foregroundColor(AmneziaTheme.textTertiary)
                            .lineLimit(2)
                    }
                    if !container.isInstalled {
                        Text("Not installed")
                            .font(AmneziaTheme.Font.small)
                            .foregroundColor(AmneziaTheme.textTertiary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var splitTunnelingDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Split tunneling")
                .font(AmneziaTheme.Font.h2)
                .foregroundColor(AmneziaTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            Text("Allows you to connect to some sites or applications through a VPN connection and bypass others")
                .font(AmneziaTheme.Font.body)
                .foregroundColor(AmneziaTheme.textTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            AmneziaListItem(
                title: "Site-based split tunneling",
                subtitle: isSplitTunnelingEnabled ? "Enabled" : "Disabled",
                showChevron: true
            ) {
                showSplitTunnelingDrawer = false
                navigationPath.append(HomeDestination.splitTunneling)
            }
            Spacer()
        }
        .background(AmneziaTheme.bgSurface)
    }
}

enum HomeDestination: Hashable {
    case logging
    case splitTunneling
    case serverInfo(serverId: String)
}
