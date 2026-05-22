import SwiftUI

struct ManageView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    private var isRoot: Bool {
        sessionStore.adminUser?.isRoot == true
    }

    var body: some View {
        List {
            NavigationLink {
                ChannelsView()
            } label: {
                Label("渠道管理", systemImage: "antenna.radiowaves.left.and.right")
            }

            NavigationLink {
                TokensView()
            } label: {
                Label("我的令牌", systemImage: "key")
            }

            NavigationLink {
                UsersView()
            } label: {
                Label("用户管理", systemImage: "person.2")
            }

            if isRoot {
                NavigationLink {
                    PricingView()
                } label: {
                    Label("模型定价", systemImage: "tag")
                }
            }

            NavigationLink {
                RedemptionsView()
            } label: {
                Label("兑换码", systemImage: "giftcard")
            }
        }
        .navigationTitle("管理")
    }
}
