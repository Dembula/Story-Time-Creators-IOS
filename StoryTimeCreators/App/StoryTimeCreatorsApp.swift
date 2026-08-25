import SwiftUI

@main
struct StoryTimeCreatorsApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var appRouter = AppRouter()

    init() {
        // Start StoreKit transaction listener early (Universe pattern) so
        // subscription updates activate licenses even if the paywall is closed.
        StoreKitService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(appRouter)
                .preferredColorScheme(.dark)
        }
    }
}
