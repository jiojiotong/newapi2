import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var confirmingClearData = false
    @State private var confirmingLogout = false

    var body: some View {
        List {
            Section("当前服务器") {
                LabeledContent("地址", value: sessionStore.profile?.baseURL.absoluteString ?? "-")
                LabeledContent("账号", value: sessionStore.adminUser?.username ?? "-")
            }

            Section {
                Button("重新验证会话") {
                    Task { await sessionStore.revalidateSession() }
                }

                Button(role: ButtonRole.destructive) {
                    confirmingLogout = true
                } label: {
                    Text("退出登录")
                }

                Button(role: ButtonRole.destructive) {
                    confirmingClearData = true
                } label: {
                    Text("清理本地数据")
                }
            }

            if let error = sessionStore.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }
        }
        .navigationTitle("设置")
        .confirmationDialog("确认退出登录？", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                Task { await sessionStore.logout() }
            }
        }
        .confirmationDialog("确认清理所有本地数据？这将清除保存的密码和会话信息。", isPresented: $confirmingClearData, titleVisibility: .visible) {
            Button("清理", role: .destructive) {
                sessionStore.clearLocalData()
            }
        }
    }
}
