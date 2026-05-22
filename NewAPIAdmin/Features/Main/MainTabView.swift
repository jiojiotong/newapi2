import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var resetIDs: [Int: UUID] = [
        0: UUID(), 1: UUID(), 2: UUID()
    ]

    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack {
                StatisticsView()
            }
            .id(resetIDs[0])
            .tabItem {
                Label("首页", systemImage: "chart.bar")
            }
            .tag(0)

            NavigationStack {
                ManageView()
            }
            .id(resetIDs[1])
            .tabItem {
                Label("管理", systemImage: "square.grid.2x2")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .id(resetIDs[2])
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(2)
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    resetIDs[newTab] = UUID()
                }
                previousTab = selectedTab
                selectedTab = newTab
            }
        )
    }
}
