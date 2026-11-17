import Foundation

final class ServerStore {
    private let defaults: UserDefaults
    private let serversKey = "servers.v1"
    private let defaultServerKey = "defaultServerId"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var servers: [VPNServer] {
        get {
            guard let data = defaults.data(forKey: serversKey),
                  let servers = try? JSONDecoder().decode([VPNServer].self, from: data) else {
                return []
            }
            return servers
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: serversKey)
            }
        }
    }

    var defaultServerId: String? {
        get { defaults.string(forKey: defaultServerKey) }
        set { defaults.set(newValue, forKey: defaultServerKey) }
    }

    var defaultServer: VPNServer? {
        guard let id = defaultServerId else { return servers.first }
        return servers.first { $0.id == id } ?? servers.first
    }

    func add(_ server: VPNServer) {
        var current = servers
        current.append(server)
        servers = current
        if defaultServerId == nil {
            defaultServerId = server.id
        }
    }

    func update(_ server: VPNServer) {
        var current = servers
        if let index = current.firstIndex(where: { $0.id == server.id }) {
            current[index] = server
            servers = current
        }
    }

    func remove(serverId: String) {
        var current = servers
        current.removeAll { $0.id == serverId }
        servers = current
        if defaultServerId == serverId {
            defaultServerId = current.first?.id
        }
    }

    func nextAvailableServerName() -> String {
        let names = Set(servers.map { $0.name })
        var index = servers.count + 1
        while names.contains("Server \(index)") {
            index += 1
        }
        return "Server \(index)"
    }
}
