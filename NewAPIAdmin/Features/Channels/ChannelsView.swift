import SwiftUI

struct ChannelsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                ChannelsContentView(viewModel: viewModel, holder: holder)
            } else {
                LoadingStateView(title: "准备渠道管理")
            }
        }
        .navigationTitle("渠道")
        .task { setupAndLoad() }
    }

    private func setupAndLoad() {
        guard holder.viewModel == nil, let client = try? sessionStore.activeClient() else { return }
        let viewModel = ChannelsViewModel(service: ChannelService(client: client))
        holder.viewModel = viewModel
        Task { await viewModel.load() }
    }

    @MainActor final class Holder: ObservableObject {
        @Published var viewModel: ChannelsViewModel?
        @Published var searchText = ""
    }
}

private struct ChannelsContentView: View {
    @ObservedObject var viewModel: ChannelsViewModel
    @ObservedObject var holder: ChannelsView.Holder
    @State private var showingCreate = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }
            if let success = viewModel.successMessage {
                Section { Text(success).foregroundColor(Color.green) }
            }
            if let message = viewModel.serverMessage {
                Section("服务器消息") { Text(message) }
            }
            ForEach(viewModel.items) { item in
                NavigationLink {
                    ChannelDetailView(item: item, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(Font.headline)
                        Text("\(item.type.map { ChannelType.name(for: $0) } ?? "-") · \(item.group ?? "-") · \(item.status == 1 ? "启用" : "禁用")")
                            .font(Font.caption)
                            .foregroundColor(Color.secondary)
                        Text("优先级 \(item.priority.map { String($0) } ?? "0") · 权重 \(item.weight.map { String($0) } ?? "1")")
                            .font(Font.caption)
                            .foregroundColor(Color.secondary)
                    }
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
        .searchable(text: $holder.searchText, prompt: "搜索渠道")
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
            if viewModel.isLoading { LoadingStateView(title: "加载渠道") }
            else if viewModel.items.isEmpty { EmptyStateView(title: "没有渠道", message: "创建渠道或调整搜索条件。") }
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
            ChannelFormView(viewModel: viewModel, editingChannel: nil)
        }
    }
}

private struct ChannelDetailView: View {
    let item: Channel
    @ObservedObject var viewModel: ChannelsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detail: Channel?
    @State private var showingEdit = false
    @State private var confirmingDelete = false
    @State private var isTesting = false
    @State private var isUpdatingBalance = false
    @State private var actionResult: String?
    @State private var actionIsError = false

    private var displayed: Channel { detail ?? item }
    private var title: String { displayed.name }
    private var groupText: String { displayed.group ?? "-" }
    private var balanceText: String { displayed.balance.map { String($0) } ?? "-" }

    var body: some View {
        content
        .navigationTitle(title)
        .task { detail = await viewModel.detail(id: item.id) }
        .onChange(of: viewModel.items) { _ in
            if !viewModel.items.contains(where: { $0.id == item.id }) {
                dismiss()
            }
        }
        .confirmationDialog("确认删除渠道？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: ButtonRole.destructive) { Task { await viewModel.delete(displayed) } }
        }
        .navigationDestination(isPresented: $showingEdit) {
            ChannelFormView(viewModel: viewModel, editingChannel: displayed)
        }
    }

    private var content: some View {
        List {
            basicInfoSection
            if let result = actionResult {
                Section {
                    Text(result)
                        .foregroundColor(actionIsError ? Color.red : Color.green)
                }
            }
            actionSection
        }
    }

    private var basicInfoSection: some View {
        Section("基本信息") {
            LabeledContent("名称", value: title)
            LabeledContent("类型", value: displayed.type.map { ChannelType.name(for: $0) } ?? "-")
            LabeledContent("分组", value: groupText)
            LabeledContent("状态", value: displayed.status == 1 ? "启用" : "禁用")
            LabeledContent("余额", value: balanceText)
            LabeledContent("优先级", value: displayed.priority.map { String($0) } ?? "0")
            LabeledContent("权重", value: displayed.weight.map { String($0) } ?? "1")
        }
    }

    private var actionSection: some View {
        Section("操作") {
            Button("编辑渠道") { showingEdit = true }
            Button {
                Task { await testChannel() }
            } label: {
                HStack {
                    Text("测试渠道")
                    Spacer()
                    if isTesting { ProgressView() }
                }
            }
            .disabled(isTesting || isUpdatingBalance)
            Button {
                Task { await updateBalance() }
            } label: {
                HStack {
                    Text("更新余额")
                    Spacer()
                    if isUpdatingBalance { ProgressView() }
                }
            }
            .disabled(isTesting || isUpdatingBalance)
            Button("删除", role: ButtonRole.destructive) { confirmingDelete = true }
        }
    }

    private func testChannel() async {
        isTesting = true
        actionResult = nil
        defer { isTesting = false }
        await viewModel.test(item)
        if let error = viewModel.errorMessage {
            actionResult = error
            actionIsError = true
            viewModel.errorMessage = nil
        } else {
            actionResult = viewModel.serverMessage ?? "测试成功"
            actionIsError = false
            viewModel.serverMessage = nil
        }
    }

    private func updateBalance() async {
        isUpdatingBalance = true
        actionResult = nil
        defer { isUpdatingBalance = false }
        await viewModel.updateBalance(item)
        if let error = viewModel.errorMessage {
            actionResult = error
            actionIsError = true
            viewModel.errorMessage = nil
        } else {
            actionResult = viewModel.serverMessage ?? "余额已更新"
            actionIsError = false
            viewModel.serverMessage = nil
        }
    }
}
