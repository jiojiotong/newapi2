import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var selectedTab = 0
    @State private var resetIDs: [Int: UUID] = [
        0: UUID(), 1: UUID(), 2: UUID(), 3: UUID()
    ]

    private var isAdmin: Bool {
        sessionStore.adminUser?.isAdmin == true
    }

    var body: some View {
        TabView(selection: tabSelection) {
            // 首页 - 所有用户可见（普通用户看自己的统计，管理员看全局）
            NavigationStack {
                if isAdmin {
                    StatisticsView()
                } else {
                    UserHomeView()
                }
            }
            .id(resetIDs[0])
            .tabItem {
                Label("首页", systemImage: "chart.bar")
            }
            .tag(0)

            // 对话 - 所有用户可见
            NavigationStack {
                ChatView()
            }
            .id(resetIDs[1])
            .tabItem {
                Label("对话", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(1)

            // 管理 - 仅管理员可见
            if isAdmin {
                NavigationStack {
                    ManageView()
                }
                .id(resetIDs[2])
                .tabItem {
                    Label("管理", systemImage: "square.grid.2x2")
                }
                .tag(2)
            }

            // 设置 - 所有用户可见
            NavigationStack {
                SettingsView()
            }
            .id(resetIDs[3])
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(isAdmin ? 3 : 2)
        }
        .tint(.accentColor)
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    resetIDs[newTab] = UUID()
                }
                selectedTab = newTab
            }
        )
    }
}
