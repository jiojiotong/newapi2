import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModelHolder = ViewModelHolder()

    var body: some View {
        Group {
            if let viewModel = viewModelHolder.viewModel {
                DashboardContentView(viewModel: viewModel, sessionStore: sessionStore)
            } else {
                LoadingStateView(title: "准备首页")
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

private struct DashboardContentView: View {
    @ObservedObject var viewModel: DashboardViewModel
    var sessionStore: SessionStore

    var body: some View {
        List {
            Section("服务器") {
                LabeledContent("地址", value: sessionStore.profile?.baseURL.absoluteString ?? "-")
                LabeledContent("管理员", value: sessionStore.adminUser?.username ?? "-")
                LabeledContent("角色", value: roleText)
                LabeledContent("连接", value: viewModel.statusText)
            }

            Section("统计") {
                LabeledContent("渠道数量", value: viewModel.channelCountText)
                LabeledContent("用户数量", value: viewModel.userCountText)
                LabeledContent("兑换码数量", value: viewModel.redemptionCountText)
            }

            Section("管理") {
                NavigationLink("数据看板") {
                    StatisticsView()
                }
                NavigationLink("模型定价") {
                    PricingView()
                }
            }
        }
    }

    private var roleText: String {
        guard let role = sessionStore.adminUser?.role else {
            return "-"
        }
        return role >= 100 ? "Root" : "Admin"
    }
}
