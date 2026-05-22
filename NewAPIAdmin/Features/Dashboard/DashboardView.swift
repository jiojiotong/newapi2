import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModelHolder = ViewModelHolder()

    var body: some View {
        List {
            Section("服务器") {
                LabeledContent("地址", value: sessionStore.profile?.baseURL.absoluteString ?? "-")
                LabeledContent("管理员", value: sessionStore.adminUser?.username ?? "-")
                LabeledContent("角色", value: roleText)
                LabeledContent("连接", value: viewModelHolder.viewModel?.statusText ?? "未加载")
            }

            Section("统计") {
                LabeledContent("渠道数量", value: viewModelHolder.viewModel?.channelCountText ?? "-")
                LabeledContent("用户数量", value: viewModelHolder.viewModel?.userCountText ?? "-")
                LabeledContent("兑换码数量", value: viewModelHolder.viewModel?.redemptionCountText ?? "-")
            }

            Section("快捷入口") {
                NavigationLink("渠道管理") {
                    ChannelsView()
                }
                NavigationLink("模型定价和分组倍率") {
                    PricingView()
                }
                NavigationLink("用户管理") {
                    UsersView()
                }
                NavigationLink("兑换码管理") {
                    RedemptionsView()
                }
            }
        }
        .navigationTitle("首页")
        .toolbar {
            Button("刷新") {
                Task { await load() }
            }
        }
        .task { await load() }
    }

    private var roleText: String {
        guard let role = sessionStore.adminUser?.role else {
            return "-"
        }
        return role >= 100 ? "Root" : "Admin"
    }

    private func load() async {
        guard let client = try? sessionStore.activeClient() else { return }
        if viewModelHolder.viewModel == nil {
            viewModelHolder.viewModel = DashboardViewModel(service: DashboardService(client: client))
        }
        await viewModelHolder.viewModel?.load()
    }

    @MainActor
    private final class ViewModelHolder: ObservableObject {
        @Published var viewModel: DashboardViewModel?
    }
}
