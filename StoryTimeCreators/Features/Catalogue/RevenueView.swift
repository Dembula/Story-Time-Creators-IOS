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
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                StatTile(
                                    title: "Period Revenue",
                                    value: vm.formatCurrency(payload.revenue),
                                    icon: "banknote.fill"
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

                            if let perView = payload.perViewRand {
                                summaryRow("Per view", value: vm.formatCurrency(perView))
                            }
                            if let perStream = payload.perStreamRand {
                                summaryRow("Per stream", value: vm.formatCurrency(perStream))
                            }

                            if let payouts = payload.payouts, !payouts.isEmpty {
                                SectionHeader(title: "Recent Payouts", trailing: "\(payouts.count)")
                                ForEach(Array(payouts.enumerated()), id: \.offset) { _, payout in
                                    payoutRow(payout, format: vm.formatCurrency)
                                }
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
    var walletAvailable: Double?
    var walletTotalEarnings: Double?
    var payouts: [RevenuePayout]?
}

struct RevenuePayout: Decodable {
    var amount: Double?
    var status: String?
    var createdAt: String?
}
