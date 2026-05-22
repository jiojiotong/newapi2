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
            let result = try await service.test(id: item.id)
            serverMessage = String(describing: result.rawValue)
        }
    }

    func updateBalance(_ item: Channel) async {
        await perform {
            let result = try await service.updateBalance(id: item.id)
            serverMessage = String(describing: result.rawValue)
        }
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

    func createValidated(quota: Double, count: Int, expiredTime: Int?, usageLimit: Int?) async {
        await perform {
            try FormValidation.requirePositive(quota, field: "额度")
            try FormValidation.requirePositiveInt(count, field: "数量")
            if let expiredTime {
                try FormValidation.requirePositiveInt(expiredTime, field: "过期时间")
            }
            if let usageLimit {
                try FormValidation.requirePositiveInt(usageLimit, field: "使用次数")
            }

            var values: [String: AnyJSONValue] = [
                "quota": .double(quota),
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
    @Published var options: [String: String] = [:]
    @Published var selectedKey = PricingService.primaryKeys.first ?? "ModelPrice"
    @Published var editorText = "{}"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

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
            editorText = options[selectedKey] ?? "{}"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ key: String) {
        selectedKey = key
        editorText = options[key] ?? "{}"
    }

    func saveSelected() async {
        await save([selectedKey: editorText])
    }

    func saveModelBatch() async {
        var payload: [String: String] = [:]
        for key in PricingService.batchKeys {
            if let value = options[key] {
                payload[key] = key == selectedKey ? editorText : value
            }
        }
        payload[selectedKey] = editorText
        await save(payload, batch: true)
    }

    private func save(_ payload: [String: String], batch: Bool = false) async {
        errorMessage = nil
        successMessage = nil
        do {
            for (key, value) in payload where looksLikeJSONOption(key) {
                try FormValidation.validateJSONString(value, field: key)
            }
            if batch {
                try await service.batchUpdate(payload)
            } else if let key = payload.keys.first, let value = payload[key] {
                try await service.update(key: key, value: value)
            }
            options.merge(payload) { _, new in new }
            successMessage = "已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func looksLikeJSONOption(_ key: String) -> Bool {
        !["DefaultUseAutoGroup"].contains(key)
    }
}
