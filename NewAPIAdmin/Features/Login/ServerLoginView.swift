import SwiftUI

struct ServerLoginView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var rememberPassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("服务器地址", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    TextField("管理员用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("密码", text: $password)

                    Toggle("记住密码", isOn: $rememberPassword)
                } header: {
                    Text("连接 NewAPI")
                } footer: {
                    Text("普通用户无法登录。请使用管理员或 Root 账号。")
                }

                if let errorMessage = sessionStore.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await sessionStore.login(serverURL: serverURL, username: username, password: password, rememberPassword: rememberPassword)
                        }
                    } label: {
                        if sessionStore.isLoading {
                            ProgressView()
                        } else {
                            Text("登录")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(sessionStore.isLoading || serverURL.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("NewAPI 管理")
            .onAppear {
                if serverURL.isEmpty {
                    serverURL = sessionStore.lastServerURL
                }
            }
            .onChange(of: username) { newValue in
                if let remembered = sessionStore.rememberedPassword(serverURL: serverURL, username: newValue) {
                    password = remembered
                    rememberPassword = true
                }
            }
        }
    }
}
