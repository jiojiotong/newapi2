import SwiftUI

struct UsersView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                UsersContentView(viewModel: viewModel, holder: holder)
            } else {
                LoadingStateView(title: "准备用户管理")
            }
        }
        .navigationTitle("用户")
        .task { setupAndLoad() }
    }

    private func setupAndLoad() {
        guard holder.viewModel == nil, let client = try? sessionStore.activeClient() else { return }
        let viewModel = UsersViewModel(service: UserService(client: client))
        holder.viewModel = viewModel
        Task { await viewModel.load() }
    }

    @MainActor final class Holder: ObservableObject {
        @Published var viewModel: UsersViewModel?
        @Published var searchText = ""
    }
}

private struct UsersContentView: View {
    @ObservedObject var viewModel: UsersViewModel
    @ObservedObject var holder: UsersView.Holder
    @State private var showingCreate = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage { Section { Text(error).foregroundColor(Color.red) } }
            ForEach(viewModel.items) { item in
                NavigationLink {
                    UserDetailView(item: item, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.username).font(Font.headline)
                        Text("显示名 \(item.displayName ?? "-") · 分组 \(item.group ?? "-")")
                            .font(Font.caption).foregroundColor(Color.secondary)
                        Text("额度 \(item.quota.map { String($0) } ?? "-") · 状态 \(item.status.map { String($0) } ?? "-") · 角色 \(item.role.map { String($0) } ?? "-")")
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
        .searchable(text: $holder.searchText, prompt: "搜索用户")
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
            if viewModel.isLoading { LoadingStateView(title: "加载用户") }
            else if viewModel.items.isEmpty { EmptyStateView(title: "没有用户", message: "创建用户或调整搜索条件。") }
        }
        .toolbar {
            Button("新增") { showingCreate = true }
                .disabled(viewModel.isLoading)
            Button("刷新") { Task { await viewModel.load() } }
                .disabled(viewModel.isLoading)
        }
        .navigationDestination(isPresented: $showingCreate) {
            DynamicObjectFormView(title: "新增用户", initialValues: ["username": .string(""), "password": .string(""), "group": .string("default")]) { payload in
                await viewModel.create(payload)
                return viewModel.errorMessage == nil
            }
        }
    }
}

private struct UserDetailView: View {
    let item: ManagedUser
    @ObservedObject var viewModel: UsersViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ManagedUser?
    @State private var showingEdit = false
    @State private var confirmingDelete = false
    @State private var confirmingDisable = false
    @State private var confirmingEnable = false
    @State private var confirmingRoleChange = false

    private var displayed: ManagedUser { detail ?? item }
    private var title: String { displayed.username }
    private var displayNameText: String { displayed.displayName ?? "-" }
    private var groupText: String { displayed.group ?? "-" }
    private var quotaText: String { displayed.quota.map { String($0) } ?? "-" }
    private var roleText: String { displayed.role.map { String($0) } ?? "-" }

    var body: some View {
        content
        .navigationTitle(title)
        .task { detail = await viewModel.detail(id: item.id) }
        .onChange(of: viewModel.items) { _ in
            if !viewModel.items.contains(where: { $0.id == item.id }) {
                dismiss()
            }
        }
        .confirmationDialog("确认启用用户？", isPresented: $confirmingEnable, titleVisibility: .visible) {
            Button("启用") { Task { await viewModel.manage(displayed, action: "enable") } }
        }
        .confirmationDialog("确认禁用用户？", isPresented: $confirmingDisable, titleVisibility: .visible) {
            Button("禁用", role: ButtonRole.destructive) { Task { await viewModel.manage(displayed, action: "disable") } }
        }
        .confirmationDialog("确认切换管理员角色？", isPresented: $confirmingRoleChange, titleVisibility: .visible) {
            Button("设为管理员") { Task { await viewModel.manage(displayed, action: "promote") } }
            Button("降为普通用户", role: ButtonRole.destructive) { Task { await viewModel.manage(displayed, action: "demote") } }
        }
        .confirmationDialog("确认删除用户？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: ButtonRole.destructive) { Task { await viewModel.delete(displayed) } }
        }
        .navigationDestination(isPresented: $showingEdit) {
            DynamicObjectFormView(title: "编辑用户", initialValues: displayed.raw.values) { payload in
                await viewModel.update(payload)
                return viewModel.errorMessage == nil
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
            LabeledContent("用户名", value: title)
            LabeledContent("显示名", value: displayNameText)
            LabeledContent("分组", value: groupText)
            LabeledContent("额度", value: quotaText)
            LabeledContent("角色", value: roleText)
        }
    }

    private var actionSection: some View {
        Section("操作") {
            Button("编辑 JSON") { showingEdit = true }
            Button("启用用户") { confirmingEnable = true }
            Button("禁用用户") { confirmingDisable = true }
            Button("切换管理员角色") { confirmingRoleChange = true }
            Button("删除", role: ButtonRole.destructive) { confirmingDelete = true }
        }
    }
}
