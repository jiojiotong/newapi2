import Foundation

final class ProfileStorage {
    private let profileKey = "newapi.admin.activeProfile"
    private let userKey = "newapi.admin.activeUser"
    private let lastServerURLKey = "newapi.admin.lastServerURL"
    private let accessTokenKey = "newapi.admin.accessToken"

    func save(profile: ServerProfile, user: AdminUser) {
        let encoder = JSONEncoder()
        if let profileData = try? encoder.encode(profile) {
            UserDefaults.standard.set(profileData, forKey: profileKey)
        }
        if let userData = try? encoder.encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        UserDefaults.standard.set(profile.baseURL.absoluteString, forKey: lastServerURLKey)
    }

    func saveAccessToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: accessTokenKey)
    }

    func loadAccessToken() -> String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
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
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
    }

    func clearAll() {
        clear()
        UserDefaults.standard.removeObject(forKey: lastServerURLKey)
    }

    func lastServerURL() -> String {
        UserDefaults.standard.string(forKey: lastServerURLKey) ?? ""
    }
}
