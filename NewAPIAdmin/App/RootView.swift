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
        .adminScreenBackground()
        .task {
            await sessionStore.restoreSessionIfPossible()
        }
    }
}
