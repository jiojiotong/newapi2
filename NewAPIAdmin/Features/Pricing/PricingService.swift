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
        do {
            let _: EmptyResponseData = try await client.put("/api/option/", body: OptionUpdateRequest(key: key, value: value))
        } catch NewAPIError.forbidden {
            throw NewAPIError.validation("当前账号没有 Root 权限，无法修改系统选项。")
        }
    }

    func batchUpdate(_ options: [String: String]) async throws {
        do {
            let _: EmptyResponseData = try await client.put("/api/option/batch", body: OptionBatchUpdateRequest(options: options))
        } catch NewAPIError.forbidden {
            throw NewAPIError.validation("当前账号没有 Root 权限，无法批量修改模型定价选项。")
        }
    }
}
