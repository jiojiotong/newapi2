import Combine
import Foundation

@MainActor
final class ChannelsViewModel: ObservableObject {
    @Published var items: [Channel] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var serverMessage: String?
    @Published var currentPage = 1
    @Published var total: Int?

    private let service: ChannelService
    private let pageSize = 50

    init(service: ChannelService) {
        self.service = service
    }

    var canGoPrevious: Bool { currentPage > 1 }
    var canGoNext: Bool {
        if let total {
            return currentPage * pageSize < total
        }
        return items.count == pageSize
    }

    func load(page: Int? = nil) async {
        let targetPage = max(1, page ?? currentPage)
        await perform {
            let response = try await service.list(page: targetPage, pageSize: pageSize)
            items = response.items
            total = response.total
            currentPage = targetPage
        }
    }

    func search() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await load()
            return
        }
        await perform {
            let response = try await service.search(keyword: searchText)
            items = response.items
            total = response.total
            currentPage = 1
        }
    }

    func previousPage() async {
        guard canGoPrevious else { return }
        await load(page: currentPage - 1)
    }

    func nextPage() async {
        guard canGoNext else { return }
        await load(page: currentPage + 1)
    }

    func delete(_ item: Channel) async {
        await perform {
            try await service.delete(id: item.id)
            items.removeAll { $0.id == item.id }
        }
    }

    func test(_ item: Channel) async {
        await perform {
            try await service.test(id: item.id)
            serverMessage = "渠道测试成功"
        }
    }

    func updateBalance(_ item: Channel) async {
        await perform {
            try await service.updateBalance(id: item.id)
            serverMessage = "余额已更新"
        }
        await load()
    }

    func update(_ payload: DynamicObject) async {
        await perform {
            _ = try await service.update(payload)
        }
        await load()
    }

    func create(_ payload: DynamicObject) async {
        await perform {
            _ = try await service.create(payload)
        }
        await load()
    }

    func detail(id: Int) async -> Channel? {
        do {
            return try await service.detail(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class UsersViewModel: ObservableObject {
    @Published var items: [ManagedUser] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var total: Int?

    private let service: UserService
    private let pageSize = 50

    init(service: UserService) {
        self.service = service
    }

    var canGoPrevious: Bool { currentPage > 1 }
    var canGoNext: Bool {
        if let total {
            return currentPage * pageSize < total
        }
        return items.count == pageSize
    }

    func load(page: Int? = nil) async {
        let targetPage = max(1, page ?? currentPage)
        await perform {
            let response = try await service.list(page: targetPage, pageSize: pageSize)
            items = response.items
            total = response.total
            currentPage = targetPage
        }
    }

    func search() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await load()
            return
        }
        await perform {
            let response = try await service.search(keyword: searchText)
            items = response.items
            total = response.total
            currentPage = 1
        }
    }

    func previousPage() async {
        guard canGoPrevious else { return }
        await load(page: currentPage - 1)
    }

    func nextPage() async {
        guard canGoNext else { return }
        await load(page: currentPage + 1)
    }

    func manage(_ item: ManagedUser, action: String) async {
        await perform { try await service.manage(id: item.id, action: action) }
        await load()
    }

    func update(_ payload: DynamicObject) async {
        await perform { _ = try await service.update(payload) }
        await load()
    }

    func create(_ payload: DynamicObject) async {
        await perform { _ = try await service.create(payload) }
        await load()
    }

    func delete(_ item: ManagedUser) async {
        await perform {
            try await service.delete(id: item.id)
            items.removeAll { $0.id == item.id }
        }
    }

    func detail(id: Int) async -> ManagedUser? {
        do {
            return try await service.detail(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do { try await operation() } catch { errorMessage = error.localizedDescription }
    }
}

@MainActor
final class RedemptionsViewModel: ObservableObject {
    @Published var items: [RedemptionCode] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var total: Int?

    private let service: RedemptionService
    private let pageSize = 50

    init(service: RedemptionService) {
        self.service = service
    }

    var canGoPrevious: Bool { currentPage > 1 }
    var canGoNext: Bool {
        if let total {
            return currentPage * pageSize < total
        }
        return items.count == pageSize
    }

    func load(page: Int? = nil) async {
        let targetPage = max(1, page ?? currentPage)
        await perform {
            let response = try await service.list(page: targetPage, pageSize: pageSize)
            items = response.items
            total = response.total
            currentPage = targetPage
        }
    }

    func search() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await load()
            return
        }
        await perform {
            let response = try await service.search(keyword: searchText)
            items = response.items
            total = response.total
            currentPage = 1
        }
    }

    func previousPage() async {
        guard canGoPrevious else { return }
        await load(page: currentPage - 1)
    }

    func nextPage() async {
        guard canGoNext else { return }
        await load(page: currentPage + 1)
    }

    func delete(_ item: RedemptionCode) async {
        await perform {
            try await service.delete(id: item.id)
            items.removeAll { $0.id == item.id }
        }
    }

    func clearInvalid() async {
        await perform { try await service.clearInvalid() }
        await load()
    }

    func update(_ payload: DynamicObject) async {
        await perform { _ = try await service.update(payload) }
        await load()
    }

    func create(_ payload: DynamicObject) async {
        await perform { _ = try await service.create(payload) }
        await load()
    }

    func createValidated(name: String, quota: Int, count: Int, expiredTime: Int?, usageLimit: Int?) async {
        await perform {
            try FormValidation.requirePositiveInt(quota, field: "额度")
            try FormValidation.requirePositiveInt(count, field: "数量")
            if let expiredTime {
                try FormValidation.requirePositiveInt(expiredTime, field: "过期时间")
            }
            if let usageLimit {
                try FormValidation.requirePositiveInt(usageLimit, field: "使用次数")
            }

            var values: [String: AnyJSONValue] = [
                "name": .string(name),
                "quota": .int(quota),
                "count": .int(count)
            ]
            if let expiredTime {
                values["expired_time"] = .int(expiredTime)
            }
            if let usageLimit {
                values["usage_limit"] = .int(usageLimit)
            }
            _ = try await service.create(DynamicObject(values: values))
        }
        await load()
    }

    func detail(id: Int) async -> RedemptionCode? {
        do {
            return try await service.detail(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do { try await operation() } catch { errorMessage = error.localizedDescription }
    }
}

@MainActor
final class PricingViewModel: ObservableObject {
    @Published var modelRows: [ModelPricingRow] = []
    @Published var groupRows: [GroupRatioRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var options: [String: String] = [:]
    private let service: PricingService

    init(service: PricingService) {
        self.service = service
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            options = try await service.fetchOptions()
            buildRows()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAll() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = buildPayload()
            try await service.batchUpdate(payload)
            options.merge(payload) { _, new in new }
        } catch {
            errorMessage = "模型定价保存失败：\(error.localizedDescription)"
            return
        }
        do {
            let groupJSON = buildGroupRatioJSON()
            try await service.update(key: "GroupRatio", value: groupJSON)
            options["GroupRatio"] = groupJSON
            successMessage = "已保存"
        } catch {
            errorMessage = "模型定价已保存，但分组倍率保存失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Model operations

    func addModel(_ name: String) {
        guard !modelRows.contains(where: { $0.modelName == name }) else { return }
        modelRows.append(ModelPricingRow(modelName: name, modelRatio: 1, completionRatio: 1))
        modelRows.sort { $0.modelName < $1.modelName }
    }

    func removeModel(_ name: String) {
        modelRows.removeAll { $0.modelName == name }
    }

    func updateModel(_ name: String, modelRatio: Double?, completionRatio: Double?, modelPrice: Double?, cacheRatio: Double?, createCacheRatio: Double?, imageRatio: Double?, audioRatio: Double?, audioCompletionRatio: Double?) {
        guard let index = modelRows.firstIndex(where: { $0.modelName == name }) else { return }
        modelRows[index].modelRatio = modelRatio ?? 0
        modelRows[index].completionRatio = completionRatio ?? 0
        modelRows[index].modelPrice = modelPrice
        modelRows[index].cacheRatio = cacheRatio
        modelRows[index].createCacheRatio = createCacheRatio
        modelRows[index].imageRatio = imageRatio
        modelRows[index].audioRatio = audioRatio
        modelRows[index].audioCompletionRatio = audioCompletionRatio
    }

    // MARK: - Group operations

    func addGroup(_ name: String) {
        guard !groupRows.contains(where: { $0.groupName == name }) else { return }
        groupRows.append(GroupRatioRow(groupName: name, ratio: 1))
        groupRows.sort { $0.groupName < $1.groupName }
    }

    func removeGroup(_ name: String) {
        groupRows.removeAll { $0.groupName == name }
    }

    func updateGroup(_ name: String, ratio: Double) {
        guard let index = groupRows.firstIndex(where: { $0.groupName == name }) else { return }
        groupRows[index].ratio = ratio
    }

    // MARK: - Private

    private func buildRows() {
        let modelRatioMap = parseJSON(options["ModelRatio"])
        let completionRatioMap = parseJSON(options["CompletionRatio"])
        let modelPriceMap = parseJSON(options["ModelPrice"])
        let cacheRatioMap = parseJSON(options["CacheRatio"])
        let createCacheRatioMap = parseJSON(options["CreateCacheRatio"])
        let imageRatioMap = parseJSON(options["ImageRatio"])
        let audioRatioMap = parseJSON(options["AudioRatio"])
        let audioCompletionRatioMap = parseJSON(options["AudioCompletionRatio"])

        var allModels = Set<String>()
        allModels.formUnion(modelRatioMap.keys)
        allModels.formUnion(completionRatioMap.keys)
        allModels.formUnion(modelPriceMap.keys)
        allModels.formUnion(cacheRatioMap.keys)
        allModels.formUnion(createCacheRatioMap.keys)
        allModels.formUnion(imageRatioMap.keys)
        allModels.formUnion(audioRatioMap.keys)
        allModels.formUnion(audioCompletionRatioMap.keys)

        modelRows = allModels.sorted().map { name in
            ModelPricingRow(
                modelName: name,
                modelRatio: modelRatioMap[name] ?? 1,
                completionRatio: completionRatioMap[name] ?? 1,
                modelPrice: modelPriceMap[name],
                cacheRatio: cacheRatioMap[name],
                createCacheRatio: createCacheRatioMap[name],
                imageRatio: imageRatioMap[name],
                audioRatio: audioRatioMap[name],
                audioCompletionRatio: audioCompletionRatioMap[name]
            )
        }

        let groupRatioMap = parseJSON(options["GroupRatio"])
        groupRows = groupRatioMap.sorted { $0.key < $1.key }.map { GroupRatioRow(groupName: $0.key, ratio: $0.value) }
    }

    private func buildPayload() -> [String: String] {
        var modelRatioMap: [String: Double] = [:]
        var completionRatioMap: [String: Double] = [:]
        var modelPriceMap: [String: Double] = [:]
        var cacheRatioMap: [String: Double] = [:]
        var createCacheRatioMap: [String: Double] = [:]
        var imageRatioMap: [String: Double] = [:]
        var audioRatioMap: [String: Double] = [:]
        var audioCompletionRatioMap: [String: Double] = [:]

        for row in modelRows {
            modelRatioMap[row.modelName] = row.modelRatio
            completionRatioMap[row.modelName] = row.completionRatio
            if let v = row.modelPrice, v > 0 {
                modelPriceMap[row.modelName] = v
            }
            if let v = row.cacheRatio {
                cacheRatioMap[row.modelName] = v
            }
            if let v = row.createCacheRatio {
                createCacheRatioMap[row.modelName] = v
            }
            if let v = row.imageRatio {
                imageRatioMap[row.modelName] = v
            }
            if let v = row.audioRatio {
                audioRatioMap[row.modelName] = v
            }
            if let v = row.audioCompletionRatio {
                audioCompletionRatioMap[row.modelName] = v
            }
        }

        var payload: [String: String] = [:]
        payload["ModelRatio"] = toJSON(modelRatioMap)
        payload["CompletionRatio"] = toJSON(completionRatioMap)
        payload["ModelPrice"] = toJSON(modelPriceMap)
        payload["CacheRatio"] = toJSON(cacheRatioMap)
        payload["CreateCacheRatio"] = toJSON(createCacheRatioMap)
        payload["ImageRatio"] = toJSON(imageRatioMap)
        payload["AudioRatio"] = toJSON(audioRatioMap)
        payload["AudioCompletionRatio"] = toJSON(audioCompletionRatioMap)

        return payload
    }

    private func buildGroupRatioJSON() -> String {
        var groupRatioMap: [String: Double] = [:]
        for row in groupRows {
            groupRatioMap[row.groupName] = row.ratio
        }
        return toJSON(groupRatioMap)
    }

    private func parseJSON(_ jsonString: String?) -> [String: Double] {
        guard let str = jsonString, let data = str.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var result: [String: Double] = [:]
        for (key, value) in obj {
            if let num = value as? Double {
                result[key] = num
            } else if let num = value as? Int {
                result[key] = Double(num)
            }
        }
        return result
    }

    private func toJSON(_ map: [String: Double]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: map, options: [.sortedKeys]) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Data Models

struct ModelPricingRow: Identifiable, Equatable {
    var id: String { modelName }
    let modelName: String
    var modelRatio: Double
    var completionRatio: Double
    var modelPrice: Double?
    var cacheRatio: Double?
    var createCacheRatio: Double?
    var imageRatio: Double?
    var audioRatio: Double?
    var audioCompletionRatio: Double?
}

struct GroupRatioRow: Identifiable, Equatable {
    var id: String { groupName }
    let groupName: String
    var ratio: Double
}
