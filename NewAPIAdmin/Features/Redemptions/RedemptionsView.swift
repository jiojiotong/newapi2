import SwiftUI

struct RedemptionsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                RedemptionsContentView(viewModel: viewModel, holder: holder)
            } else {
                LoadingStateView(title: "准备兑换码管理")
            }
        }
        .navigationTitle("兑换码")
        .task { setupAndLoad() }
    }

    private func setupAndLoad() {
        guard holder.viewModel == nil, let client = try? sessionStore.activeClient() else { return }
        let viewModel = RedemptionsViewModel(service: RedemptionService(client: client))
        holder.viewModel = viewModel
        Task { await viewModel.load() }
    }

    @MainActor final class Holder: ObservableObject {
        @Published var viewModel: RedemptionsViewModel?
        @Published var searchText = ""
    }
}

private struct RedemptionsContentView: View {
    @ObservedObject var viewModel: RedemptionsViewModel
    @ObservedObject var holder: RedemptionsView.Holder
    @State private var showingCreate = false
    @State private var confirmingClearInvalid = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage { Section { Text(error).foregroundColor(Color.red) } }
            ForEach(viewModel.items) { item in
                NavigationLink {
                    RedemptionDetailView(item: item, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.key.isEmpty ? (item.name ?? "兑换码") : item.key).font(Font.headline)
                        Text("额度 \(item.quota.map { String($0) } ?? "-") · 数量 \(item.count.map { String($0) } ?? "-") · 已用 \(item.usedCount.map { String($0) } ?? "-")")
                            .font(Font.caption).foregroundColor(Color.secondary)
                        Text("状态 \(item.status.map { String($0) } ?? "-") · 过期 \(formatExpiry(item.expiredTime))")
                            .font(Font.caption).foregroundColor(Color.secondary)
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
        .searchable(text: $holder.searchText, prompt: "搜索兑换码")
        .onSubmit(of: .search) {
            viewModel.searchText = holder.searchText
            Task { await viewModel.search() }
        }
        .overlay {
            if viewModel.isLoading { LoadingStateView(title: "加载兑换码") }
            else if viewModel.items.isEmpty { EmptyStateView(title: "没有兑换码", message: "创建兑换码或调整搜索条件。") }
        }
        .toolbar {
            Button("新增") { showingCreate = true }
            Button("清理失效") { confirmingClearInvalid = true }
            Button("刷新") { Task { await viewModel.load() } }
        }
        .navigationDestination(isPresented: $showingCreate) {
            RedemptionCreateView(viewModel: viewModel)
        }
        .confirmationDialog("确认清理失效兑换码？", isPresented: $confirmingClearInvalid, titleVisibility: .visible) {
            Button("清理", role: ButtonRole.destructive) { Task { await viewModel.clearInvalid() } }
        }
    }

    private func formatExpiry(_ timestamp: Int?) -> String {
        guard let ts = timestamp, ts > 0 else { return "永不" }
        let date = Date(timeIntervalSince1970: Double(ts))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

private struct RedemptionDetailView: View {
    let item: RedemptionCode
    @ObservedObject var viewModel: RedemptionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detail: RedemptionCode?
    @State private var showingEdit = false
    @State private var confirmingDelete = false

    private var displayed: RedemptionCode { detail ?? item }
    private var title: String { displayed.key.isEmpty ? "兑换码" : displayed.key }
    private var nameText: String { displayed.name ?? "-" }
    private var quotaText: String { displayed.quota.map { String($0) } ?? "-" }
    private var countText: String { displayed.count.map { String($0) } ?? "-" }

    var body: some View {
        content
        .navigationTitle(title)
        .task { detail = await viewModel.detail(id: item.id) }
        .onChange(of: viewModel.items) { _ in
            if !viewModel.items.contains(where: { $0.id == item.id }) {
                dismiss()
            }
        }
        .confirmationDialog("确认删除兑换码？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: ButtonRole.destructive) { Task { await viewModel.delete(displayed) } }
        }
        .navigationDestination(isPresented: $showingEdit) {
            DynamicObjectFormView(title: "编辑兑换码", initialValues: displayed.raw.values) { payload in
                await viewModel.update(payload)
            }
        }
    }

    private var content: some View {
        List {
            basicInfoSection
            actionSection
        }
    }

    private var basicInfoSection: some View {
        Section("基本信息") {
            LabeledContent("兑换码", value: title)
            LabeledContent("名称", value: nameText)
            LabeledContent("额度", value: quotaText)
            LabeledContent("数量", value: countText)
        }
    }

    private var actionSection: some View {
        Section("操作") {
            Button("编辑 JSON") { showingEdit = true }
            Button("删除", role: ButtonRole.destructive) { confirmingDelete = true }
        }
    }
}
