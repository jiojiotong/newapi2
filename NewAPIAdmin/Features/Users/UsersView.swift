import SwiftUI

struct UsersView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()
    @State private var showingCreate = false

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
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
                                Text("额度 \(item.quota.map(String.init) ?? "-") · 状态 \(item.status.map(String.init) ?? "-") · 角色 \(item.role.map(String.init) ?? "-")")
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
                .overlay {
                    if viewModel.isLoading { LoadingStateView(title: "加载用户") }
                    else if viewModel.items.isEmpty { EmptyStateView(title: "没有用户", message: "创建用户或调整搜索条件。") }
                }
                .toolbar {
                    Button("新增") { showingCreate = true }
                    Button("刷新") { Task { await viewModel.load() } }
                }
                .navigationDestination(isPresented: $showingCreate) {
                    DynamicObjectFormView(title: "新增用户", initialValues: ["username": .string(""), "password": .string(""), "group": .string("default")]) { payload in
                        await viewModel.create(payload)
                    }
                }
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

    @MainActor private final class Holder: ObservableObject {
        @Published var viewModel: UsersViewModel?
        @Published var searchText = ""
    }
}

private struct UserDetailView: View {
    let item: ManagedUser
    @ObservedObject var viewModel: UsersViewModel
    @State private var detail: ManagedUser?
    @State private var showingEdit = false
    @State private var confirmingDelete = false
    @State private var confirmingDisable = false
    @State private var confirmingEnable = false
    @State private var confirmingRoleChange = false

    private var displayed: ManagedUser { detail ?? item }

    var body: some View {
        List {
            Section("基本信息") {
                LabeledContent("用户名", value: displayed.username)
                LabeledContent("显示名", value: displayed.displayName ?? "-")
                LabeledContent("分组", value: displayed.group ?? "-")
                LabeledContent("额度", value: displayed.quota.map(String.init) ?? "-")
                LabeledContent("角色", value: displayed.role.map(String.init) ?? "-")
            }
            Section("操作") {
                Button("编辑 JSON") { showingEdit = true }
                Button("启用用户") { confirmingEnable = true }
                Button("禁用用户") { confirmingDisable = true }
                Button("切换管理员角色") { confirmingRoleChange = true }
                Button("删除", role: ButtonRole.destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(displayed.username)
        .task { detail = await viewModel.detail(id: item.id) }
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
            }
        }
    }
}
