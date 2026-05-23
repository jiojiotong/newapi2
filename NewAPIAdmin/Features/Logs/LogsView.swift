import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = LogsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                LoadingStateView(title: "加载日志")
            } else {
                LogsContentView(viewModel: viewModel)
            }
        }
        .navigationTitle("使用日志")
        .task {
            if let client = try? sessionStore.activeClient() {
                viewModel.client = client
                viewModel.isAdmin = sessionStore.adminUser?.isAdmin == true
                await viewModel.load()
            }
        }
    }
}

private struct LogsContentView: View {
    @ObservedObject var viewModel: LogsViewModel

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }

            ForEach(viewModel.items) { log in
                LogRowView(log: log)
            }

            Section {
                LabeledContent("当前页", value: String(viewModel.currentPage))
                if let total = viewModel.total {
                    LabeledContent("总数", value: String(total))
                }
                HStack {
                    Button("上一页") { Task { await viewModel.previousPage() } }
                        .disabled(!viewModel.canGoPrevious || viewModel.isLoading)
                    Spacer()
                    Button("下一页") { Task { await viewModel.nextPage() } }
                        .disabled(!viewModel.canGoNext || viewModel.isLoading)
                }
            }
        }
        .overlay {
            if viewModel.isLoading && !viewModel.items.isEmpty {
                ProgressView().padding()
            }
        }
        .toolbar {
            Button("刷新") { Task { await viewModel.load() } }
                .disabled(viewModel.isLoading)
        }
    }
}

private struct LogRowView: View {
    let log: LogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.modelName.isEmpty ? "未知模型" : log.modelName)
                    .font(Font.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text(logTypeText(log.type))
                    .font(Font.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(logTypeColor(log.type).opacity(0.15))
                    .foregroundColor(logTypeColor(log.type))
                    .cornerRadius(4)
            }
            HStack(spacing: 8) {
                if !log.tokenName.isEmpty {
                    Text(log.tokenName)
                }
                if !log.username.isEmpty {
                    Text(log.username)
                }
            }
            .font(Font.caption)
            .foregroundColor(Color.secondary)
            .lineLimit(1)
            HStack(spacing: 12) {
                Text("输入 \(log.promptTokens)")
                Text("输出 \(log.completionTokens)")
                Text(formatQuota(log.quota))
                Text("\(log.useTime)ms")
            }
            .font(Font.caption)
            .foregroundColor(Color.secondary)
            Text(formatTime(log.createdAt))
                .font(Font.caption2)
                .foregroundColor(Color.secondary)
        }
        .padding(.vertical, 2)
    }

    private func logTypeText(_ type: Int) -> String {
        switch type {
        case 1: return "充值"
        case 2: return "消费"
        case 3: return "管理"
        case 4: return "系统"
        default: return "未知"
        }
    }

    private func logTypeColor(_ type: Int) -> Color {
        switch type {
        case 1: return Color.green
        case 2: return Color.blue
        case 3: return Color.orange
        case 4: return Color.purple
        default: return Color.gray
        }
    }

    private func formatQuota(_ quota: Int) -> String {
        String(format: "$%.2f", Double(quota) / 500000.0)
    }

    private func formatTime(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
final class LogsViewModel: ObservableObject {
    @Published var items: [LogItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var total: Int?

    var client: NewAPIClient?
    var isAdmin = false
    private let pageSize = 30

    var canGoPrevious: Bool { currentPage > 1 }
    var canGoNext: Bool {
        if let total { return currentPage * pageSize < total }
        return items.count == pageSize
    }

    func load(page: Int? = nil) async {
        guard let client else { return }
        let targetPage = max(1, page ?? currentPage)
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let path = isAdmin ? "/api/log/" : "/api/log/self"
            let response: PaginatedResponse<LogItem> = try await client.get(path, queryItems: [
                URLQueryItem(name: "p", value: String(targetPage)),
                URLQueryItem(name: "page_size", value: String(pageSize))
            ])
            items = response.items
            total = response.total
            currentPage = targetPage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previousPage() async { guard canGoPrevious else { return }; await load(page: currentPage - 1) }
    func nextPage() async { guard canGoNext else { return }; await load(page: currentPage + 1) }
}

// MARK: - Model

struct LogItem: Codable, Identifiable {
    let id: Int
    let userId: Int
    let createdAt: Int
    let type: Int
    let content: String
    let username: String
    let tokenName: String
    let modelName: String
    let quota: Int
    let promptTokens: Int
    let completionTokens: Int
    let useTime: Int
    let channelId: Int
    let group: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case type
        case content
        case username
        case tokenName = "token_name"
        case modelName = "model_name"
        case quota
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case useTime = "use_time"
        case channelId = "channel"
        case group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? Int.random(in: Int.min ..< -1)
        userId = (try? container.decode(Int.self, forKey: .userId)) ?? 0
        createdAt = (try? container.decode(Int.self, forKey: .createdAt)) ?? 0
        type = (try? container.decode(Int.self, forKey: .type)) ?? 0
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        username = (try? container.decode(String.self, forKey: .username)) ?? ""
        tokenName = (try? container.decode(String.self, forKey: .tokenName)) ?? ""
        modelName = (try? container.decode(String.self, forKey: .modelName)) ?? ""
        quota = (try? container.decode(Int.self, forKey: .quota)) ?? 0
        promptTokens = (try? container.decode(Int.self, forKey: .promptTokens)) ?? 0
        completionTokens = (try? container.decode(Int.self, forKey: .completionTokens)) ?? 0
        useTime = (try? container.decode(Int.self, forKey: .useTime)) ?? 0
        channelId = (try? container.decode(Int.self, forKey: .channelId)) ?? 0
        group = (try? container.decode(String.self, forKey: .group)) ?? ""
    }
}
