import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                StatisticsContentView(viewModel: viewModel)
            } else {
                LoadingStateView(title: "准备数据看板")
            }
        }
        .navigationTitle("数据看板")
        .task { setupAndLoad() }
    }

    private func setupAndLoad() {
        guard holder.viewModel == nil, let client = try? sessionStore.activeClient() else { return }
        let viewModel = StatisticsViewModel(service: StatisticsService(client: client))
        holder.viewModel = viewModel
        Task { await viewModel.load() }
    }

    @MainActor private final class Holder: ObservableObject {
        @Published var viewModel: StatisticsViewModel?
    }
}

private struct StatisticsContentView: View {
    @ObservedObject var viewModel: StatisticsViewModel

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundColor(Color.red)
                }
            }

            Section("总览") {
                StatCard(title: "总消耗额度", value: viewModel.totalQuotaText, icon: "creditcard")
                StatCard(title: "总 Token 数", value: viewModel.totalTokenText, icon: "number")
                StatCard(title: "总请求数", value: viewModel.totalRequestText, icon: "arrow.up.arrow.down")
            }

            Section("实时") {
                StatCard(title: "RPM（每分钟请求）", value: viewModel.rpmText, icon: "speedometer")
                StatCard(title: "TPM（每分钟 Token）", value: viewModel.tpmText, icon: "bolt")
            }

            Section("资源") {
                StatCard(title: "用户数量", value: viewModel.userCountText, icon: "person.2")
                StatCard(title: "渠道数量", value: viewModel.channelCountText, icon: "antenna.radiowaves.left.and.right")
            }

            if !viewModel.topModels.isEmpty {
                Section("模型用量 Top 10") {
                    ForEach(viewModel.topModels) { model in
                        HStack {
                            Text(model.modelName)
                                .font(Font.subheadline)
                                .lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(formatNumber(model.totalTokens)) tokens")
                                    .font(Font.caption)
                                Text("\(model.requestCount) 次")
                                    .font(Font.caption)
                                    .foregroundColor(Color.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading { LoadingStateView(title: "加载统计数据") }
        }
        .toolbar {
            Button("刷新") { Task { await viewModel.load() } }
        }
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.2fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return String(value)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.caption)
                    .foregroundColor(Color.secondary)
                Text(value)
                    .font(Font.title3.bold())
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var totalQuotaText = "-"
    @Published var totalTokenText = "-"
    @Published var totalRequestText = "-"
    @Published var rpmText = "-"
    @Published var tpmText = "-"
    @Published var userCountText = "-"
    @Published var channelCountText = "-"
    @Published var topModels: [ModelUsage] = []

    private let service: StatisticsService

    init(service: StatisticsService) {
        self.service = service
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        await loadLogStat()
        await loadCounts()
        await loadQuotaData()
    }

    private func loadLogStat() async {
        do {
            let stat = try await service.logStat()
            totalQuotaText = formatQuota(stat.quota)
            rpmText = String(stat.rpm)
            tpmText = formatLargeNumber(stat.tpm)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadCounts() async {
        do {
            let users = try await service.userCount()
            userCountText = String(users)
        } catch {
            userCountText = "加载失败"
        }

        do {
            let channels = try await service.channelCount()
            channelCountText = String(channels)
        } catch {
            channelCountText = "加载失败"
        }
    }

    private func loadQuotaData() async {
        do {
            let now = Int(Date().timeIntervalSince1970)
            let sevenDaysAgo = now - 7 * 24 * 3600
            let data = try await service.quotaData(startTimestamp: sevenDaysAgo, endTimestamp: now)

            var totalTokens = 0
            var totalRequests = 0
            var modelMap: [String: (tokens: Int, requests: Int)] = [:]

            for point in data {
                totalTokens += point.tokenUsed
                totalRequests += point.count
                let existing = modelMap[point.modelName] ?? (tokens: 0, requests: 0)
                modelMap[point.modelName] = (tokens: existing.tokens + point.tokenUsed, requests: existing.requests + point.count)
            }

            totalTokenText = formatLargeNumber(totalTokens)
            totalRequestText = formatLargeNumber(totalRequests)

            topModels = modelMap
                .sorted { $0.value.tokens > $1.value.tokens }
                .prefix(10)
                .map { ModelUsage(modelName: $0.key, totalTokens: $0.value.tokens, requestCount: $0.value.requests) }
        } catch {
            totalTokenText = "加载失败"
            totalRequestText = "加载失败"
        }
    }

    private func formatQuota(_ quota: Int) -> String {
        // NewAPI: 1 unit = $0.002/1K tokens, so $1 = 500000 quota units
        let dollars = Double(quota) / 500000.0
        if dollars >= 1000 {
            return String(format: "$%.0f", dollars)
        } else if dollars >= 1 {
            return String(format: "$%.2f", dollars)
        } else if dollars > 0 {
            return String(format: "$%.4f", dollars)
        }
        return "$0"
    }

    private func formatLargeNumber(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.2fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return String(value)
    }
}

struct ModelUsage: Identifiable {
    var id: String { modelName }
    let modelName: String
    let totalTokens: Int
    let requestCount: Int
}
