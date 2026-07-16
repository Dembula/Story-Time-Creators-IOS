import SwiftUI

struct LoadingStateView: View {
    var message: String = "Loading…"
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(STColor.primary)
            Text(message)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(STColor.primary)
            Text(message)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let retry {
                Button("Try again", action: retry)
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(STColor.brandGradient))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let title: String
    var subtitle: String?
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(STColor.textMuted)
            Text(title)
                .font(STFont.display(17, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(STColor.primary)
            Text(value)
                .font(STFont.display(22, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(STFont.body(12))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}

struct ToolCard: View {
    let title: String
    var subtitle: String?
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(STColor.primary)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12).fill(STColor.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(STFont.body(15, weight: .semibold))
                        .foregroundStyle(STColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(STFont.body(12))
                            .foregroundStyle(STColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
            }
            .padding(14)
            .glassPanel()
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(STFont.display(18, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(STFont.body(12, weight: .medium))
                    .foregroundStyle(STColor.textMuted)
            }
        }
    }
}

struct NoPayBanner: View {
    var text: String = "Browse, inquire, and manage your own contacts here. In-app marketplace payments are disabled in the Creators app."

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(STColor.accent)
            Text(text)
                .font(STFont.body(12))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(STColor.primary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(STColor.primary.opacity(0.25), lineWidth: 1)
                )
        )
    }
}
