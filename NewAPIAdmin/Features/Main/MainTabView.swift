import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("首页", systemImage: "gauge")
            }

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("数据", systemImage: "chart.bar")
            }

            NavigationStack {
                ChannelsView()
            }
            .tabItem {
                Label("渠道", systemImage: "antenna.radiowaves.left.and.right")
            }

            NavigationStack {
                PricingView()
            }
            .tabItem {
                Label("定价", systemImage: "tag")
            }

            NavigationStack {
                UsersView()
            }
            .tabItem {
                Label("用户", systemImage: "person.2")
            }

            NavigationStack {
                RedemptionsView()
            }
            .tabItem {
                Label("兑换码", systemImage: "giftcard")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
    }
}
