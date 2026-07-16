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

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .task {
            await auth.restoreSession()
        }
    }
}
