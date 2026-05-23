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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard

                    if !savedServers.isEmpty {
                        savedServersCard
                    }

                    credentialsCard

                    if sessionStore.turnstileRequired && !sessionStore.turnstileSiteKey.isEmpty {
                        turnstileCard
                    }

                    if let errorMessage = sessionStore.errorMessage {
                        AdminSurfaceCard {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(errorMessage)
                                    .foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Button {
                        Task {
                            await sessionStore.login(
                                serverURL: serverURL,
                                username: username,
                                password: password,
                                rememberPassword: rememberPassword,
                                turnstileToken: turnstileToken.isEmpty ? nil : turnstileToken
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if sessionStore.isLoading {
                                ProgressView()
                            } else {
                                Text("登录")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(canLogin ? Color.accentColor : Color.accentColor.opacity(0.45))
                    )
                    .disabled(!canLogin)
                }
                .padding()
            }
            .adminScreenBackground()
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

    private var canLogin: Bool {
        !sessionStore.isLoading
        && !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.isEmpty
        && (!sessionStore.turnstileRequired || !turnstileToken.isEmpty)
    }

    private var headerCard: some View {
        AdminSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                        Image(systemName: "server.rack")
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("NewAPI")
                            .font(.title2.weight(.semibold))
                        Text("连接服务器后进入管理控制台")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Text("管理员可管理渠道、用户、定价和日志。登录后会自动恢复上次会话。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var savedServersCard: some View {
        AdminSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("已保存的服务器")
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(savedServers) { server in
                        Button {
                            serverURL = server.url
                            username = server.username
                            if let remembered = sessionStore.rememberedPassword(serverURL: server.url, username: server.username) {
                                password = remembered
                                rememberPassword = true
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "server.rack")
                                    .foregroundColor(serverURL == server.url ? .accentColor : .secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(server.name)
                                        .foregroundColor(.primary)
                                    Text(server.username.isEmpty ? server.url : "\(server.username)@\(server.url)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if serverURL == server.url {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(serverURL == server.url ? Color.accentColor.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var credentialsCard: some View {
        AdminSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("连接 NewAPI")
                    .font(.headline)

                fieldGroup(title: "服务器地址") {
                    TextField("https://example.com", text: $serverURL)
                        .adminURLKeyboard()
                        .adminEditableField()
                }

                fieldGroup(title: "用户名") {
                    TextField("请输入用户名", text: Binding(get: {
                        username
                    }, set: { newValue in
                        username = newValue
                        if let remembered = sessionStore.rememberedPassword(serverURL: serverURL, username: newValue) {
                            password = remembered
                            rememberPassword = true
                        }
                    }))
                        .adminPlainTextInput()
                        .adminEditableField()
                }

                fieldGroup(title: "密码") {
                    SecureField("请输入密码", text: $password)
                        .adminEditableField()
                }

                Toggle("记住密码", isOn: $rememberPassword)
                    .tint(.accentColor)

                Text("普通用户不能登录。管理员可以管理渠道、用户、定价和日志。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var turnstileCard: some View {
        AdminSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("安全验证")
                    .font(.headline)
                Text("请完成人机验证后登录")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if turnstileToken.isEmpty {
                    TurnstileView(siteKey: sessionStore.turnstileSiteKey) { token in
                        turnstileToken = token
                    }
                    .frame(height: 80)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("验证已通过")
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
    }
}
