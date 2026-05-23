import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

struct ChatView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingKeyPicker = false
    @State private var showingModelPicker = false
    @State private var showingImageMode = false
    @State private var showingHistory = false
    @State private var showingMemory = false
    #if canImport(UIKit)
    @State private var showingAttachment = false
    @State private var showingPhotoPicker = false
    @State private var showingFileImporter = false
    #endif

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

                Toggle("", isOn: $viewModel.streamEnabled)
                    .labelsHidden()
                    .frame(width: 50)
                Text(viewModel.streamEnabled ? "流式" : "普通")
                    .font(Font.caption2)

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

            #if canImport(UIKit)
            if let img = viewModel.attachedImage {
                HStack {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                        .clipped()
                    Text("已附加图片")
                        .font(Font.caption)
                        .foregroundColor(Color.secondary)
                    Spacer()
                    Button {
                        viewModel.attachedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
            #endif

            // Input
            HStack(spacing: 8) {
                #if canImport(UIKit)
                Button {
                    showingAttachment = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(Font.title3)
                        .foregroundColor(Color.accentColor)
                }
                #endif

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
                .disabled((showingImageMode ? viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImage == nil)) || viewModel.isSending || viewModel.selectedKey.isEmpty || viewModel.selectedModel.isEmpty)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal)

            ContextUsageView(contextUsage: viewModel.contextUsage)
                .padding(.horizontal)
                .padding(.bottom, 4)
        }
        .navigationTitle(showingImageMode ? "画图" : "对话")
        .toolbar {
            Button("记忆") { showingMemory = true }
            Button("历史") { showingHistory = true }
            Button("清空") { viewModel.clearMessages() }
        }
        .task {
            if let baseURL = sessionStore.profile?.baseURL {
                viewModel.baseURL = baseURL
            }
            let client = try? sessionStore.activeClient()
            viewModel.setSessionClient(client)
            viewModel.loadHistory()
            viewModel.loadMemories()
            await viewModel.loadTokens(client: client)
        }
        .sheet(isPresented: $showingKeyPicker) {
            KeyPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingModelPicker) {
            ModelPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingHistory) {
            ChatHistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingMemory) {
            MemoryView(viewModel: viewModel)
        }
        #if canImport(UIKit)
        .confirmationDialog("添加附件", isPresented: $showingAttachment, titleVisibility: .visible) {
            Button("选择图片") { showingPhotoPicker = true }
            Button("选择文件") { showingFileImporter = true }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(image: $viewModel.attachedImage)
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importAttachment(from: url)
            case .failure(let error):
                viewModel.messages.append(DisplayMessage(content: "选择文件失败：\(error.localizedDescription)", isUser: false, imageURL: nil))
            }
        }
        #endif
    }

    private func send() async {
        if showingImageMode {
            await viewModel.generateImage()
        } else {
            await viewModel.sendMessage()
        }
    }

    #if canImport(UIKit)
    private func importAttachment(from url: URL) {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url), let image = PlatformImage(data: data) else {
            viewModel.messages.append(DisplayMessage(content: "当前仅支持可识别的图片文件", isUser: false, imageURL: nil))
            return
        }

        viewModel.attachedImage = image
    }
    #endif
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: DisplayMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 40)
            } else {
                AssistantAvatar()
                    .padding(.top, 2)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if let imageURL = message.imageURL {
                    if imageURL.hasPrefix("data:") {
                        Group {
                            if let image = localImage(from: imageURL) {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: 250, maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxWidth: 250, maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)
                        .background(message.isUser ? Color.accentColor : Color.gray.opacity(0.12))
                        .foregroundColor(message.isUser ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(message.isUser ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.06), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(message.isUser ? 0.08 : 0.04), radius: 8, x: 0, y: 2)
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("复制") { copyContent(message.content) }
                        }
                }
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }

    private func localImage(from imageURL: String) -> Image? {
        guard let base64Part = imageURL.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).last,
              let data = Data(base64Encoded: String(base64Part)) else {
            return nil
        }
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(data: data) {
            return Image(nsImage: nsImage)
        }
        #endif
        return nil
    }

    private func copyContent(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

private struct AssistantAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
            Circle()
                .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
            Image(systemName: "sparkles")
                .font(Font.system(size: 12, weight: .semibold))
                .foregroundColor(Color.accentColor)
        }
        .frame(width: 28, height: 28)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

