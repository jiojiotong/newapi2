import SwiftUI

struct ChannelsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()
    @State private var showingCreate = false

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                List {
                    if let error = viewModel.errorMessage {
                        Section { Text(error).foregroundColor(Color.red) }
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
                                Text("类型 \(item.type.map(String.init) ?? "-") · 分组 \(item.group ?? "-") · 状态 \(item.status.map(String.init) ?? "-")")
                                    .font(Font.caption)
                                    .foregroundColor(Color.secondary)
                                Text("余额 \(item.balance.map(String.init) ?? "-") · 响应 \(item.responseTime.map(String.init) ?? "-") · 优先级 \(item.priority.map(String.init) ?? "-") · 权重 \(item.weight.map(String.init) ?? "-")")
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
                .overlay {
                    if viewModel.isLoading { LoadingStateView(title: "加载渠道") }
                    else if viewModel.items.isEmpty { EmptyStateView(title: "没有渠道", message: "创建渠道或调整搜索条件。") }
                }
                .toolbar {
                    Button("新增") { showingCreate = true }
                    Button("刷新") { Task { await viewModel.load() } }
                }
                .navigationDestination(isPresented: $showingCreate) {
                    DynamicObjectFormView(title: "新增渠道", initialValues: ["name": .string("")]) { payload in
                        await viewModel.create(payload)
                    }
                }
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

    @MainActor private final class Holder: ObservableObject {
        @Published var viewModel: ChannelsViewModel?
        @Published var searchText = ""
    }
}

private struct ChannelDetailView: View {
    let item: Channel
    @ObservedObject var viewModel: ChannelsViewModel
    @State private var detail: Channel?
    @State private var showingEdit = false
    @State private var confirmingDelete = false

    private var displayed: Channel { detail ?? item }

    var body: some View {
        List {
            Section("基本信息") {
                LabeledContent("名称", value: displayed.name)
                LabeledContent("分组", value: displayed.group ?? "-")
                LabeledContent("状态", value: displayed.status.map(String.init) ?? "-")
                LabeledContent("余额", value: displayed.balance.map(String.init) ?? "-")
            }
            Section("操作") {
                Button("编辑 JSON") { showingEdit = true }
                Button("测试渠道") { Task { await viewModel.test(item) } }
                Button("更新余额") { Task { await viewModel.updateBalance(item) } }
                Button("删除", role: ButtonRole.destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(displayed.name)
        .task { detail = await viewModel.detail(id: item.id) }
        .confirmationDialog("确认删除渠道？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: ButtonRole.destructive) { Task { await viewModel.delete(displayed) } }
        }
        .navigationDestination(isPresented: $showingEdit) {
            DynamicObjectFormView(title: "编辑渠道", initialValues: displayed.raw.values) { payload in
                await viewModel.update(payload)
            }
        }
    }
}
