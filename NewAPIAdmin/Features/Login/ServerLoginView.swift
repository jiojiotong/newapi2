import SwiftUI

struct ServerLoginView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var rememberPassword = false
    @State private var turnstileToken = ""
    @State private var hasCheckedStatus = false
    @State private var savedServers: [SavedServer] = []

    var body: some View {
        NavigationStack {
            Form {
                if !savedServers.isEmpty {
                    Section("已保存的服务器") {
                        ForEach(savedServers) { server in
                            Button {
                                serverURL = server.url
                                username = server.username
                                if let remembered = sessionStore.rememberedPassword(serverURL: server.url, username: server.username) {
                                    password = remembered
                                    rememberPassword = true
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(server.name)
                                            .font(Font.subheadline)
                                            .foregroundColor(Color.primary)
                                        if !server.username.isEmpty {
                                            Text("\(server.username)@\(server.url)")
                                                .font(Font.caption)
                                                .foregroundColor(Color.secondary)
                                                .lineLimit(1)
                                        } else {
                                            Text(server.url)
                                                .font(Font.caption)
                                                .foregroundColor(Color.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if serverURL == server.url {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    TextField("服务器地址", text: $serverURL)
                        .adminURLKeyboard()

                    TextField("用户名", text: Binding(get: {
                        username
                    }, set: { newValue in
                        username = newValue
                        if let remembered = sessionStore.rememberedPassword(serverURL: serverURL, username: newValue) {
                            password = remembered
                            rememberPassword = true
                        }
                    }))
                        .adminPlainTextInput()

                    SecureField("密码", text: $password)

                    Toggle("记住密码", isOn: $rememberPassword)
                } header: {
                    Text("连接 NewAPI")
                } footer: {
                    Text("管理员可管理渠道、用户和定价。普通用户可使用对话和管理令牌。")
                }

                // Turnstile verification section
                if sessionStore.turnstileRequired && !sessionStore.turnstileSiteKey.isEmpty {
                    Section(header: Text("安全验证"), footer: Text("请完成人机验证后登录")) {
                        if turnstileToken.isEmpty {
                            TurnstileView(siteKey: sessionStore.turnstileSiteKey) { token in
                                turnstileToken = token
                            }
                            .frame(height: 80)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.green)
                                Text("验证已通过")
                            }
                        }
                    }
                }

                if let errorMessage = sessionStore.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(Color.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await sessionStore.login(serverURL: serverURL, username: username, password: password, rememberPassword: rememberPassword, turnstileToken: turnstileToken.isEmpty ? nil : turnstileToken)
                        }
                    } label: {
                        if sessionStore.isLoading {
                            ProgressView()
                        } else {
                            Text("登录")
                                .frame(maxWidth: CGFloat.infinity)
                        }
                    }
                    .disabled(sessionStore.isLoading || serverURL.isEmpty || username.isEmpty || password.isEmpty || (sessionStore.turnstileRequired && turnstileToken.isEmpty))
                }
            }
            .navigationTitle("NewAPI")
            .onAppear {
                savedServers = ProfileStorage().loadSavedServers()
                if serverURL.isEmpty {
                    serverURL = sessionStore.lastServerURL
                }
            }
            .task {
                if !serverURL.isEmpty && !hasCheckedStatus {
                    await sessionStore.checkServerStatus(serverURL: serverURL)
                    hasCheckedStatus = true
                }
            }
            .onChange(of: serverURL) { newValue in
                hasCheckedStatus = false
                turnstileToken = ""
                if !newValue.isEmpty {
                    Task {
                        await sessionStore.checkServerStatus(serverURL: newValue)
                        hasCheckedStatus = true
                    }
                }
            }
        }
    }
}
