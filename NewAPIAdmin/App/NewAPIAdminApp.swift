import SwiftUI

#if !SWIFT_PACKAGE
@main
struct NewAPIAdminApp: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
        }
    }
}
#endif
