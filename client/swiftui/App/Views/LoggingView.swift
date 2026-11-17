import SwiftUI

struct LoggingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isLoggingEnabled = false
    @State private var showClearConfirm = false
    @State private var navigationPath = NavigationPath()
    @State private var exportData: Data?
    @State private var showExporter = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                AmneziaNavigationBar(title: "Logging", onBack: { dismiss() })
                Text("Logs help support figure out what's wrong")
                    .font(AmneziaTheme.Font.body)
                    .foregroundColor(AmneziaTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Record logs")
                                    .font(AmneziaTheme.Font.body)
                                    .foregroundColor(AmneziaTheme.textPrimary)
                                Text("Recording turns off after 14 days and logs are deleted")
                                    .font(AmneziaTheme.Font.small)
                                    .foregroundColor(AmneziaTheme.textTertiary)
                            }
                            Spacer()
                            AmneziaSwitch(isOn: $isLoggingEnabled)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .padding(.top, 12)
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        Text("Logs")
                            .font(AmneziaTheme.Font.body)
                            .foregroundColor(AmneziaTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                        AmneziaListItem(title: "Tunnel",
                                        subtitle: "Connection events · \(Logger.shared.sizeDescription(stream: .tunnel))",
                                        showChevron: true) {
                            navigationPath.append(Logger.Stream.tunnel)
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Application",
                                        subtitle: "App events · \(Logger.shared.sizeDescription(stream: .app))",
                                        showChevron: true) {
                            navigationPath.append(Logger.Stream.app)
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Save all logs",
                                        subtitle: ".zip archive with both logs",
                                        showChevron: true) {
                            if let data = Logger.shared.zipData() {
                                exportData = data
                                showExporter = true
                            } else {
                                appState.showSnackbar("Failed to save logs. Try again later")
                            }
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                        AmneziaListItem(title: "Clear all logs", isDestructive: true, showChevron: true) {
                            showClearConfirm = true
                        }
                        Divider().background(AmneziaTheme.borderSoft).padding(.leading, 16)
                    }
                }
                Spacer()
            }
            .background(AmneziaTheme.bgBase)
            .navigationBarHidden(true)
            .navigationDestination(for: Logger.Stream.self) { stream in
                LogViewerView(stream: stream)
            }
            .onAppear {
                isLoggingEnabled = appState.core.settings.isLoggingEnabled
            }
            .onChange(of: isLoggingEnabled) { _, newValue in
                appState.core.settings.isLoggingEnabled = newValue
                if newValue {
                    appState.core.settings.loggingEnabledSince = Date()
                    Logger.shared.log("Logging enabled")
                }
            }
            .alert("Clear all logs?", isPresented: $showClearConfirm) {
                Button("Clear", role: .destructive) {
                    Logger.shared.clearAll()
                    appState.showSnackbar("Logs have been cleaned up")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("App and tunnel logs will be deleted from the device and can't be restored")
            }
            .sheet(isPresented: $showExporter) {
                if let exportData {
                    ShareSheet(data: exportData, fileName: "logs.zip")
                }
            }
        }
    }
}

extension Logger.Stream: Hashable {}

struct LogViewerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let stream: Logger.Stream
    @State private var selectedStream: Logger.Stream
    @State private var logText = ""
    @State private var exportData: Data?
    @State private var showExporter = false

    init(stream: Logger.Stream) {
        self.stream = stream
        self._selectedStream = State(initialValue: stream)
    }

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: selectedStream == .app ? "Application" : "Tunnel", onBack: { dismiss() })
            AmneziaSegmentedControl(options: ["Application", "Tunnel"], selection: Binding(
                get: { selectedStream == .app ? 0 : 1 },
                set: { selectedStream = $0 == 0 ? .app : .tunnel }
            ))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            HStack(spacing: 8) {
                AmneziaButton(title: "Refresh", size: .small, style: .secondary) {
                    refresh()
                }
                AmneziaButton(title: "Copy", size: .small, style: .secondary) {
                    UIPasteboard.general.string = logText
                    appState.showSnackbar("Copied")
                }
                AmneziaButton(title: "Save", size: .small, style: .secondary) {
                    if let data = logText.data(using: .utf8) {
                        exportData = data
                        showExporter = true
                    } else {
                        appState.showSnackbar("Failed to save logs. Try again later")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            ScrollView {
                if logText.isEmpty {
                    Text("No logs yet")
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 48)
                } else {
                    Text(logText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
        .onAppear {
            refresh()
        }
        .onChange(of: selectedStream) { _, _ in
            refresh()
        }
        .sheet(isPresented: $showExporter) {
            if let exportData {
                ShareSheet(data: exportData, fileName: selectedStream == .app ? "app.log" : "tunnel.log")
            }
        }
    }

    private func refresh() {
        logText = Logger.shared.contents(stream: selectedStream)
    }
}
