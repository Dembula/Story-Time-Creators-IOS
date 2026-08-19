import SwiftUI

/// One-time disclosure + consent before the VA sends any data to the AI service.
/// Required by App Store Guideline 5.1.1(i) — third-party AI data sharing.
struct VAConsentView: View {
    @ObservedObject var controller: VAController

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 44))
                .foregroundStyle(STColor.primary)

            Text("AI Assistant Data Use")
                .font(STFont.display(20, weight: .bold))
                .foregroundStyle(STColor.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                disclosureRow(
                    icon: "text.bubble",
                    title: "What is sent",
                    detail: "Your messages in this conversation and the current project context (title, logline, project ID) are sent to process your request."
                )
                disclosureRow(
                    icon: "building.2",
                    title: "Who receives it",
                    detail: "Data is processed by OpenAI (OpenAI, L.L.C.) on our server to generate responses. It is not used to train AI models."
                )
                disclosureRow(
                    icon: "lock.shield",
                    title: "How it's used",
                    detail: "Your data is used only to answer your question in real time. Conversations are not stored beyond the session on our AI provider's servers."
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(STColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(STColor.border))
            )

            Text("You can withdraw consent at any time from the Account page. Your privacy policy is available at story-time.online/legal/privacy.")
                .font(STFont.body(11))
                .foregroundStyle(STColor.textMuted)
                .multilineTextAlignment(.center)

            Button {
                controller.grantConsent()
            } label: {
                Text("Allow & Continue")
                    .font(STFont.body(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.black)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(STColor.brandGradient)
                    )
            }

            Button {
                controller.close()
            } label: {
                Text("Don't Allow")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(STColor.background)
    }

    private func disclosureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(STColor.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(STColor.primary.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Text(detail)
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
