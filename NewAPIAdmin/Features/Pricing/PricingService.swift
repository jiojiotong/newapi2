import Foundation

final class PricingService {
    static let primaryKeys = [
        "ModelPrice", "ModelRatio", "CompletionRatio", "CacheRatio", "CreateCacheRatio", "ImageRatio", "AudioRatio", "AudioCompletionRatio", "GroupRatio", "UserUsableGroups", "GroupGroupRatio", "AutoGroups", "DefaultUseAutoGroup"
    ]

    static let batchKeys = ["ModelPrice", "ModelRatio", "CompletionRatio", "CacheRatio", "CreateCacheRatio", "ImageRatio", "AudioRatio", "AudioCompletionRatio"]

    private let client: NewAPIClient

    init(client: NewAPIClient) {
        self.client = client
    }

    func fetchOptions() async throws -> [String: String] {
        let options: [OptionItem] = try await client.get("/api/option/")
        return OptionParser.dictionary(from: options)
    }

    func update(key: String, value: String) async throws {
        let _: EmptyResponseData = try await client.put("/api/option/", body: OptionUpdateRequest(key: key, value: value))
    }

    func batchUpdate(_ options: [String: String]) async throws {
        let optionArray = options.map { OptionUpdateRequest(key: $0.key, value: $0.value) }
        let _: EmptyResponseData = try await client.put("/api/option/batch", body: OptionBatchUpdateRequest(options: optionArray))
    }
}
