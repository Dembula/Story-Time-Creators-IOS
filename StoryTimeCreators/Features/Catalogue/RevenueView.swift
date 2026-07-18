import SwiftUI

struct RevenueView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = RevenueViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .loading where vm.payload == nil:
                LoadingStateView(message: "Loading revenue…")
            case .error(let message) where vm.payload == nil:
                ErrorStateView(message: message, retry: { Task { await vm.load(auth: auth) } })
            default:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Revenue", trailing: "This month")

                        if let payload = vm.payload {
                            heroRevenue(payload)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                StatTile(
                                    title: "Watch-time share",
                                    value: vm.formatPercent(payload.share),
                                    icon: "percent"
                                )
                                StatTile(
                                    title: "Watch Time",
                                    value: vm.formatHours(payload.watchTime),
                                    icon: "clock.fill"
                                )
                                StatTile(
                                    title: "Total Views",
                                    value: "\(payload.totalViews ?? 0)",
                                    icon: "eye.fill"
                                )
                                StatTile(
                                    title: "Streams",
                                    value: "\(payload.streamCount ?? 0)",
                                    icon: "play.rectangle.fill"
                                )
                                StatTile(
                                    title: "Wallet Available",
                                    value: vm.formatCurrency(payload.walletAvailable),
                                    icon: "wallet.pass.fill"
                                )
                                StatTile(
                                    title: "Total Earnings",
                                    value: vm.formatCurrency(payload.walletTotalEarnings),
                                    icon: "chart.line.uptrend.xyaxis"
                                )
                            }

                            SectionHeader(title: "Breakdown")
                            if let perView = payload.perViewRand {
                                summaryRow("Per view", value: vm.formatCurrency(perView))
                            }
                            if let perStream = payload.perStreamRand {
                                summaryRow("Per stream", value: vm.formatCurrency(perStream))
                            }
                            if let projected = payload.projectedRevenue {
                                summaryRow("Projected", value: vm.formatCurrency(projected))
                            }

                            if let banking = payload.banking {
                                bankingCard(banking)
                            }

                            if let payouts = payload.payouts, !payouts.isEmpty {
                                SectionHeader(title: "Recent Payouts", trailing: "\(payouts.count)")
                                ForEach(Array(payouts.enumerated()), id: \.offset) { _, payout in
                                    payoutRow(payout, format: vm.formatCurrency)
                                }
                            } else {
                                Text("No payouts yet. Earnings accrue to your wallet and are paid out per cycle.")
                                    .font(STFont.body(12))
                                    .foregroundStyle(STColor.textMuted)
                                    .padding(.top, 4)
                            }
                        } else {
                            EmptyStateView(
                                title: "No revenue data",
                                subtitle: "Publish catalogue titles to start earning.",
                                systemImage: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(STColor.background)
        .task { await vm.load(auth: auth) }
        .refreshable { await vm.load(auth: auth) }
    }

    private func heroRevenue(_ payload: RevenueAPIResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This month’s revenue")
                .font(STFont.body(12, weight: .medium))
                .foregroundStyle(STColor.textMuted)
            Text(vm.formatCurrency(payload.revenue))
                .font(STFont.display(34, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
            Text("Based on your \(vm.formatPercent(payload.share)) share of platform watch time")
                .font(STFont.body(12))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [STColor.primary.opacity(0.28), STColor.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(STColor.primary.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func bankingCard(_ banking: RevenueBanking) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 20))
                .foregroundStyle(STColor.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(banking.bankName ?? "Bank account")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Text("•••• \(banking.accountNumberLast4 ?? "****") · \(banking.accountType ?? "")")
                    .font(STFont.body(11))
                    .foregroundStyle(STColor.textMuted)
            }
            Spacer()
            Image(systemName: banking.verified == true ? "checkmark.seal.fill" : "exclamationmark.circle")
                .foregroundStyle(banking.verified == true ? STColor.success : STColor.textMuted)
        }
        .padding(14)
        .glassPanel()
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
            Spacer()
            Text(value)
                .font(STFont.mono(14, weight: .semibold))
                .foregroundStyle(STColor.accent)
        }
        .padding(14)
        .glassPanel()
    }

    private func payoutRow(_ payout: RevenuePayout, format: (Double?) -> String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(format(payout.amount))
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                if let status = payout.status {
                    Text(status)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textMuted)
                }
            }
            Spacer()
            if let createdAt = payout.createdAt {
                Text(createdAt)
                    .font(STFont.body(11))
                    .foregroundStyle(STColor.textMuted)
            }
        }
        .padding(14)
        .glassPanel()
    }
}

@MainActor
private final class RevenueViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var payload: RevenueAPIResponse?
    @Published private(set) var state: LoadState = .idle

    private let client = APIClient.shared

    func load(auth: AuthService) async {
        state = .loading
        do {
            payload = try await client.get(
                "/api/creator/revenue",
                query: [URLQueryItem(name: "period", value: "month")]
            )
            state = .loaded
        } catch {
            state = .error(Self.mapError(error, auth: auth))
        }
    }

    func formatCurrency(_ value: Double?) -> String {
        guard let value else { return "R0" }
        return String(format: "R%.2f", value)
    }

    func formatHours(_ seconds: Double?) -> String {
        guard let seconds else { return "0h" }
        return String(format: "%.1fh", seconds / 3600.0)
    }

    func formatPercent(_ value: Double?) -> String {
        guard let value else { return "0%" }
        return String(format: "%.2f%%", value)
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private struct RevenueAPIResponse: Decodable {
    var revenue: Double?
    var watchTime: Double?
    var share: Double?
    var totalViews: Int?
    var streamCount: Int?
    var perViewRand: Double?
    var perStreamRand: Double?
    var projectedRevenue: Double?
    var walletAvailable: Double?
    var walletTotalEarnings: Double?
    var banking: RevenueBanking?
    var payouts: [RevenuePayout]?
}

struct RevenueBanking: Decodable {
    var bankName: String?
    var accountNumberLast4: String?
    var accountType: String?
    var verified: Bool?
}

struct RevenuePayout: Decodable {
    var amount: Double?
    var status: String?
    var period: String?
    var createdAt: String?
}
