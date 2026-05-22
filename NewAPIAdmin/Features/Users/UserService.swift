import Foundation

final class UserService {
    private let client: NewAPIClient

    init(client: NewAPIClient) {
        self.client = client
    }

    func list(page: Int, pageSize: Int) async throws -> PaginatedResponse<ManagedUser> {
        try await client.get("/api/user/", queryItems: pagination(page: page, pageSize: pageSize))
    }

    func search(keyword: String) async throws -> PaginatedResponse<ManagedUser> {
        try await client.get("/api/user/search", queryItems: [URLQueryItem(name: "keyword", value: keyword)])
    }

    func detail(id: Int) async throws -> ManagedUser {
        try await client.get("/api/user/\(id)")
    }

    func create(_ payload: DynamicObject) async throws -> ManagedUser {
        try await client.post("/api/user/", body: payload)
    }

    func update(_ payload: DynamicObject) async throws -> ManagedUser {
        try await client.put("/api/user/", body: payload)
    }

    func manage(id: Int, action: String) async throws {
        let _: EmptyResponseData = try await client.post("/api/user/manage", body: ManageUserRequest(id: id, action: action))
    }

    func delete(id: Int) async throws {
        let _: EmptyResponseData = try await client.delete("/api/user/\(id)")
    }

    private func pagination(page: Int, pageSize: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "p", value: String(page)), URLQueryItem(name: "page_size", value: String(pageSize))]
    }
}
