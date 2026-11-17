import Foundation

enum SplitTunnelRouteMode: Int, Codable {
    case viaVpn = 1
    case directly = 2
}

final class SplitTunnelingStore {
    private let defaults: UserDefaults
    private let key = "splitTunneling.v1"

    struct State: Codable {
        var isEnabled: Bool = false
        var routeMode: SplitTunnelRouteMode = .viaVpn
        var viaVpnSites: [SplitTunnelSite] = []
        var directSites: [SplitTunnelSite] = []

        var sites: [SplitTunnelSite] {
            get { routeMode == .viaVpn ? viaVpnSites : directSites }
            set {
                if routeMode == .viaVpn {
                    viaVpnSites = newValue
                } else {
                    directSites = newValue
                }
            }
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var state: State {
        get {
            guard let data = defaults.data(forKey: key),
                  let state = try? JSONDecoder().decode(State.self, from: data) else {
                return State()
            }
            return state
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }

    func addSite(url: String, ips: [String]) {
        var current = state
        let cleaned = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !current.sites.contains(where: { $0.url == cleaned }) else { return }
        current.sites.append(SplitTunnelSite(url: cleaned, ips: ips))
        state = current
    }

    func removeSite(url: String) {
        var current = state
        current.sites.removeAll { $0.url == url }
        state = current
    }

    func removeAllSites() {
        var current = state
        current.sites.removeAll()
        state = current
    }

    func importSites(_ sites: [SplitTunnelSite], replace: Bool) {
        var current = state
        if replace {
            current.sites = sites
        } else {
            for site in sites where !current.sites.contains(where: { $0.url == site.url }) {
                current.sites.append(site)
            }
        }
        state = current
    }
}
