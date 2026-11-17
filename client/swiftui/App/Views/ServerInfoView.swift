import SwiftUI

struct ServerInfoView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let serverId: String
    @State private var selectedTab: Int = 0
    @State private var showRenameSheet = false
    @State private var renameText = ""

    private var server: VPNServer? {
        appState.servers.first { $0.id == serverId }
    }

    private var tabs: [ServerInfoTab] {
        var result: [ServerInfoTab] = []
        if let server, server.containers.contains(where: { $0.isVpn && $0.isInstalled }) {
            result.append(.protocols)
        }
        if let server, server.containers.contains(where: { !$0.isVpn && $0.isInstalled }) {
            result.append(.services)
        }
        result.append(.management)
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: server?.name ?? "", onBack: { dismiss() })
            if let server {
                Text(headerDescription(server: server))
                    .font(AmneziaTheme.Font.small)
                    .foregroundColor(AmneziaTheme.textTertiary)
                    .padding(.horizontal, 16)
                HStack {
                    Spacer()
                    Button(action: {
                        renameText = server.name
                        showRenameSheet = true
                    }) {
                        AmneziaIcon(name: "edit-3", size: 24)
                            .foregroundColor(AmneziaTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            HStack(spacing: 8) {
                ForEach(tabs.indices, id: \.self) { index in
                    Button(action: { selectedTab = index }) {
                        Text(tabs[index].title)
                            .font(AmneziaTheme.Font.button)
                            .foregroundColor(selectedTab == index ? AmneziaTheme.textPrimary : AmneziaTheme.textTertiary)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(selectedTab == index ? AmneziaTheme.bgSurfaceAlt : Color.clear)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            if let server, tabs.indices.contains(selectedTab) {
                switch tabs[selectedTab] {
                case .protocols:
                    protocolsTab(server: server)
                case .services:
                    servicesTab(server: server)
                case .management:
                    ServerDataView(server: server)
                }
            }
            Spacer()
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func headerDescription(server: VPNServer) -> String {
        if server.isFromApi {
            return server.expandedDescription
        }
        if server.hasWriteAccess {
            return server.hostName
        }
        return server.hostName
    }

    private func protocolsTab(server: VPNServer) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(server.containers.filter { $0.isVpn && $0.isInstalled }) { container in
                    Button(action: {
                        if let index = server.containers.firstIndex(where: { $0.key == container.key }) {
                            appState.setDefaultContainer(serverId: server.id, containerIndex: index)
                        }
                    }) {
                        HStack(spacing: 12) {
                            AmneziaRadioButton(isSelected: server.defaultContainer?.key == container.key)
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
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .background(AmneziaTheme.borderSoft)
                        .padding(.leading, 16)
                }
            }
            .padding(.top, 24)
        }
    }

    private func servicesTab(server: VPNServer) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(server.containers.filter { !$0.isVpn && $0.isInstalled }) { container in
                    AmneziaListItem(title: container.displayName, subtitle: container.description, showChevron: true) {
                        appState.showSnackbar("Service settings are coming in a later build")
                    }
                    Divider()
                        .background(AmneziaTheme.borderSoft)
                        .padding(.leading, 16)
                }
            }
            .padding(.top, 24)
        }
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Server name")
                .font(AmneziaTheme.Font.h2)
                .foregroundColor(AmneziaTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            AmneziaTextField(placeholder: "Server name", text: $renameText)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .onChange(of: renameText) { newValue in
                    if newValue.count > 30 {
                        renameText = String(newValue.prefix(30))
                    }
                }
            AmneziaButton(title: "Save") {
                if let server {
                    appState.renameServer(id: server.id, name: renameText)
                }
                showRenameSheet = false
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            Spacer()
        }
        .background(AmneziaTheme.bgSurface)
    }
}

enum ServerInfoTab {
    case protocols
    case services
    case management

    var title: String {
        switch self {
        case .protocols: return "Protocols"
        case .services: return "Services"
        case .management: return "Management"
        }
    }
}
