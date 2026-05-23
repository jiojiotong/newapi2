import Foundation

final class TokenService {
    private let client: NewAPIClient

    init(client: NewAPIClient) {
        self.client = client
    }

    func list(page: Int, pageSize: Int) async throws -> PaginatedResponse<APIToken> {
        try await client.get("/api/token/", queryItems: [
            URLQueryItem(name: "p", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ])
    }

    func search(keyword: String) async throws -> PaginatedResponse<APIToken> {
        try await client.get("/api/token/search", queryItems: [URLQueryItem(name: "keyword", value: keyword)])
    }

    func create(_ payload: DynamicObject) async throws {
        let _: EmptyResponseData = try await client.post("/api/token/", body: payload)
    }

    func update(_ payload: DynamicObject) async throws {
        let _: EmptyResponseData = try await client.put("/api/token/", body: payload)
    }

    func delete(id: Int) async throws {
        let _: EmptyResponseData = try await client.delete("/api/token/\(id)")
    }

    func getFullKey(id: Int) async throws -> String {
        let response: TokenKeyResponse = try await client.post("/api/token/\(id)/key", body: EmptyRequest())
        return response.key
    }

    func fetchGroups() async throws -> [String] {
        let response: GroupNamesResponse = try await client.get("/api/group/")
        return response.names
    }
}

struct APIToken: Codable, Identifiable, Equatable {
    let id: Int
    var name: String
    var key: String
    var status: Int?
    var expiredTime: Int?
    var remainQuota: Int?
    var unlimitedQuota: Bool?
    var modelLimitsEnabled: Bool?
    var modelLimits: String?
    var group: String?
    var usedQuota: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeIntIfPresent("id") ?? Int.random(in: Int.min ..< -1)
        name = container.decodeStringIfPresent("name") ?? ""
        key = container.decodeStringIfPresent("key") ?? ""
        status = container.decodeIntIfPresent("status")
        expiredTime = container.decodeIntIfPresent("expired_time")
        remainQuota = container.decodeIntIfPresent("remain_quota")
        unlimitedQuota = (try? container.decodeIfPresent(Bool.self, forKey: DynamicCodingKey(stringValue: "unlimited_quota")!))
        modelLimitsEnabled = (try? container.decodeIfPresent(Bool.self, forKey: DynamicCodingKey(stringValue: "model_limits_enabled")!))
        modelLimits = container.decodeStringIfPresent("model_limits")
        group = container.decodeStringIfPresent("group")
        usedQuota = container.decodeIntIfPresent("used_quota")
    }
}

struct TokenKeyResponse: Decodable {
    let key: String
}

private struct EmptyRequest: Encodable {}
