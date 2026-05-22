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

    func fetchModelChannelMap() async throws -> [String: [String]] {
        let response: PaginatedResponse<ModelMeta> = try await client.get("/api/models/", queryItems: [
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "page_size", value: "1000")
        ])
        var result: [String: [String]] = [:]
        for model in response.items {
            let channelNames = model.boundChannels.map { $0.name }
            if !channelNames.isEmpty {
                result[model.modelName] = channelNames
            }
        }
        return result
    }

    func update(key: String, value: String) async throws {
        let _: EmptyResponseData = try await client.put("/api/option/", body: OptionUpdateRequest(key: key, value: value))
    }

    func batchUpdate(_ options: [String: String]) async throws {
        let optionArray = options.map { OptionUpdateRequest(key: $0.key, value: $0.value) }
        let _: EmptyResponseData = try await client.put("/api/option/batch", body: OptionBatchUpdateRequest(options: optionArray))
    }
}

struct ModelMeta: Codable, Identifiable {
    var id: String { modelName }
    let modelName: String
    let boundChannels: [BoundChannel]

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case boundChannels = "bound_channels"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelName = (try? container.decode(String.self, forKey: .modelName)) ?? ""
        boundChannels = (try? container.decode([BoundChannel].self, forKey: .boundChannels)) ?? []
    }
}

struct BoundChannel: Codable {
    let name: String
    let type: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        type = (try? container.decode(Int.self, forKey: .type)) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
    }
}
