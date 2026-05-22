import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var resetIDs: [Int: UUID] = [
        0: UUID(), 1: UUID(), 2: UUID(), 3: UUID(), 4: UUID()
    ]

    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack {
                DashboardView()
            }
            .id(resetIDs[0])
            .tabItem {
                Label("首页", systemImage: "gauge")
            }
            .tag(0)

            NavigationStack {
                ChannelsView()
            }
            .id(resetIDs[1])
            .tabItem {
                Label("渠道", systemImage: "antenna.radiowaves.left.and.right")
            }
            .tag(1)

            NavigationStack {
                UsersView()
            }
            .id(resetIDs[2])
            .tabItem {
                Label("用户", systemImage: "person.2")
            }
            .tag(2)

            NavigationStack {
                RedemptionsView()
            }
            .id(resetIDs[3])
            .tabItem {
                Label("兑换码", systemImage: "giftcard")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .id(resetIDs[4])
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(4)
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    // Tapped the same tab again — reset to root
                    resetIDs[newTab] = UUID()
                }
                previousTab = selectedTab
                selectedTab = newTab
            }
        )
    }
}
