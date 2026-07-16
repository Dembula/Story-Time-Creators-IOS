import SwiftUI

struct VAFloatingButton: View {
    @ObservedObject var controller: VAController
    @EnvironmentObject private var router: AppRouter

    @State private var pulse = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    controller.open(projectId: router.selectedProjectId)
                } label: {
                    ZStack {
                        if controller.statusAvailable {
                            Circle()
                                .fill(STColor.primary.opacity(0.35))
                                .frame(width: pulse ? 62 : 52, height: pulse ? 62 : 52)
                                .animation(
                                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                    value: pulse
                                )
                        }

                        Circle()
                            .fill(STColor.brandGradient)
                            .frame(width: 54, height: 54)
                            .shadow(color: STColor.primary.opacity(0.45), radius: 12, y: 4)

                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.85))
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 18)
                .accessibilityLabel("Open Story Time assistant")
            }
        }
        .onAppear {
            pulse = true
            Task { await controller.loadStatus() }
        }
    }
}
