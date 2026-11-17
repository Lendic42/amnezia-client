import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    @State private var useAmneziaDns: Bool = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                AmneziaNavigationBar(title: "Connection", onBack: { dismiss() })
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use AmneziaDNS")
                                    .font(AmneziaTheme.Font.body)
                                    .foregroundColor(AmneziaTheme.textPrimary)
                                Text("If AmneziaDNS is installed on the server")
                                    .font(AmneziaTheme.Font.small)
                                    .foregroundColor(AmneziaTheme.textTertiary)
                            }
                            Spacer()
                            AmneziaSwitch(isOn: $useAmneziaDns)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "DNS servers",
                                        subtitle: "When AmneziaDNS is not used or installed",
                                        showChevron: true) {
                            navigationPath.append("dns")
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Site-based split tunneling",
                                        subtitle: "Allows you to select which sites you want to access through the VPN",
                                        showChevron: true) {
                            navigationPath.append("splitTunneling")
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    }
                    .padding(.top, 12)
                }
                Spacer()
            }
            .background(AmneziaTheme.bgBase)
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { destination in
                if destination == "dns" {
                    DnsView()
                } else if destination == "splitTunneling" {
                    SplitTunnelingView()
                }
            }
            .onAppear {
                useAmneziaDns = appState.core.settings.useAmneziaDns
            }
            .onChange(of: useAmneziaDns) { _, newValue in
                appState.core.settings.useAmneziaDns = newValue
            }
        }
    }
}

struct DnsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var primaryDns = ""
    @State private var secondaryDns = ""
    @State private var showRestoreConfirm = false
    @State private var primaryError: String?

    private func isValidIp(_ value: String) -> Bool {
        let parts = value.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let number = Int(part), number >= 0, number <= 255 else { return false }
            return !part.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: "DNS servers", onBack: { dismiss() })
            Text("If AmneziaDNS is not used or installed")
                .font(AmneziaTheme.Font.body)
                .foregroundColor(AmneziaTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Primary DNS")
                        .font(AmneziaTheme.Font.h3)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    AmneziaTextField(placeholder: "1.1.1.1", text: $primaryDns, keyboardType: .decimalPad)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    if let primaryError {
                        Text(primaryError)
                            .font(AmneziaTheme.Font.small)
                            .foregroundColor(AmneziaTheme.statusDestructive)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                    Text("Secondary DNS")
                        .font(AmneziaTheme.Font.h3)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    AmneziaTextField(placeholder: "1.0.0.1", text: $secondaryDns, keyboardType: .decimalPad)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Button(action: { showRestoreConfirm = true }) {
                        Text("Restore default")
                            .font(AmneziaTheme.Font.button)
                            .foregroundColor(AmneziaTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AmneziaTheme.bgSurfaceAlt)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                }
            }
            AmneziaButton(title: "Save") {
                if primaryDns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    primaryError = "Primary DNS cannot be empty"
                    return
                }
                if !isValidIp(primaryDns) || (!secondaryDns.isEmpty && !isValidIp(secondaryDns)) {
                    primaryError = "Invalid IP address format"
                    return
                }
                primaryError = nil
                appState.core.settings.primaryDns = primaryDns
                appState.core.settings.secondaryDns = secondaryDns
                appState.showSnackbar("Settings saved")
                dismiss()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
        .onAppear {
            primaryDns = appState.core.settings.primaryDns
            secondaryDns = appState.core.settings.secondaryDns
            if appState.defaultServer?.isFromApi == true {
                appState.showSnackbar("Default server does not support custom DNS")
            }
        }
        .alert("Restore default DNS settings?", isPresented: $showRestoreConfirm) {
            Button("Continue") {
                primaryDns = SettingsStore.defaultPrimaryDns
                secondaryDns = SettingsStore.defaultSecondaryDns
                appState.core.settings.primaryDns = primaryDns
                appState.core.settings.secondaryDns = secondaryDns
                appState.showSnackbar("Settings have been reset")
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
