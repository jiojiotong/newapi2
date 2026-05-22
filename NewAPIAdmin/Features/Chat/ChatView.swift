import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingKeyPicker = false
    @State private var showingModelPicker = false
    @State private var showingImageMode = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: key + model selection
            HStack {
                Button {
                    showingKeyPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "key")
                        Text(viewModel.selectedKeyName.isEmpty ? "选择令牌" : viewModel.selectedKeyName)
                            .lineLimit(1)
                    }
                    .font(Font.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)
                }

                Button {
                    showingModelPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(viewModel.selectedModel.isEmpty ? "选择模型" : viewModel.selectedModel)
                            .lineLimit(1)
                    }
                    .font(Font.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)
                }

                Spacer()

                Menu {
                    Button("对话模式") { showingImageMode = false }
                    Button("画图模式") { showingImageMode = true }
                } label: {
                    Image(systemName: showingImageMode ? "photo" : "bubble.left.and.bubble.right")
                        .padding(6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: 8) {
                TextField(showingImageMode ? "描述你想生成的图片..." : "输入消息...", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await send() }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                            .frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(Font.title2)
                    }
                }
                .disabled(viewModel.inputText.isEmpty || viewModel.isSending || viewModel.selectedKey.isEmpty)
            }
            .padding()
        }
        .navigationTitle(showingImageMode ? "画图" : "对话")
        .toolbar {
            Button("清空") { viewModel.clearMessages() }
        }
        .task {
            if let baseURL = sessionStore.profile?.baseURL {
                viewModel.baseURL = baseURL
            }
            let client = try? sessionStore.activeClient()
            viewModel.setSessionClient(client)
            await viewModel.loadTokens(client: client)
        }
        .sheet(isPresented: $showingKeyPicker) {
            KeyPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingModelPicker) {
            ModelPickerView(viewModel: viewModel)
        }
    }

    private func send() async {
        if showingImageMode {
            await viewModel.generateImage()
        } else {
            await viewModel.sendMessage()
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: DisplayMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if let imageURL = message.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: 250, maxHeight: 250)
                    .cornerRadius(12)
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(10)
                        .background(message.isUser ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(message.isUser ? Color.white : Color.primary)
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Key Picker

private struct KeyPickerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.availableTokens.isEmpty {
                    Text("没有可用的令牌，请先创建令牌")
                        .foregroundColor(Color.secondary)
                }
                ForEach(viewModel.availableTokens) { token in
                    Button {
                        Task {
                            await viewModel.selectToken(token)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(token.name).font(Font.headline)
                                Text("sk-\(token.key)").font(Font.caption).foregroundColor(Color.secondary).lineLimit(1)
                            }
                            Spacer()
                            if viewModel.selectedKeyName == token.name {
                                Image(systemName: "checkmark").foregroundColor(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择令牌")
            .toolbar {
                Button("关闭") { dismiss() }
            }
        }
    }
}

// MARK: - Model Picker

private struct ModelPickerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredModels: [String] {
        if searchText.isEmpty { return viewModel.availableModels }
        return viewModel.availableModels.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredModels, id: \.self) { model in
                    Button {
                        viewModel.selectedModel = model
                        dismiss()
                    } label: {
                        HStack {
                            Text(model)
                            Spacer()
                            if viewModel.selectedModel == model {
                                Image(systemName: "checkmark").foregroundColor(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索模型")
            .navigationTitle("选择模型")
            .toolbar {
                Button("关闭") { dismiss() }
            }
        }
    }
}

// MARK: - ViewModel

struct DisplayMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let imageURL: String?
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [DisplayMessage] = []
    @Published var inputText = ""
    @Published var isSending = false
    @Published var selectedModel = ""
    @Published var selectedKey = ""
    @Published var selectedKeyName = ""
    @Published var availableTokens: [APIToken] = []
    @Published var availableModels: [String] = []
    var baseURL: URL?

    private var chatService: ChatService?
    private var chatHistory: [ChatMessage] = []

    func loadTokens(client: NewAPIClient?) async {
        guard let client else { return }
        let service = TokenService(client: client)
        do {
            let response = try await service.list(page: 1, pageSize: 100)
            availableTokens = response.items.filter { $0.status == 1 }
        } catch {}
    }

    func selectToken(_ token: APIToken) async {
        selectedKeyName = token.name
        guard let baseURL else { return }
        guard let client = sessionClient else {
            messages.append(DisplayMessage(content: "会话已失效，请重新登录", isUser: false, imageURL: nil))
            return
        }

        // Get full key from server (list returns masked keys)
        let service = TokenService(client: client)
        do {
            let fullKey = try await service.getFullKey(id: token.id)
            selectedKey = "sk-\(fullKey)"
            chatService = ChatService(baseURL: baseURL, apiKey: selectedKey)
            availableModels = try await chatService?.fetchModels() ?? []
        } catch {
            messages.append(DisplayMessage(content: "获取令牌失败：\(error.localizedDescription)", isUser: false, imageURL: nil))
        }
    }

    private var sessionClient: NewAPIClient?

    func setSessionClient(_ client: NewAPIClient?) {
        sessionClient = client
    }

    func sendMessage() async {
        guard let service = chatService, !inputText.isEmpty else { return }
        let userText = inputText
        inputText = ""
        messages.append(DisplayMessage(content: userText, isUser: true, imageURL: nil))
        chatHistory.append(ChatMessage(role: "user", content: userText))

        isSending = true
        defer { isSending = false }

        do {
            let reply = try await service.sendMessage(model: selectedModel, messages: chatHistory)
            chatHistory.append(ChatMessage(role: "assistant", content: reply))
            messages.append(DisplayMessage(content: reply, isUser: false, imageURL: nil))
        } catch {
            messages.append(DisplayMessage(content: "错误：\(error.localizedDescription)", isUser: false, imageURL: nil))
        }
    }

    func generateImage() async {
        guard let service = chatService, !inputText.isEmpty else { return }
        let prompt = inputText
        inputText = ""
        messages.append(DisplayMessage(content: prompt, isUser: true, imageURL: nil))

        isSending = true
        defer { isSending = false }

        do {
            let url = try await service.generateImage(model: selectedModel, prompt: prompt, size: "1024x1024")
            if url.hasPrefix("http") {
                messages.append(DisplayMessage(content: "", isUser: false, imageURL: url))
            } else {
                messages.append(DisplayMessage(content: url, isUser: false, imageURL: nil))
            }
        } catch {
            messages.append(DisplayMessage(content: "错误：\(error.localizedDescription)", isUser: false, imageURL: nil))
        }
    }

    func clearMessages() {
        messages = []
        chatHistory = []
    }
}
