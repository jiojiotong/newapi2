import Foundation

final class RedemptionService {
    private let client: NewAPIClient

    init(client: NewAPIClient) {
        self.client = client
    }

    func list(page: Int, pageSize: Int) async throws -> PaginatedResponse<RedemptionCode> {
        try await client.get("/api/redemption/", queryItems: pagination(page: page, pageSize: pageSize))
    }

    func search(keyword: String) async throws -> PaginatedResponse<RedemptionCode> {
        try await client.get("/api/redemption/search", queryItems: [URLQueryItem(name: "keyword", value: keyword)])
    }

    func detail(id: Int) async throws -> RedemptionCode {
        try await client.get("/api/redemption/\(id)")
    }

    func create(_ payload: DynamicObject) async throws {
        let _: EmptyResponseData = try await client.post("/api/redemption/", body: payload)
    }

    func update(_ payload: DynamicObject) async throws {
        let _: EmptyResponseData = try await client.put("/api/redemption/", body: payload)
    }

    func delete(id: Int) async throws {
        let _: EmptyResponseData = try await client.delete("/api/redemption/\(id)")
    }

    func clearInvalid() async throws {
        let _: EmptyResponseData = try await client.delete("/api/redemption/invalid")
    }

    private func pagination(page: Int, pageSize: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "p", value: String(page)), URLQueryItem(name: "page_size", value: String(pageSize))]
    }
}
