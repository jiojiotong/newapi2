import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var confirmingClearData = false
    @State private var confirmingLogout = false
    @State private var savedServers: [SavedServer] = []

    private var roleText: String {
        guard let role = sessionStore.adminUser?.role else { return "-" }
        switch role {
        case 100: return "Root"
        case 10: return "管理员"
        default: return "普通用户"
        }
    }

    private var currentServerURL: String {
        sessionStore.profile?.baseURL.absoluteString ?? "-"
    }

    var body: some View {
        List {
            Section("当前服务器") {
                LabeledContent("地址", value: currentServerURL)
                LabeledContent("账号", value: sessionStore.adminUser?.username ?? "-")
                if sessionStore.adminUser?.isAdmin == true {
                    LabeledContent("角色", value: roleText)
                }
            }

            if savedServers.count > 1 {
                Section("切换服务器") {
                    ForEach(savedServers) { server in
                        Button {
                            switchToServer(server)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.name)
                                        .font(Font.subheadline)
                                        .foregroundColor(Color.primary)
                                    Text("\(server.username)@\(server.url)")
                                        .font(Font.caption)
                                        .foregroundColor(Color.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if server.url == currentServerURL && server.username == sessionStore.adminUser?.username {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        let toDelete = indexSet.map { savedServers[$0] }
                        for server in toDelete {
                            ProfileStorage().removeSavedServer(server)
                        }
                        savedServers = ProfileStorage().loadSavedServers()
                    }
                }
            }

            Section("账号管理") {
                NavigationLink {
                    ProfileEditView()
                } label: {
                    Label("修改个人信息", systemImage: "person.circle")
                }
                NavigationLink {
                    TopUpView()
                } label: {
                    Label("充值", systemImage: "creditcard")
                }
                NavigationLink {
                    RedeemView()
                } label: {
                    Label("兑换码入口", systemImage: "ticket")
                }
                NavigationLink {
                    CheckinView()
                } label: {
                    Label("每日签到", systemImage: "calendar.badge.checkmark")
                }
            }

            Section("操作") {
                Button {
                    Task { await sessionStore.revalidateSession() }
                } label: {
                    Label("重新验证会话", systemImage: "arrow.clockwise")
                }

                NavigationLink {
                    AddServerView(onAdded: { savedServers = ProfileStorage().loadSavedServers() })
                } label: {
                    Label("添加其他服务器", systemImage: "plus.circle")
                }

                Button(role: ButtonRole.destructive) {
                    confirmingLogout = true
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: ButtonRole.destructive) {
                    confirmingClearData = true
                } label: {
                    Label("清理本地数据", systemImage: "trash")
                }
            }

            if let error = sessionStore.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }
        }
        .navigationTitle("设置")
        .onAppear { savedServers = ProfileStorage().loadSavedServers() }
        .confirmationDialog("确认退出登录？", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                Task { await sessionStore.logout() }
            }
        }
        .confirmationDialog("确认清理所有本地数据？这将清除保存的密码和所有服务器记录。", isPresented: $confirmingClearData, titleVisibility: .visible) {
            Button("清理", role: .destructive) {
                sessionStore.clearLocalData()
                savedServers = []
            }
        }
        .adminListChrome()
    }

    private func switchToServer(_ server: SavedServer) {
        Task {
            await sessionStore.logout()
            sessionStore.lastServerURL = server.url
        }
    }
}

// MARK: - Add Server View

private struct AddServerView: View {
    let onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""

    var body: some View {
        Form {
            Section(header: Text("添加服务器"), footer: Text("添加后可在设置中快速切换。登录时会自动保存当前服务器。")) {
                TextField("名称（如：主站）", text: $name)
                    .adminPlainTextInput()
                TextField("服务器地址", text: $url)
                    .adminURLKeyboard()
            }

            Section {
                Button("添加") {
                    let server = SavedServer(name: name.isEmpty ? url : name, url: url, username: "")
                    ProfileStorage().addToSavedServers(server)
                    onAdded()
                    dismiss()
                }
                .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("添加服务器")
        .adminFormChrome()
    }
}
