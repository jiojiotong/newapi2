import Foundation

final class ProfileStorage {
    private let profileKey = "newapi.admin.activeProfile"
    private let userKey = "newapi.admin.activeUser"
    private let lastServerURLKey = "newapi.admin.lastServerURL"
    private let savedServersKey = "newapi.admin.savedServers"

    func save(profile: ServerProfile, user: AdminUser) {
        let encoder = JSONEncoder()
        if let profileData = try? encoder.encode(profile) {
            UserDefaults.standard.set(profileData, forKey: profileKey)
        }
        if let userData = try? encoder.encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        UserDefaults.standard.set(profile.baseURL.absoluteString, forKey: lastServerURLKey)
        // Also save to server list
        addToSavedServers(SavedServer(name: profile.name, url: profile.baseURL.absoluteString, username: user.username))
    }

    func load() -> (ServerProfile, AdminUser)? {
        guard let profileData = UserDefaults.standard.data(forKey: profileKey),
              let userData = UserDefaults.standard.data(forKey: userKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        guard let profile = try? decoder.decode(ServerProfile.self, from: profileData),
              let user = try? decoder.decode(AdminUser.self, from: userData) else {
            return nil
        }
        return (profile, user)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    func clearAll() {
        clear()
        UserDefaults.standard.removeObject(forKey: lastServerURLKey)
        UserDefaults.standard.removeObject(forKey: savedServersKey)
    }

    func lastServerURL() -> String {
        UserDefaults.standard.string(forKey: lastServerURLKey) ?? ""
    }

    // MARK: - Multi-server management

    func loadSavedServers() -> [SavedServer] {
        guard let data = UserDefaults.standard.data(forKey: savedServersKey),
              let servers = try? JSONDecoder().decode([SavedServer].self, from: data) else {
            return []
        }
        return servers
    }

    func saveSavedServers(_ servers: [SavedServer]) {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: savedServersKey)
        }
    }

    func addToSavedServers(_ server: SavedServer) {
        var servers = loadSavedServers()
        // Update existing or add new
        if let index = servers.firstIndex(where: { $0.url == server.url && $0.username == server.username }) {
            servers[index] = server
        } else {
            servers.append(server)
        }
        saveSavedServers(servers)
    }

    func removeSavedServer(_ server: SavedServer) {
        var servers = loadSavedServers()
        servers.removeAll { $0.url == server.url && $0.username == server.username }
        saveSavedServers(servers)
    }
}

struct SavedServer: Codable, Identifiable, Equatable {
    var id: String { "\(url)_\(username)" }
    let name: String
    let url: String
    let username: String
}