private struct ContextUsageView: View {
    let contextUsage: ContextUsage?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "memorychip")
                .font(Font.caption2)
            if let contextUsage {
                ProgressView(value: contextUsage.progress)
                    .tint(Color.secondary)
                Text("上下文约 \(contextUsage.percentage)%")
            } else {
                Text("上下文 --")
            }
            Spacer()
        }
        .font(Font.caption2)
        .foregroundColor(Color.secondary)
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
                            if await viewModel.selectToken(token) {
                                dismiss()
                            }
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

    private var filteredModels: [ModelInfo] {
        if searchText.isEmpty { return viewModel.availableModels }
        return viewModel.availableModels.filter { $0.id.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredModels) { model in
                    Button {
                        viewModel.selectedModel = model.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(model.id)
                            Spacer()
                            if viewModel.selectedModel == model.id {
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

struct ContextUsage {
    let usedTokens: Int
    let limit: Int

    var percentage: Int {
        guard limit > 0 else { return 0 }
        return Int((Double(usedTokens) / Double(limit)) * 100.0)
    }

    var progress: Double {
        guard limit > 0 else { return 0 }
        return min(Double(usedTokens) / Double(limit), 1)
    }
}

private enum ModelContextCatalog {
    static func limit(for modelName: String) -> Int? {
        let lower = modelName.lowercased()
        if lower.contains("gpt-4.1") || lower.contains("o4") {
            return 1_000_000
        }
        if lower.contains("gpt-4o") || lower.contains("gpt-4-turbo") || lower.contains("gpt-4.5") {
            return 128_000
        }
        if lower.contains("gpt-4") {
            return 128_000
        }
        if lower.contains("claude-3") {
            return 200_000
        }
        if lower.contains("gemini-1.5") || lower.contains("gemini-2") {
            return 1_000_000
        }
        if lower.contains("deepseek") || lower.contains("qwen") || lower.contains("llama") || lower.contains("glm") {
            return 128_000
        }
        return 128_000
    }
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
    @Published var availableModels: [ModelInfo] = []
    @Published var streamEnabled = true
    @Published var memories: [MemoryItem] = []
    var baseURL: URL?

    private var chatService: ChatService?
    var chatHistory: [ChatMessage] = []
    @Published var attachedImage: PlatformImage?

    func loadTokens(client: NewAPIClient?) async {
        guard let client else { return }
        let service = TokenService(client: client)
        do {
            let response = try await service.list(page: 1, pageSize: 100)
            availableTokens = response.items.filter { $0.status == 1 }
        } catch {}
    }

    func selectToken(_ token: APIToken) async -> Bool {
        guard let baseURL else { return false }
        guard let client = sessionClient else {
            messages.append(DisplayMessage(content: "会话已失效，请重新登录", isUser: false, imageURL: nil))
            return false
        }

        // Get full key from server (list returns masked keys)
        let service = TokenService(client: client)
        do {
            let fullKey = try await service.getFullKey(id: token.id)
            selectedKey = "sk-\(fullKey)"
            chatService = ChatService(baseURL: baseURL, apiKey: selectedKey)
            availableModels = []
            selectedModel = ""
            availableModels = try await chatService?.fetchModels() ?? []
            if selectedModel.isEmpty || !availableModels.contains(where: { $0.id == selectedModel }) {
                selectedModel = availableModels.first?.id ?? ""
            }
            selectedKeyName = token.name
            return true
        } catch {
            availableModels = []
            selectedModel = ""
            selectedKey = ""
            chatService = nil
            messages.append(DisplayMessage(content: "获取令牌失败：\(error.localizedDescription)", isUser: false, imageURL: nil))
            return false
        }
    }

    private var sessionClient: NewAPIClient?

    func setSessionClient(_ client: NewAPIClient?) {
        sessionClient = client
    }

    var contextUsage: ContextUsage? {
        guard let limit = selectedModelContextLimit, limit > 0 else { return nil }
        let used = estimatedContextTokens()
        return ContextUsage(usedTokens: used, limit: limit)
    }

    private var selectedModelContextLimit: Int? {
        if let model = availableModels.first(where: { $0.id == selectedModel })?.contextWindow {
            return model
        }
        return ModelContextCatalog.limit(for: selectedModel)
    }

    private func estimatedContextTokens() -> Int {
        var total = 0
        for message in buildMessagesWithMemory() {
            total += 4 + estimatedTokenCount(for: message.content)
        }
        let draft = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.isEmpty {
            total += 4 + estimatedTokenCount(for: draft)
        }
        return total
    }

    private func estimatedTokenCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var count = 0
        var asciiRun = 0

        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }
            if scalar.value < 128 {
                asciiRun += 1
                if asciiRun == 4 {
                    count += 1
                    asciiRun = 0
                }
            } else {
                if asciiRun > 0 {
                    count += 1
                    asciiRun = 0
                }
                count += 1
            }
        }

        if asciiRun > 0 {
            count += 1
        }

        return max(count, 1)
    }

    func sendMessage() async {
        guard let service = chatService else { return }
        guard !selectedModel.isEmpty else { return }
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty || attachedImage != nil else { return }
        let imageBase64 = attachedImageBase64()
        let userDisplayText = userText.isEmpty ? (attachedImage != nil ? "已附加图片" : "") : userText
        let historyText = userText
        inputText = ""
        #if canImport(UIKit)
        attachedImage = nil
        #endif
        messages.append(DisplayMessage(content: userDisplayText, isUser: true, imageURL: nil))
        chatHistory.append(ChatMessage(role: "user", content: historyText))

        isSending = true
        defer { isSending = false }

        // Build messages with memory as system prompt
        let messagesWithMemory = buildMessagesWithMemory()

        if streamEnabled {
            // Stream mode: show response token by token
            var fullReply = ""
            let replyIndex = messages.count
            messages.append(DisplayMessage(content: "", isUser: false, imageURL: nil))

            do {
                try await service.sendMessageStream(model: selectedModel, messages: messagesWithMemory, imageBase64: imageBase64) { chunk in
                    fullReply += chunk
                    self.messages[replyIndex] = DisplayMessage(content: fullReply, isUser: false, imageURL: nil)
                }
                chatHistory.append(ChatMessage(role: "assistant", content: fullReply))
                saveCurrentToHistory()
            } catch {
                messages[replyIndex] = DisplayMessage(content: "错误：\(error.localizedDescription)", isUser: false, imageURL: nil)
            }
        } else {
            // Normal mode: wait for full response
            do {
                let reply = try await service.sendMessage(model: selectedModel, messages: messagesWithMemory, imageBase64: imageBase64)
                chatHistory.append(ChatMessage(role: "assistant", content: reply))
                messages.append(DisplayMessage(content: reply, isUser: false, imageURL: nil))
                saveCurrentToHistory()
            } catch {
                messages.append(DisplayMessage(content: "错误：\(error.localizedDescription)", isUser: false, imageURL: nil))
            }
        }
    }

    func generateImage() async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let service = chatService, !selectedModel.isEmpty, !prompt.isEmpty else { return }
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
        // Save current conversation to history before clearing
        if !messages.isEmpty {
            saveCurrentToHistory()
        }
        messages = []
        chatHistory = []
        currentConversationID = nil
        #if canImport(UIKit)
        attachedImage = nil
        #endif
    }

    // MARK: - Memory

    private func buildMessagesWithMemory() -> [ChatMessage] {
        var result: [ChatMessage] = []
        let activeMemories = memories.filter { $0.enabled }
        if !activeMemories.isEmpty {
            let memoryContent = activeMemories.map { $0.content }.joined(separator: "\n")
            result.append(ChatMessage(role: "system", content: memoryContent))
        }
        result.append(contentsOf: chatHistory)
        return result
    }

    func loadMemories() {
        guard let data = UserDefaults.standard.data(forKey: "chat_memories"),
              let items = try? JSONDecoder().decode([MemoryItem].self, from: data) else {
            memories = []
            return
        }
        memories = items
    }

    func saveMemories() {
        if let data = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(data, forKey: "chat_memories")
        }
    }

    func addMemory(_ content: String) {
        let item = MemoryItem(id: UUID().uuidString, content: content, enabled: true)
        memories.append(item)
        saveMemories()
    }

    func deleteMemory(_ item: MemoryItem) {
        memories.removeAll { $0.id == item.id }
        saveMemories()
    }

    func toggleMemory(_ item: MemoryItem) {
        if let index = memories.firstIndex(where: { $0.id == item.id }) {
            memories[index].enabled.toggle()
            saveMemories()
        }
    }

    // MARK: - History

    @Published var savedConversations: [SavedConversation] = []

    func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "chat_history"),
              let conversations = try? JSONDecoder().decode([SavedConversation].self, from: data) else {
            savedConversations = []
            return
        }
        savedConversations = conversations
    }

    func saveCurrentToHistory() {
        guard !chatHistory.isEmpty else { return }
        let conversationID = currentConversationID ?? UUID().uuidString
        currentConversationID = conversationID
        let conversation = SavedConversation(
            id: conversationID,
            title: conversationTitle(),
            model: selectedModel,
            messages: chatHistory,
            date: Date()
        )
        if let index = savedConversations.firstIndex(where: { $0.id == conversationID }) {
            savedConversations[index] = conversation
        } else {
            savedConversations.insert(conversation, at: 0)
            // Keep max 50 conversations
            if savedConversations.count > 50 {
                savedConversations = Array(savedConversations.prefix(50))
            }
        }
        if let data = try? JSONEncoder().encode(savedConversations) {
            UserDefaults.standard.set(data, forKey: "chat_history")
        }
    }

    func loadConversation(_ conversation: SavedConversation) {
        currentConversationID = conversation.id
        chatHistory = conversation.messages
        messages = conversation.messages.map { msg in
            DisplayMessage(
                content: msg.content.isEmpty && msg.role == "user" ? "已附加图片" : msg.content,
                isUser: msg.role == "user",
                imageURL: nil
            )
        }
        if !conversation.model.isEmpty {
            selectedModel = conversation.model
        }
        inputText = ""
        #if canImport(UIKit)
        attachedImage = nil
        #endif
    }

    func deleteConversation(_ conversation: SavedConversation) {
        savedConversations.removeAll { $0.id == conversation.id }
        if currentConversationID == conversation.id {
            currentConversationID = nil
        }
        if let data = try? JSONEncoder().encode(savedConversations) {
            UserDefaults.standard.set(data, forKey: "chat_history")
        }
    }

    private var currentConversationID: String?

    private func attachedImageBase64() -> String? {
        #if canImport(UIKit)
        guard let attachedImage,
              let data = attachedImage.jpegData(compressionQuality: 0.9) else {
            return nil
        }
        return data.base64EncodedString()
        #else
        return nil
        #endif
    }

    private func conversationTitle() -> String {
        if let firstNonEmpty = chatHistory.first(where: { $0.role == "user" && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return String(firstNonEmpty.content.prefix(30))
        }
        return chatHistory.contains(where: { $0.role == "user" }) ? "图片对话" : "对话"
    }
}

