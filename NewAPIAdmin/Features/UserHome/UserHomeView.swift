import SwiftUI

struct UserHomeView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                UserHomeContentView(viewModel: viewModel)
            } else {
                LoadingStateView(title: "加载中")
            }
        }
        .navigationTitle("首页")
        .task { setupAndLoad() }
    }

    private func setupAndLoad() {
        guard holder.viewModel == nil, let client = try? sessionStore.activeClient(),
              let user = sessionStore.adminUser else { return }
        let viewModel = UserHomeViewModel(client: client, user: user)
        holder.viewModel = viewModel
        Task { await viewModel.load() }
    }

    @MainActor private final class Holder: ObservableObject {
        @Published var viewModel: UserHomeViewModel?
    }
}

private struct UserHomeContentView: View {
    @ObservedObject var viewModel: UserHomeViewModel
    @State private var showNotice = true

    var body: some View {
        List {
            if !viewModel.noticeText.isEmpty && showNotice {
                Section("公告") {
                    HStack(alignment: .top) {
                        Text(viewModel.noticeText)
                            .font(Font.subheadline)
                        Spacer()
                        Button {
                            showNotice = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("我的账户") {
                LabeledContent("用户名", value: viewModel.username)
                LabeledContent("剩余额度", value: viewModel.quotaText)
                LabeledContent("已用额度", value: viewModel.usedQuotaText)
                LabeledContent("请求次数", value: viewModel.requestCountText)
            }

            Section("用量统计") {
                LabeledContent("总消耗", value: viewModel.totalQuotaText)
                LabeledContent("RPM", value: viewModel.rpmText)
                LabeledContent("TPM", value: viewModel.tpmText)
            }

            if !viewModel.modelPricingList.isEmpty {
                Section("模型定价") {
                    ForEach(viewModel.modelPricingList, id: \.modelName) { item in
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
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("令牌") {
                NavigationLink {
                    TokensView()
                } label: {
                    Label("管理我的令牌", systemImage: "key")
                }
            }

            Section("日志") {
                NavigationLink {
                    LogsView()
                } label: {
                    Label("使用日志", systemImage: "doc.text")
                }
            }
        }
        .overlay {
            if viewModel.isLoading { LoadingStateView(title: "加载数据") }
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
        let formatted = String(format: "%.6f", value)
        var result = formatted
        while result.hasSuffix("0") { result.removeLast() }
        if result.hasSuffix(".") { result.removeLast() }
        return result
    }
}

@MainActor
final class UserHomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var username = "-"
    @Published var quotaText = "-"
    @Published var usedQuotaText = "-"
    @Published var requestCountText = "-"
    @Published var totalQuotaText = "-"
    @Published var rpmText = "-"
    @Published var tpmText = "-"
    @Published var tokenCountText = "-"
    @Published var noticeText = ""
    @Published var modelPricingList: [UserModelPriceItem] = []

    private let client: NewAPIClient

    init(client: NewAPIClient, user: AdminUser) {
        self.client = client
        self.username = user.username
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Load notice (public endpoint)
        do {
            let notice: String = try await client.get("/api/notice")
            noticeText = notice
        } catch {
            noticeText = ""
        }

        // Load user self info
        do {
            let userInfo: UserSelfInfo = try await client.get("/api/user/self")
            quotaText = formatQuota(userInfo.quota)
            usedQuotaText = formatQuota(userInfo.usedQuota)
            requestCountText = String(userInfo.requestCount ?? 0)
        } catch {}

        // Load self log stat
        do {
            let stat: LogStatResponse = try await client.get("/api/log/self/stat")
            totalQuotaText = formatQuota(stat.quota)
            rpmText = String(stat.rpm)
            tpmText = String(stat.tpm)
        } catch {}

        // Load token count
        do {
            let response: PaginatedResponse<APIToken> = try await client.get("/api/token/", queryItems: [
                URLQueryItem(name: "p", value: "1"),
                URLQueryItem(name: "page_size", value: "1")
            ])
            tokenCountText = String(response.total ?? 0)
        } catch {}

        // Load model pricing from /api/pricing (public endpoint)
        await loadPricing()
    }

    private func loadPricing() async {
        do {
            let pricing: [PricingItem] = try await client.get("/api/pricing")
            modelPricingList = pricing.map { item in
                let inputPrice = item.modelRatio * 2
                let outputPrice = item.modelRatio * 2 * item.completionRatio
                let isFixed = item.quotaType == 1
                return UserModelPriceItem(
                    modelName: item.modelName,
                    inputPrice: isFixed ? item.modelPrice : inputPrice,
                    outputPrice: isFixed ? item.modelPrice : outputPrice,
                    isFixedPrice: isFixed
                )
            }
        } catch {}
    }

    private func formatQuota(_ value: Int?) -> String {
        guard let q = value else { return "$0.00" }
        return String(format: "$%.2f", Double(q) / 500000.0)
    }
}

struct UserModelPriceItem {
    let modelName: String
    let inputPrice: Double
    let outputPrice: Double
    let isFixedPrice: Bool
}

struct PricingItem: Decodable {
    let modelName: String
    let quotaType: Int
    let modelRatio: Double
    let modelPrice: Double
    let completionRatio: Double

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case quotaType = "quota_type"
        case modelRatio = "model_ratio"
        case modelPrice = "model_price"
        case completionRatio = "completion_ratio"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelName = (try? container.decode(String.self, forKey: .modelName)) ?? ""
        quotaType = (try? container.decode(Int.self, forKey: .quotaType)) ?? 0
        modelRatio = (try? container.decode(Double.self, forKey: .modelRatio)) ?? 1
        modelPrice = (try? container.decode(Double.self, forKey: .modelPrice)) ?? 0
        completionRatio = (try? container.decode(Double.self, forKey: .completionRatio)) ?? 1
    }
}

struct UserSelfInfo: Decodable {
    let quota: Int?
    let usedQuota: Int?
    let requestCount: Int?

    enum CodingKeys: String, CodingKey {
        case quota
        case usedQuota = "used_quota"
        case requestCount = "request_count"
    }
}
