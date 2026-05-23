import SwiftUI

struct UserFormView: View {
    @ObservedObject var viewModel: UsersViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss

    let editingUser: ManagedUser?

    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var group = "default"
    @State private var remark = ""
    @State private var role = 1
    @State private var status = 1
    @State private var quotaAction = "add"
    @State private var quotaAmount = ""
    @State private var isSaving = false
    @State private var availableGroups: [String] = []
    @State private var successMessage: String?

    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }
            if let success = successMessage {
                Section { Text(success).foregroundColor(Color.green) }
            }

            Section("基本信息") {
                TextField("用户名", text: $username)
                    .adminPlainTextInput()
                if editingUser == nil {
                    SecureField("密码（8-20位）", text: $password)
                } else {
                    SecureField("新密码（留空不修改）", text: $password)
                }
                TextField("显示名称", text: $displayName)
                    .adminPlainTextInput()
            }

            Section("分组") {
                if availableGroups.isEmpty {
                    Text("加载分组中...")
                        .foregroundColor(Color.secondary)
                } else {
                    Picker("分组", selection: $group) {
                        ForEach(availableGroups, id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }
                }
            }

            if editingUser != nil {
                Section("角色") {
                    Picker("角色", selection: $role) {
                        Text("普通用户").tag(1)
                        Text("管理员").tag(10)
                        if sessionStore.adminUser?.isRoot == true {
                            Text("Root").tag(100)
                        }
                    }
                    if sessionStore.adminUser?.isRoot != true {
                        Text("仅 Root 可以提升用户为管理员")
                            .font(Font.caption)
                            .foregroundColor(Color.secondary)
                    }
                }

                Section("状态") {
                    Picker("状态", selection: $status) {
                        Text("启用").tag(1)
                        Text("禁用").tag(2)
                    }
                }

                Section(header: Text("额度管理"), footer: Text("当前额度：\(formatQuota(editingUser?.quota))。输入美元金额，如 1 表示 $1.00")) {
                    Picker("操作", selection: $quotaAction) {
                        Text("增加").tag("add")
                        Text("减少").tag("subtract")
                        Text("设置为").tag("override")
                    }
                    TextField("金额（美元）", text: $quotaAmount)
                        .adminDecimalKeyboard()
                        .adminEditableField()
                    Button("修改额度") {
                        Task { await updateQuota() }
                    }
                    .disabled(quotaAmount.isEmpty || isSaving)
                }
            }

            Section("备注") {
                TextField("备注（可选）", text: $remark)
                    .adminPlainTextInput()
            }

            Section {
                Button(editingUser == nil ? "创建用户" : "保存基本信息") {
                    Task { await save() }
                }
                .disabled(isSaving || username.isEmpty || (editingUser == nil && password.isEmpty))
            }
        }
        .navigationTitle(editingUser == nil ? "新增用户" : "编辑用户")
        .task {
            availableGroups = await viewModel.fetchGroups()
            loadFromUser()
        }
        .adminFormChrome()
    }

    private func loadFromUser() {
        guard let user = editingUser else { return }
        username = user.username
        displayName = user.displayName ?? ""
        group = user.group ?? "default"
        role = user.role ?? 1
        status = user.status ?? 1
        if case .string(let v) = user.raw["remark"] { remark = v }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        successMessage = nil
        viewModel.errorMessage = nil

        var values: [String: AnyJSONValue] = [
            "username": .string(username),
            "display_name": .string(displayName),
            "group": .string(group),
            "remark": .string(remark)
        ]

        if !password.isEmpty {
            values["password"] = .string(password)
        }

        if let user = editingUser {
            values["id"] = .int(user.id)
            await viewModel.update(DynamicObject(values: values))
            if viewModel.errorMessage != nil { return }

            // Handle role change via manage endpoint
            if role != (user.role ?? 1) {
                if role >= 10 && (user.role ?? 1) < 10 {
                    await viewModel.manage(user, action: "promote")
                } else if role < 10 && (user.role ?? 1) >= 10 {
                    await viewModel.manage(user, action: "demote")
                }
                if viewModel.errorMessage != nil { return }
            }

            // Handle status change via manage endpoint
            if status != (user.status ?? 1) {
                if status == 1 {
                    await viewModel.manage(user, action: "enable")
                } else {
                    await viewModel.manage(user, action: "disable")
                }
                if viewModel.errorMessage != nil { return }
            }

            successMessage = "保存成功"
        } else {
            values["password"] = .string(password)
            values["role"] = .int(role)
            await viewModel.create(DynamicObject(values: values))
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }

    private func updateQuota() async {
        guard let user = editingUser, let dollars = Double(quotaAmount), dollars > 0 else {
            viewModel.errorMessage = "请输入有效的金额"
            return
        }
        let quotaValue = Int(dollars * 500000)
        isSaving = true
        defer { isSaving = false }
        successMessage = nil

        await viewModel.manageQuota(user, value: quotaValue, mode: quotaAction)
        if viewModel.errorMessage == nil {
            successMessage = "额度修改成功（\(quotaAction == "add" ? "+" : quotaAction == "subtract" ? "-" : "=") $\(String(format: "%.2f", dollars))）"
            quotaAmount = ""
        }
    }

    private func formatQuota(_ quota: Double?) -> String {
        guard let q = quota else { return "$0.00" }
        let dollars = q / 500000.0
        return String(format: "$%.2f", dollars)
    }
}
