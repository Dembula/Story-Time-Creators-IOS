import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Story Time")
                        .font(STFont.display(16, weight: .bold))
                        .foregroundStyle(STColor.textPrimary)
                    Text("Creators")
                        .font(STFont.body(12, weight: .semibold))
                        .foregroundStyle(STColor.primary)
                }
                Spacer()
                Button { router.closeMenu() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(STColor.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(STColor.surfaceElevated))
                }
            }
            .padding(18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Operating", items: AppDestination.operating)
                    section("Catalogue", items: AppDestination.monetization)
                    menuRow(.originals, highlight: true)
                    section("Pipeline", items: AppDestination.pipeline)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }

            Button {
                Task { await auth.signOut() }
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(STFont.body(15, weight: .medium))
                    .foregroundStyle(STColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(STColor.surfaceElevated)
        }
        .frame(maxHeight: .infinity)
        .background(
            STColor.surface
                .overlay(alignment: .trailing) {
                    Rectangle().fill(STColor.border).frame(width: 1)
                }
                .ignoresSafeArea()
        )
        .shadow(color: .black.opacity(0.45), radius: 24, x: 8)
    }

    private func section(_ title: String, items: [AppDestination]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(STFont.body(11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(STColor.textMuted)
                .padding(.horizontal, 10)
                .padding(.top, 4)
            ForEach(items) { item in
                menuRow(item)
            }
        }
    }

    private func menuRow(_ item: AppDestination, highlight: Bool = false) -> some View {
        let active = router.destination == item
        return Button {
            router.open(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                Text(item.title)
                    .font(STFont.body(15, weight: active ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(highlight || active ? STColor.accent : STColor.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? STColor.primary.opacity(0.14) : (highlight ? STColor.primary.opacity(0.08) : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? STColor.primary.opacity(0.28) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
