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
            Section("统计") {
                LabeledContent("连接状态", value: viewModel.statusText)
                LabeledContent("渠道数量", value: viewModel.channelCountText)
                LabeledContent("用户数量", value: viewModel.userCountText)
                LabeledContent("兑换码数量", value: viewModel.redemptionCountText)
            }

            Section("管理") {
                NavigationLink("模型定价") {
                    PricingView()
                }
            }
        }
    }
}
