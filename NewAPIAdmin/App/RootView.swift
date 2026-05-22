import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.isAuthenticated {
                MainTabView()
            } else {
                ServerLoginView()
            }
        }
        .task {
            await sessionStore.restoreSessionIfPossible()
        }
    }
}
