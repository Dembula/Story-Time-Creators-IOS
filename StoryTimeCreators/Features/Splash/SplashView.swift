import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 1.06
    @State private var meshPhase: CGFloat = 0
    @State private var progress: CGFloat = 0
    @State private var progressOpacity: Double = 0
    @State private var sparkle = false
    @State private var exitOpacity: Double = 1
    @State private var taglinePulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base brand orange (letterboxed edges / safe areas)
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.52, blue: 0.10),
                        Color(red: 0.96, green: 0.38, blue: 0.04),
                        Color(red: 0.90, green: 0.28, blue: 0.02),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                livingMesh
                    .ignoresSafeArea()

                // Exact uploaded splash art
                Image("SplashScreen")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .scaleEffect(contentScale)
                    .opacity(contentOpacity)
                    .overlay {
                        // Soft vignette so edges blend into orange field
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.45, blue: 0.08).opacity(0.15),
                                .clear,
                                Color(red: 0.92, green: 0.30, blue: 0.02).opacity(0.25),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)
                    }

                // Animated comet loader over the mock’s bottom strip
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 3)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1, green: 0.7, blue: 0.2).opacity(0.15),
                                            Color(red: 1, green: 0.88, blue: 0.45),
                                            .white,
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(10, progress * geo.size.width * 0.58), height: 3)
                                .shadow(color: Color.white.opacity(0.75), radius: 8)

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white, Color(red: 1, green: 0.92, blue: 0.55), .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 12
                                    )
                                )
                                .frame(width: sparkle ? 16 : 12, height: sparkle ? 16 : 12)
                                .offset(x: max(0, progress * geo.size.width * 0.58 - 8))
                                .shadow(color: .white.opacity(0.95), radius: 10)
                        }
                        .frame(width: geo.size.width * 0.58)
                        .opacity(progressOpacity)

                        Text("BUILDING STORIES TOGETHER...")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(3.4)
                            .foregroundStyle(.white.opacity(taglinePulse ? 1 : 0.72))
                            .opacity(progressOpacity)
                    }
                    .padding(.bottom, max(42, geo.safeAreaInsets.bottom + 28))
                }
            }
        }
        .ignoresSafeArea()
        .opacity(exitOpacity)
        .onAppear { runSequence() }
    }

    private var livingMesh: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 240
                    )
                )
                .frame(width: 460, height: 300)
                .offset(x: -60 + meshPhase * 40, y: -220)
                .rotationEffect(.degrees(meshPhase * 10 - 12))
                .blur(radius: 2)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 280
                    )
                )
                .frame(width: 520, height: 340)
                .offset(x: 90 - meshPhase * 36, y: 180)
                .rotationEffect(.degrees(-meshPhase * 8 + 8))
                .blur(radius: 4)
        }
        .allowsHitTesting(false)
    }

    private func runSequence() {
        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
            meshPhase = 1
        }

        // Hero entrance — settle from slight zoom
        withAnimation(.easeOut(duration: 0.85)) {
            contentOpacity = 1
            contentScale = 1
        }

        withAnimation(.easeOut(duration: 0.45).delay(0.55)) {
            progressOpacity = 1
        }

        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true).delay(0.6)) {
            sparkle = true
            taglinePulse = true
        }

        // Comet sweep
        withAnimation(.easeInOut(duration: 2.05).delay(0.7)) {
            progress = 1
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_850_000_000)
            withAnimation(.easeInOut(duration: 0.48)) {
                exitOpacity = 0
                contentScale = 1.04
            }
            try? await Task.sleep(nanoseconds: 480_000_000)
            onFinished()
        }
    }
}
