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

    func create(_ payload: DynamicObject) async throws {
        let wrapped = AddChannelRequest(mode: "single", channel: payload)
        let _: EmptyResponseData = try await client.post("/api/channel/", body: wrapped)
    }

    func update(_ payload: DynamicObject) async throws {
        let _: EmptyResponseData = try await client.put("/api/channel/", body: payload)
    }

    func delete(id: Int) async throws {
        let _: EmptyResponseData = try await client.delete("/api/channel/\(id)")
    }

    func test(id: Int) async throws {
        let _: EmptyResponseData = try await client.get("/api/channel/test/\(id)")
    }

    func updateBalance(id: Int) async throws {
        let _: EmptyResponseData = try await client.get("/api/channel/update_balance/\(id)")
    }

    /// Fetch available groups from server
    func fetchGroups() async throws -> [String] {
        let response: GroupNamesResponse = try await client.get("/api/group/")
        return response.names
    }

    /// Fetch global options (for pricing display)
    func fetchOptions() async throws -> [OptionItem] {
        try await client.get("/api/option/")
    }

    /// Batch update options (for pricing save)
    func batchUpdateOptions(_ options: [OptionUpdateRequest]) async throws {
        let _: EmptyResponseData = try await client.put("/api/option/batch", body: OptionBatchUpdateRequest(options: options))
    }

    /// Fetch models from upstream for an existing channel
    func fetchModels(channelId: Int) async throws -> [String] {
        try await client.get("/api/channel/fetch_models/\(channelId)")
    }

    /// Fetch models from upstream with explicit parameters (for new channels)
    func fetchModels(type: Int, key: String, baseURL: String) async throws -> [String] {
        try await client.post("/api/channel/fetch_models", body: FetchModelsRequest(type: type, key: key, baseURL: baseURL))
    }

    private func pagination(page: Int, pageSize: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "p", value: String(page)), URLQueryItem(name: "page_size", value: String(pageSize))]
    }
}

private struct AddChannelRequest: Encodable {
    let mode: String
    let channel: DynamicObject
}

private struct FetchModelsRequest: Encodable {
    let type: Int
    let key: String
    let baseURL: String

    enum CodingKeys: String, CodingKey {
        case type
        case key
        case baseURL = "base_url"
    }
}
