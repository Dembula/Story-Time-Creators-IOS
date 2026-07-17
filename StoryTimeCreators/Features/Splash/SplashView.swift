import SwiftUI

/// Native Creators splash — logo mark + typography (never full-bleed SplashScreen mock).
struct SplashView: View {
    var onFinished: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.86
    @State private var logoY: CGFloat = 28
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkY: CGFloat = 18
    @State private var footerOpacity: Double = 0
    @State private var progress: CGFloat = 0
    @State private var mesh = false
    @State private var exitOpacity: Double = 1
    @State private var didFinish = false

    var body: some View {
        GeometryReader { geo in
            let barWidth = min(geo.size.width * 0.58, 248.0)

            ZStack {
                orangeField
                meshLayer

                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.16)

                    VStack(spacing: 8) {
                        Image("SplashLogo")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: min(geo.size.width * 0.52, 220))
                            // Soft edge so square asset blends into the field (no crop line)
                            .mask(
                                RoundedRectangle(cornerRadius: 36, style: .continuous)
                                    .padding(2)
                            )
                            .scaleEffect(logoScale)
                            .offset(y: logoY)
                            .opacity(logoOpacity)
                            .accessibilityHidden(true)

                        VStack(spacing: 10) {
                            Text("STORY TIME")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .tracking(5)
                                .foregroundStyle(.white)

                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: 36, height: 1.5)

                            Text("CREATORS")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .tracking(6.5)
                                .foregroundStyle(Color.white.opacity(0.88))
                        }
                        .offset(y: wordmarkY)
                        .opacity(wordmarkOpacity)
                    }

                    Spacer()

                    VStack(spacing: 18) {
                        progressBar(width: barWidth)

                        Text("BUILDING STORIES TOGETHER...")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(3.0)
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                    .opacity(footerOpacity)
                    .padding(.bottom, max(40, geo.safeAreaInsets.bottom + 28))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .opacity(exitOpacity)
        .onAppear { startSequence() }
        .onDisappear { didFinish = true }
    }

    // MARK: - Layers

    private var orangeField: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.62, blue: 0.18),
                Color(red: 0.99, green: 0.48, blue: 0.08),
                Color(red: 0.95, green: 0.36, blue: 0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.28),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
    }

    private var meshLayer: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 260)
                .offset(x: mesh ? 24 : -40, y: -180)
                .blur(radius: 2)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 12,
                        endRadius: 240
                    )
                )
                .frame(width: 460, height: 300)
                .offset(x: mesh ? -16 : 56, y: 180)
                .blur(radius: 4)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func progressBar(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: width, height: 3)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.72, blue: 0.25).opacity(0.2),
                            Color(red: 1, green: 0.92, blue: 0.55),
                            .white,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(8, progress * width), height: 3)
                .shadow(color: .white.opacity(0.7), radius: 6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(red: 1, green: 0.92, blue: 0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 14, height: 14)
                .offset(x: max(0, progress * width - 7))
                .shadow(color: .white.opacity(0.95), radius: 8)
        }
        .frame(width: width, height: 14)
    }

    // MARK: - Motion

    private func startSequence() {
        guard !didFinish else { return }

        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
            mesh = true
        }

        withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
            logoOpacity = 1
            logoScale = 1
            logoY = 0
        }

        withAnimation(.easeOut(duration: 0.55).delay(0.2)) {
            wordmarkOpacity = 1
            wordmarkY = 0
        }

        withAnimation(.easeOut(duration: 0.45).delay(0.45)) {
            footerOpacity = 1
        }

        withAnimation(.easeInOut(duration: 1.85).delay(0.5)) {
            progress = 1
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_450_000_000)
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        withAnimation(.easeInOut(duration: 0.38)) {
            exitOpacity = 0
            logoScale = 1.04
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 380_000_000)
            onFinished()
        }
    }
}
