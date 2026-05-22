import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    public init() {}

    public var body: some View {
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
