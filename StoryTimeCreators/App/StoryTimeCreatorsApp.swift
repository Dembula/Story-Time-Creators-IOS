import SwiftUI

@main
struct StoryTimeCreatorsApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var appRouter = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(appRouter)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    auth.handleOAuthCallback(url: url)
                }
        }
    }
}