// MARK: - History Models

struct SavedConversation: Codable, Identifiable {
    let id: String
    let title: String
    let model: String
    let messages: [ChatMessage]
    let date: Date
}

// MARK: - History View

private struct ChatHistoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.savedConversations.isEmpty {
                    Text("暂无历史记录")
                        .foregroundColor(Color.secondary)
                }
                ForEach(viewModel.savedConversations) { conversation in
                    Button {
                        viewModel.loadConversation(conversation)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(Font.subheadline)
                                .foregroundColor(Color.primary)
                                .lineLimit(1)
                            HStack {
                                if !conversation.model.isEmpty {
                                    Text(conversation.model)
                                }
                                Text(formatDate(conversation.date))
                            }
                            .font(Font.caption)
                            .foregroundColor(Color.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    let toDelete = indexSet.map { viewModel.savedConversations[$0] }
                    for conv in toDelete {
                        viewModel.deleteConversation(conv)
                    }
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                Button("关闭") { dismiss() }
            }
            .onAppear { viewModel.loadHistory() }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Memory Models & View

struct MemoryItem: Codable, Identifiable {
    let id: String
    var content: String
    var enabled: Bool
}

private struct MemoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newMemory = ""
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("记忆会作为系统提示词注入到每次对话中，帮助模型了解你的偏好和背景信息")) {
                    if viewModel.memories.isEmpty {
                        Text("暂无记忆，点击右上角添加")
                            .foregroundColor(Color.secondary)
                    }
                    ForEach(viewModel.memories) { item in
                        HStack {
                            Button {
                                viewModel.toggleMemory(item)
                            } label: {
                                Image(systemName: item.enabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.enabled ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            Text(item.content)
                                .font(Font.subheadline)
                                .foregroundColor(item.enabled ? Color.primary : Color.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        let toDelete = indexSet.map { viewModel.memories[$0] }
                        for item in toDelete {
                            viewModel.deleteMemory(item)
                        }
                    }
                }
            }
            .navigationTitle("记忆")
            .toolbar {
                Button("添加") { showingAdd = true }
                Button("关闭") { dismiss() }
            }
            .alert("添加记忆", isPresented: $showingAdd) {
                TextField("例如：我是一名 iOS 开发者", text: $newMemory)
                Button("添加") {
                    let content = newMemory.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        viewModel.addMemory(content)
                    }
                    newMemory = ""
                }
                Button("取消", role: .cancel) { newMemory = "" }
            }
            .onAppear { viewModel.loadMemories() }
        }
    }
}
