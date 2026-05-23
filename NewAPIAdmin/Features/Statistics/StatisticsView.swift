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

            if !viewModel.modelPricingList.isEmpty {
                Section("模型定价") {
                    ForEach(viewModel.modelPricingList) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.modelName)
                                .font(Font.subheadline)
                                .lineLimit(1)
                            HStack(spacing: 12) {
                                if item.isFixedPrice {
                                    Text("固定 $\(formatPrice(item.inputPrice))/次")
                                } else {
                                    Text("输入 $\(formatPrice(item.inputPrice))/M")
                                    Text("输出 $\(formatPrice(item.outputPrice))/M")
                                }
                            }
                            .font(Font.caption)
                            .foregroundColor(Color.secondary)
                            if !item.channelNames.isEmpty {
                                Text(item.channelNames.joined(separator: ", "))
                                    .font(Font.caption2)
                                    .foregroundColor(Color.accentColor)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
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

            Section("资源") {
                StatCard(title: "用户数量", value: viewModel.userCountText, icon: "person.2")
                StatCard(title: "渠道数量", value: viewModel.channelCountText, icon: "antenna.radiowaves.left.and.right")
                StatCard(title: "模型数量", value: viewModel.modelCountText, icon: "cpu")
            }

            if !viewModel.perfModels.isEmpty {
                Section("性能健康（24h）") {
                    ForEach(viewModel.perfModels, id: \.modelName) { model in
                        HStack {
                            Text(model.modelName)
                                .font(Font.subheadline)
                                .lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(model.avgLatencyMs)ms")
                                    .font(Font.caption)
                                HStack(spacing: 4) {
                                    Text("\(String(format: "%.1f%%", model.successRate * 100))")
                                        .font(Font.caption2)
                                        .foregroundColor(model.successRate >= 0.95 ? Color.green : model.successRate >= 0.8 ? Color.orange : Color.red)
                                    if model.avgTps > 0 {
                                        Text("\(String(format: "%.1f", model.avgTps)) t/s")
                                            .font(Font.caption2)
                                            .foregroundColor(Color.secondary)
                                    }
                                }
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
        .adminListChrome()
    }

    private func formatPrice(_ value: Double) -> String {
        if value == value.rounded() && value < 100000 {
            return String(Int(value))
        }
        // Remove trailing zeros
        let formatted = String(format: "%.6f", value)
        var result = formatted
        while result.hasSuffix("0") { result.removeLast() }
        if result.hasSuffix(".") { result.removeLast() }
        return result
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
        AdminSurfaceCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: icon)
                        .foregroundColor(Color.accentColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Font.caption)
                        .foregroundColor(Color.secondary)
                    Text(value)
                        .font(Font.title3.bold())
                }

                Spacer()
            }
        }
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
    @Published var modelCountText = "-"
    @Published var topModels: [ModelUsage] = []
    @Published var modelPricingList: [ModelPricingInfo] = []
    @Published var perfModels: [PerfModelSummary] = []

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
        await loadModelPricing()
        await loadPerfMetrics()
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

    private func loadModelPricing() async {
        let channelMap = (try? await service.fetchModelChannelMap()) ?? [:]

        do {
            // Use /api/pricing (public endpoint, works for all roles)
            let pricing: [PricingItem] = try await service.fetchPricing()

            modelCountText = String(pricing.count)

            modelPricingList = pricing.map { item in
                let inputPrice = item.modelRatio * 2
                let outputPrice = item.modelRatio * 2 * item.completionRatio
                let isFixed = item.quotaType == 1
                let channels = channelMap[item.modelName] ?? []
                return ModelPricingInfo(
                    modelName: item.modelName,
                    inputPrice: isFixed ? item.modelPrice : inputPrice,
                    outputPrice: isFixed ? item.modelPrice : outputPrice,
                    isFixedPrice: isFixed,
                    channelNames: channels
                )
            }
        } catch {
            if !channelMap.isEmpty {
                modelCountText = String(channelMap.count)
            } else {
                modelCountText = "加载失败"
            }
            modelPricingList = []
        }
    }

    private func loadPerfMetrics() async {
        do {
            let result: PerfSummaryResult = try await service.fetchPerfSummary()
            perfModels = result.models
        } catch {
            perfModels = []
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
        let dollars = Double(quota) / 500000.0
        return String(format: "$%.2f", dollars)
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

struct ModelPricingInfo: Identifiable {
    var id: String { modelName }
    let modelName: String
    let inputPrice: Double
    let outputPrice: Double
    let isFixedPrice: Bool
    let channelNames: [String]
}
