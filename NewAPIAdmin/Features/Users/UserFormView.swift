import SwiftUI

struct UserFormView: View {
    @ObservedObject var viewModel: UsersViewModel
    @Environment(\.dismiss) private var dismiss

    let editingUser: ManagedUser?

    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var group = "default"
    @State private var remark = ""
    @State private var isSaving = false
    @State private var availableGroups: [String] = []

    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }

            Section("基本信息") {
                if editingUser == nil {
                    TextField("用户名", text: $username)
                        .adminPlainTextInput()
                } else {
                    TextField("用户名", text: $username)
                        .adminPlainTextInput()
                }
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

            Section("备注") {
                TextField("备注（可选）", text: $remark)
                    .adminPlainTextInput()
            }

            if let user = editingUser {
                Section("信息") {
                    LabeledContent("角色", value: roleName(user.role))
                    LabeledContent("状态", value: statusName(user.status))
                    LabeledContent("额度", value: user.quota.map { String(Int($0)) } ?? "-")
                }
            }

            Section {
                Button(editingUser == nil ? "创建用户" : "保存修改") {
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
    }

    private func loadFromUser() {
        guard let user = editingUser else { return }
        username = user.username
        displayName = user.displayName ?? ""
        group = user.group ?? "default"
        if case .string(let v) = user.raw["remark"] { remark = v }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

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
        } else {
            // Create requires password and role
            values["password"] = .string(password)
            values["role"] = .int(1) // default common user
            await viewModel.create(DynamicObject(values: values))
        }

        if viewModel.errorMessage == nil {
            dismiss()
        }
    }

    private func roleName(_ role: Int?) -> String {
        switch role {
        case 100: return "Root"
        case 10: return "管理员"
        case 1: return "普通用户"
        case 0: return "访客"
        default: return role.map { String($0) } ?? "-"
        }
    }

    private func statusName(_ status: Int?) -> String {
        switch status {
        case 1: return "启用"
        case 2: return "禁用"
        default: return status.map { String($0) } ?? "-"
        }
    }
}
