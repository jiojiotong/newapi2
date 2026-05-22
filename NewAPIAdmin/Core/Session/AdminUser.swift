import Foundation

struct AdminUser: Codable, Equatable, Decodable, Identifiable {
    let id: Int
    let username: String
    let displayName: String?
    let role: Int
    let status: Int
    let group: String?

    var isAdmin: Bool {
        role >= 10
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case role
        case status
        case group
    }
}
