import Foundation

final class SettingsStore {
    private let defaults: UserDefaults

    static let amneziaDnsIp = "172.29.172.254"
    static let defaultPrimaryDns = "1.1.1.1"
    static let defaultSecondaryDns = "1.0.0.1"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var primaryDns: String {
        get { defaults.string(forKey: "Conf/primaryDns") ?? SettingsStore.defaultPrimaryDns }
        set { defaults.set(newValue, forKey: "Conf/primaryDns") }
    }

    var secondaryDns: String {
        get { defaults.string(forKey: "Conf/secondaryDns") ?? SettingsStore.defaultSecondaryDns }
        set { defaults.set(newValue, forKey: "Conf/secondaryDns") }
    }

    var useAmneziaDns: Bool {
        get { defaults.bool(forKey: "Conf/useAmneziaDns") }
        set { defaults.set(newValue, forKey: "Conf/useAmneziaDns") }
    }

    var isLoggingEnabled: Bool {
        get { defaults.bool(forKey: "Conf/isLoggingEnabled") }
        set { defaults.set(newValue, forKey: "Conf/isLoggingEnabled") }
    }

    var loggingEnabledSince: Date? {
        get { defaults.object(forKey: "Conf/loggingEnabledSince") as? Date }
        set { defaults.set(newValue, forKey: "Conf/loggingEnabledSince") }
    }

    func checkLoggingExpiry() {
        guard isLoggingEnabled, let since = loggingEnabledSince else { return }
        if Date().timeIntervalSince(since) > 14 * 24 * 60 * 60 {
            isLoggingEnabled = false
            loggingEnabledSince = nil
            Logger.shared.clearAll()
        }
    }

    var isScreenshotsEnabled: Bool {
        get {
            if defaults.object(forKey: "Conf/isScreenshotsEnabled") == nil { return true }
            return defaults.bool(forKey: "Conf/isScreenshotsEnabled")
        }
        set { defaults.set(newValue, forKey: "Conf/isScreenshotsEnabled") }
    }

    var isAutoUpdateCheckEnabled: Bool {
        get {
            if defaults.object(forKey: "Conf/isAutoUpdateCheckEnabled") == nil { return true }
            return defaults.bool(forKey: "Conf/isAutoUpdateCheckEnabled")
        }
        set { defaults.set(newValue, forKey: "Conf/isAutoUpdateCheckEnabled") }
    }

    var isNewsNotificationsEnabled: Bool {
        get {
            if defaults.object(forKey: "Conf/isNewsNotificationsEnabled") == nil { return true }
            return defaults.bool(forKey: "Conf/isNewsNotificationsEnabled")
        }
        set { defaults.set(newValue, forKey: "Conf/isNewsNotificationsEnabled") }
    }

    var isDevModeEnabled: Bool {
        get { defaults.bool(forKey: "Conf/isDevModeEnabled") }
        set { defaults.set(newValue, forKey: "Conf/isDevModeEnabled") }
    }

    var installationUuid: String {
        if let uuid = defaults.string(forKey: "Conf/installationUuid"), !uuid.isEmpty {
            return uuid
        }
        let uuid = UUID().uuidString
        defaults.set(uuid, forKey: "Conf/installationUuid")
        return uuid
    }

    func resetAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("Conf/") {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: "servers.v1")
        defaults.removeObject(forKey: "defaultServerId")
        defaults.removeObject(forKey: "splitTunneling.v1")
    }
}
