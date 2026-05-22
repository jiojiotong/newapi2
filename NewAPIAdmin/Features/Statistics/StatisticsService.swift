import Foundation

struct LogStatResponse: Decodable {
    let quota: Int
    let rpm: Int
    let tpm: Int
}

struct QuotaDataPoint: Decodable, Identifiable {
    var id: String { "\(modelName)-\(createdAt)" }
    let modelName: String
    let createdAt: Int
    let tokenUsed: Int
    let count: Int
    let quota: Int

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case createdAt = "created_at"
        case tokenUsed = "token_used"
        case count
        case quota
    }
}

final class StatisticsService {
    private let client: NewAPIClient

    init(client: NewAPIClient) {
        self.client = client
    }

    /// Get overall log statistics (total quota consumed, RPM, TPM)
    func logStat() async throws -> LogStatResponse {
        try await client.get("/api/log/stat")
    }

    /// Get total user count
    func userCount() async throws -> Int {
        let response: PaginatedResponse<ManagedUser> = try await client.get("/api/user/", queryItems: [
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "page_size", value: "1")
        ])
        return response.total ?? 0
    }

    /// Get total channel count
    func channelCount() async throws -> Int {
        let response: PaginatedResponse<Channel> = try await client.get("/api/channel/", queryItems: [
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "page_size", value: "1")
        ])
        return response.total ?? 0
    }

    /// Get quota data for time-series (last 7 days by default)
    func quotaData(startTimestamp: Int? = nil, endTimestamp: Int? = nil) async throws -> [QuotaDataPoint] {
        var queryItems: [URLQueryItem] = []
        if let start = startTimestamp {
            queryItems.append(URLQueryItem(name: "start_timestamp", value: String(start)))
        }
        if let end = endTimestamp {
            queryItems.append(URLQueryItem(name: "end_timestamp", value: String(end)))
        }
        return try await client.get("/api/data/", queryItems: queryItems)
    }
}
