import Foundation

final class ChannelService {
    private let client: NewAPIClient

    init(client: NewAPIClient) {
        self.client = client
    }

    func list(page: Int, pageSize: Int) async throws -> PaginatedResponse<Channel> {
        try await client.get("/api/channel/", queryItems: pagination(page: page, pageSize: pageSize))
    }

    func search(keyword: String) async throws -> PaginatedResponse<Channel> {
        try await client.get("/api/channel/search", queryItems: [URLQueryItem(name: "keyword", value: keyword)])
    }

    func detail(id: Int) async throws -> Channel {
        try await client.get("/api/channel/\(id)")
    }

    func create(_ payload: DynamicObject) async throws -> Channel {
        try await client.post("/api/channel/", body: payload)
    }

    func update(_ payload: DynamicObject) async throws -> Channel {
        try await client.put("/api/channel/", body: payload)
    }

    func delete(id: Int) async throws {
        let _: EmptyResponseData = try await client.delete("/api/channel/\(id)")
    }

    func test(id: Int) async throws -> AnyJSONValue {
        try await client.get("/api/channel/test/\(id)")
    }

    func updateBalance(id: Int) async throws -> AnyJSONValue {
        try await client.get("/api/channel/update_balance/\(id)")
    }

    private func pagination(page: Int, pageSize: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "p", value: String(page)), URLQueryItem(name: "page_size", value: String(pageSize))]
    }
}
