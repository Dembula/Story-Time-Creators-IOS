import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var showSplash = true

    var body: some View {
        ZStack {
            STColor.background.ignoresSafeArea()

            Group {
                if auth.isAuthenticated {
                    MainShellView()
                } else {
                    CreatorSignInView()
                }
            }
            .opacity(showSplash ? 0 : 1)
            // Keep interactive only after splash so taps don't hit through
            .allowsHitTesting(!showSplash)

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .task {
            // Restore session in parallel with splash — splash owns its own timer
            await auth.restoreSession()
        }
    }
}
