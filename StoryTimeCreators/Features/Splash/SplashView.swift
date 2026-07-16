import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void
    @State private var scale: CGFloat = 0.86
    @State private var opacity: Double = 0
    @State private var glow = false

    var body: some View {
        ZStack {
            STColor.primary
                .ignoresSafeArea()

            STColor.orangeGlow
                .ignoresSafeArea()
                .opacity(glow ? 1 : 0.55)

            VStack(spacing: 22) {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    .scaleEffect(scale)
                    .opacity(opacity)

                VStack(spacing: 6) {
                    Text("STORY TIME")
                        .font(STFont.display(28, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(.black.opacity(0.92))
                    Text("CREATORS")
                        .font(STFont.body(13, weight: .semibold))
                        .tracking(6)
                        .foregroundStyle(.black.opacity(0.7))
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                scale = 1
                opacity = 1
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glow = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_650_000_000)
                onFinished()
            }
        }
    }
}
