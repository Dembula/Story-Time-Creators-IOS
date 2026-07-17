import SwiftUI

/// Native Creators splash — perfectly centered brand mark, wordmark, and loader.
struct SplashView: View {
    var onFinished: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.88
    @State private var wordmarkOpacity: Double = 0
    @State private var footerOpacity: Double = 0
    @State private var progress: CGFloat = 0
    @State private var glow = false
    @State private var exitOpacity: Double = 1
    @State private var didFinish = false

    var body: some View {
        ZStack {
            orangeField
            glowLayer

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                brandBlock
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                footerBlock
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(exitOpacity)
        .onAppear { startSequence() }
        .onDisappear { didFinish = true }
    }

    // MARK: - Brand

    private var brandBlock: some View {
        VStack(spacing: 22) {
            Image("SplashLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 168, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                // Italic S.T mark sits slightly heavy to the right — nudge for optical center
                .offset(x: -3)
                .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("STORY TIME")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 34, height: 1.5)

                Text("CREATORS")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(5.5)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .opacity(wordmarkOpacity)
        }
        .frame(maxWidth: .infinity)
    }

    private var footerBlock: some View {
        VStack(spacing: 16) {
            progressBar
                .frame(width: 220)

            Text("BUILDING STORIES TOGETHER...")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Color.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .opacity(footerOpacity)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(height: 3)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.75, blue: 0.3).opacity(0.35),
                            Color(red: 1, green: 0.92, blue: 0.55),
                            .white,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(10, progress * 220), height: 3)
                .shadow(color: .white.opacity(0.65), radius: 5)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(red: 1, green: 0.9, blue: 0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 9
                    )
                )
                .frame(width: 12, height: 12)
                .offset(x: max(0, progress * 220 - 6))
                .shadow(color: .white.opacity(0.9), radius: 7)
        }
        .frame(width: 220, height: 12)
    }

    // MARK: - Atmosphere

    private var orangeField: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.60, blue: 0.16),
                Color(red: 0.98, green: 0.44, blue: 0.06),
                Color(red: 0.93, green: 0.30, blue: 0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            RadialGradient(
                colors: [Color.white.opacity(0.26), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }

    private var glowLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(glow ? 0.22 : 0.10), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 200
                )
            )
            .frame(width: 420, height: 420)
            .offset(y: -40)
            .blur(radius: 2)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    // MARK: - Motion

    private func startSequence() {
        guard !didFinish else { return }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            glow = true
        }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
            logoOpacity = 1
            logoScale = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.18)) {
            wordmarkOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            footerOpacity = 1
        }

        withAnimation(.easeInOut(duration: 1.8).delay(0.45)) {
            progress = 1
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        withAnimation(.easeInOut(duration: 0.36)) {
            exitOpacity = 0
            logoScale = 1.03
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 360_000_000)
            onFinished()
        }
    }
}
