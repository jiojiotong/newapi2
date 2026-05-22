import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct LoginResponse: Decodable {
    let token: String?
    let id: Int?
    let username: String?
    let displayName: String?
    let role: Int?
    let status: Int?
    let group: String?
    let require2FA: Bool?

    var requiresTwoFactor: Bool {
        require2FA == true
    }

    var adminUser: AdminUser? {
        guard let id, let username, let role else {
            return nil
        }
        return AdminUser(id: id, username: username, displayName: displayName, role: role, status: status ?? 1, group: group)
    }

    enum CodingKeys: String, CodingKey {
        case token
        case id
        case username
        case displayName = "display_name"
        case role
        case status
        case group
        case require2FA = "require_2fa"
    }
}
