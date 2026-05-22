import Foundation

struct ServerProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var baseURL: URL
    var lastUser: String
    var lastConnectedAt: Date

    init(id: UUID = UUID(), name: String, baseURL: URL, lastUser: String, lastConnectedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.lastUser = lastUser
        self.lastConnectedAt = lastConnectedAt
    }
}
