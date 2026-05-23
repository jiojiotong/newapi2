import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var username = ""
    @State private var displayName = ""
    @State private var originalPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var resultMessage: String?
    @State private var isError = false

    var body: some View {
        Form {
            if let result = resultMessage {
                Section {
                    Text(result)
                        .foregroundColor(isError ? Color.red : Color.green)
                }
            }

            Section(header: Text("基本信息"), footer: Text("用户名修改后需要重新登录")) {
                HStack {
                    Text("用户名")
                    Spacer()
                    TextField("用户名", text: $username)
                        .adminPlainTextInput()
                        .multilineTextAlignment(.trailing)
                        .adminEditableField()
                }
                HStack {
                    Text("显示名称")
                    Spacer()
                    TextField("显示名称", text: $displayName)
                        .adminPlainTextInput()
                        .multilineTextAlignment(.trailing)
                        .adminEditableField()
                }
            }

            Section {
                Button("保存基本信息") {
                    Task { await saveProfile() }
                }
                .disabled(isSaving || username.isEmpty)
            }

            Section(header: Text("修改密码"), footer: Text("留空则不修改密码")) {
                SecureField("当前密码", text: $originalPassword)
                SecureField("新密码（8-20位）", text: $newPassword)
                SecureField("确认新密码", text: $confirmPassword)
            }

            Section {
                Button("修改密码") {
                    Task { await changePassword() }
                }
                .disabled(isSaving || originalPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
            }
        }
        .navigationTitle("修改个人信息")
        .onAppear { loadCurrentInfo() }
        .adminFormChrome()
    }

    private func loadCurrentInfo() {
        username = sessionStore.adminUser?.username ?? ""
        displayName = sessionStore.adminUser?.displayName ?? ""
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        resultMessage = nil

        guard let client = try? sessionStore.activeClient() else {
            resultMessage = "未登录"
            isError = true
            return
        }

        var payload: [String: AnyJSONValue] = [
            "username": .string(username),
            "display_name": .string(displayName)
        ]
        // Need to send password field as empty placeholder
        payload["password"] = .string("")

        do {
            let _: EmptyResponseData = try await client.put("/api/user/self", body: DynamicObject(values: payload))
            resultMessage = "保存成功"
            isError = false
        } catch let error as NewAPIError {
            resultMessage = error.localizedDescription
            isError = true
        } catch {
            resultMessage = error.localizedDescription
            isError = true
        }
    }

    private func changePassword() async {
        guard newPassword == confirmPassword else {
            resultMessage = "两次输入的新密码不一致"
            isError = true
            return
        }
        guard newPassword.count >= 8 && newPassword.count <= 20 else {
            resultMessage = "密码长度需要 8-20 位"
            isError = true
            return
        }

        isSaving = true
        defer { isSaving = false }
        resultMessage = nil

        guard let client = try? sessionStore.activeClient() else {
            resultMessage = "未登录"
            isError = true
            return
        }

        let payload: [String: AnyJSONValue] = [
            "username": .string(username),
            "display_name": .string(displayName),
            "original_password": .string(originalPassword),
            "password": .string(newPassword)
        ]

        do {
            let _: EmptyResponseData = try await client.put("/api/user/self", body: DynamicObject(values: payload))
            resultMessage = "密码修改成功"
            isError = false
            originalPassword = ""
            newPassword = ""
            confirmPassword = ""
        } catch let error as NewAPIError {
            resultMessage = error.localizedDescription
            isError = true
        } catch {
            resultMessage = error.localizedDescription
            isError = true
        }
    }
}
