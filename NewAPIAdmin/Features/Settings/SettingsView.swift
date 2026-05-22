import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore

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

                Button(role: .destructive) {
                    Task {
                        await sessionStore.logout()
                    }
                } label: {
                    Text("退出登录")
                }

                Button(role: .destructive) {
                    sessionStore.clearLocalData()
                } label: {
                    Text("清理本地数据")
                }
            }

            if let error = sessionStore.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("设置")
    }
}
