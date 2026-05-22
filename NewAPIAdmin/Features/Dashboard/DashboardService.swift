import Foundation

struct DashboardCounts {
    var status: String?
    var channelCount: Int?
    var userCount: Int?
    var redemptionCount: Int?
}

final class DashboardService {
    private let client: NewAPIClient

    init(client: NewAPIClient) {
        self.client = client
    }

    func status() async throws -> ServerStatus {
        try await client.get("/api/status")
    }

    func channelCount() async throws -> Int {
        let response: PaginatedResponse<Channel> = try await client.get("/api/channel/", queryItems: pageSizeOne)
        return response.total ?? response.items.count
    }

    func userCount() async throws -> Int {
        let response: PaginatedResponse<ManagedUser> = try await client.get("/api/user/", queryItems: pageSizeOne)
        return response.total ?? response.items.count
    }

    func redemptionCount() async throws -> Int {
        let response: PaginatedResponse<RedemptionCode> = try await client.get("/api/redemption/", queryItems: pageSizeOne)
        return response.total ?? response.items.count
    }

    private var pageSizeOne: [URLQueryItem] {
        [URLQueryItem(name: "p", value: "1"), URLQueryItem(name: "page_size", value: "1")]
    }
}
