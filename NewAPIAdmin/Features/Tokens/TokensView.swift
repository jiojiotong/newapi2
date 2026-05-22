import SwiftUI

struct TokensView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                TokensContentView(viewModel: viewModel, holder: holder)
            } else {
                LoadingStateView(title: "准备令牌管理")
            }
        }
        .navigationTitle("令牌管理")
        .task { setupAndLoad() }
    }

    private func setupAndLoad() {
        guard holder.viewModel == nil, let client = try? sessionStore.activeClient() else { return }
        let viewModel = TokensViewModel(service: TokenService(client: client))
        holder.viewModel = viewModel
        Task { await viewModel.load() }
    }

    @MainActor final class Holder: ObservableObject {
        @Published var viewModel: TokensViewModel?
        @Published var searchText = ""
    }
}

private struct TokensContentView: View {
    @ObservedObject var viewModel: TokensViewModel
    @ObservedObject var holder: TokensView.Holder
    @State private var showingCreate = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage { Section { Text(error).foregroundColor(Color.red) } }
            if let success = viewModel.successMessage { Section { Text(success).foregroundColor(Color.green) } }
            ForEach(viewModel.items) { token in
                NavigationLink {
                    TokenDetailView(token: token, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(token.name).font(Font.headline)
                        Text("sk-\(token.key)")
                            .font(Font.caption)
                            .foregroundColor(Color.secondary)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(token.status == 1 ? "启用" : "禁用")
                                .font(Font.caption2)
                                .foregroundColor(token.status == 1 ? Color.green : Color.red)
                            if token.unlimitedQuota == true {
                                Text("无限额度")
                                    .font(Font.caption2)
                            } else {
                                Text("余额 \(formatQuota(token.remainQuota))")
                                    .font(Font.caption2)
                            }
                            Text("已用 \(formatQuota(token.usedQuota))")
                                .font(Font.caption2)
                                .foregroundColor(Color.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Section {
                LabeledContent("当前页", value: String(viewModel.currentPage))
                if let total = viewModel.total {
                    LabeledContent("总数", value: String(total))
                }
                HStack {
                    Button("上一页") { Task { await viewModel.previousPage() } }
                        .disabled(!viewModel.canGoPrevious || viewModel.isLoading)
                    Spacer()
                    Button("下一页") { Task { await viewModel.nextPage() } }
                        .disabled(!viewModel.canGoNext || viewModel.isLoading)
                }
            }
        }
        .searchable(text: $holder.searchText, prompt: "搜索令牌")
        .onSubmit(of: .search) {
            viewModel.searchText = holder.searchText
            Task { await viewModel.search() }
        }
        .onChange(of: holder.searchText) { newValue in
            if newValue.isEmpty {
                viewModel.searchText = ""
                Task { await viewModel.load() }
            }
        }
        .overlay {
            if viewModel.isLoading { LoadingStateView(title: "加载令牌") }
            else if viewModel.items.isEmpty { EmptyStateView(title: "没有令牌", message: "创建令牌或调整搜索条件。") }
        }
        .toolbar {
            Button("新增") { showingCreate = true }
                .disabled(viewModel.isLoading)
            Button("刷新") {
                Task {
                    await viewModel.load()
                    if viewModel.errorMessage == nil { viewModel.successMessage = "刷新成功" }
                }
            }
                .disabled(viewModel.isLoading)
        }
        .navigationDestination(isPresented: $showingCreate) {
            TokenCreateView(viewModel: viewModel)
        }
    }

    private func formatQuota(_ quota: Int?) -> String {
        guard let q = quota else { return "$0.00" }
        let dollars = Double(q) / 500000.0
        return String(format: "$%.2f", dollars)
    }
}

// MARK: - Token Detail

private struct TokenDetailView: View {
    let token: APIToken
    @ObservedObject var viewModel: TokensViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var fullKey: String?
    @State private var isFetchingKey = false
    @State private var confirmingDelete = false
    @State private var actionResult: String?
    @State private var actionIsError = false

    var body: some View {
        List {
            Section("基本信息") {
                LabeledContent("名称", value: token.name)
                LabeledContent("状态", value: token.status == 1 ? "启用" : "禁用")
                LabeledContent("分组", value: token.group ?? "default")
                if token.unlimitedQuota == true {
                    LabeledContent("额度", value: "无限")
                } else {
                    LabeledContent("剩余额度", value: formatQuota(token.remainQuota))
                }
                LabeledContent("已用额度", value: formatQuota(token.usedQuota))
                LabeledContent("过期时间", value: formatExpiry(token.expiredTime))
                if token.modelLimitsEnabled == true, let limits = token.modelLimits, !limits.isEmpty {
                    LabeledContent("模型限制", value: limits)
                }
            }

            Section("密钥") {
                if let key = fullKey {
                    Text("sk-\(key)")
                        .font(Font.system(Font.TextStyle.caption, design: Font.Design.monospaced))
                        .textSelection(.enabled)
                } else {
                    Button {
                        Task { await fetchFullKey() }
                    } label: {
                        HStack {
                            Text("查看完整密钥")
                            Spacer()
                            if isFetchingKey { ProgressView() }
                        }
                    }
                    .disabled(isFetchingKey)
                }
            }

            if let result = actionResult {
                Section {
                    Text(result).foregroundColor(actionIsError ? Color.red : Color.green)
                }
            }

            Section("操作") {
                Button(token.status == 1 ? "禁用令牌" : "启用令牌") {
                    Task { await toggleStatus() }
                }
                Button("删除", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(token.name)
        .onChange(of: viewModel.items) { _ in
            if !viewModel.items.contains(where: { $0.id == token.id }) {
                dismiss()
            }
        }
        .confirmationDialog("确认删除令牌？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) { Task { await viewModel.delete(token) } }
        }
    }

    private func fetchFullKey() async {
        isFetchingKey = true
        defer { isFetchingKey = false }
        fullKey = await viewModel.getFullKey(id: token.id)
    }

    private func toggleStatus() async {
        actionResult = nil
        let newStatus = token.status == 1 ? 2 : 1
        await viewModel.updateStatus(id: token.id, status: newStatus)
        if viewModel.errorMessage == nil {
            actionResult = newStatus == 1 ? "已启用" : "已禁用"
            actionIsError = false
        } else {
            actionResult = viewModel.errorMessage
            actionIsError = true
            viewModel.errorMessage = nil
        }
    }

    private func formatQuota(_ quota: Int?) -> String {
        guard let q = quota else { return "$0.00" }
        return String(format: "$%.2f", Double(q) / 500000.0)
    }

    private func formatExpiry(_ timestamp: Int?) -> String {
        guard let ts = timestamp else { return "永不过期" }
        if ts == -1 { return "永不过期" }
        let date = Date(timeIntervalSince1970: Double(ts))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Token Create

private struct TokenCreateView: View {
    @ObservedObject var viewModel: TokensViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var unlimitedQuota = false
    @State private var quotaText = "500000"
    @State private var neverExpire = true
    @State private var modelLimitsEnabled = false
    @State private var modelLimits = ""
    @State private var group = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }

            Section("基本信息") {
                TextField("令牌名称", text: $name)
                    .adminPlainTextInput()
                TextField("分组（可选）", text: $group)
                    .adminPlainTextInput()
            }

            Section("额度") {
                Toggle("无限额度", isOn: $unlimitedQuota)
                if !unlimitedQuota {
                    HStack {
                        Text("额度")
                        Spacer()
                        TextField("500000", text: $quotaText)
                            .adminNumberKeyboard()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .adminEditableField()
                    }
                    Text("500000 = $1.00")
                        .font(Font.caption)
                        .foregroundColor(Color.secondary)
                }
            }

            Section("过期时间") {
                Toggle("永不过期", isOn: $neverExpire)
            }

            Section("模型限制") {
                Toggle("启用模型限制", isOn: $modelLimitsEnabled)
                if modelLimitsEnabled {
                    TextField("模型名称，逗号分隔", text: $modelLimits)
                        .adminPlainTextInput()
                }
            }

            Section {
                Button("创建令牌") {
                    Task { await create() }
                }
                .disabled(isSaving || name.isEmpty)
            }
        }
        .navigationTitle("新增令牌")
    }

    private func create() async {
        isSaving = true
        defer { isSaving = false }

        var values: [String: AnyJSONValue] = [
            "name": .string(name),
            "unlimited_quota": .bool(unlimitedQuota),
            "expired_time": .int(neverExpire ? -1 : 0)
        ]

        if !unlimitedQuota, let quota = Int(quotaText) {
            values["remain_quota"] = .int(quota)
        }

        if modelLimitsEnabled {
            values["model_limits_enabled"] = .bool(true)
            values["model_limits"] = .string(modelLimits)
        }

        if !group.trimmingCharacters(in: .whitespaces).isEmpty {
            values["group"] = .string(group.trimmingCharacters(in: .whitespaces))
        }

        await viewModel.create(DynamicObject(values: values))
        if viewModel.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - ViewModel

@MainActor
final class TokensViewModel: ObservableObject {
    @Published var items: [APIToken] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var currentPage = 1
    @Published var total: Int?

    private let service: TokenService
    private let pageSize = 50

    init(service: TokenService) {
        self.service = service
    }

    var canGoPrevious: Bool { currentPage > 1 }
    var canGoNext: Bool {
        if let total { return currentPage * pageSize < total }
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

    func previousPage() async { guard canGoPrevious else { return }; await load(page: currentPage - 1) }
    func nextPage() async { guard canGoNext else { return }; await load(page: currentPage + 1) }

    func create(_ payload: DynamicObject) async {
        await perform { try await service.create(payload) }
        await load()
    }

    func delete(_ token: APIToken) async {
        await perform {
            try await service.delete(id: token.id)
            items.removeAll { $0.id == token.id }
        }
    }

    func updateStatus(id: Int, status: Int) async {
        await perform {
            let payload = DynamicObject(values: ["id": .int(id), "status": .int(status)])
            try await service.update(payload)
        }
        await load()
    }

    func getFullKey(id: Int) async -> String? {
        do {
            return try await service.getFullKey(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
