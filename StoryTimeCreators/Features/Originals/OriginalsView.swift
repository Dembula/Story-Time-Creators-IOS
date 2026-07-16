import SwiftUI

struct OriginalsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var router: AppRouter
    @StateObject private var vm = OriginalsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero

                if let stats = vm.stats {
                    competitionSection(stats)
                } else if vm.statsUnavailable {
                    NoPayBanner(
                        text: "Competition stats are not available right now. Submit your Originals pitch from the web studio to enter the current period."
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "How to submit")
                    infoRow(
                        icon: "star.circle.fill",
                        title: "Story Time Originals",
                        detail: "Greenlit originals compete for platform support and audience votes. Build your project in My Projects and mark it as an Original when submitting."
                    )
                    infoRow(
                        icon: "globe",
                        title: "Submit on the web",
                        detail: "Full Originals submission, legal review, and checkout live at storytimecreators.com/creator/originals."
                    )
                    infoRow(
                        icon: "folder.fill",
                        title: "Track in Projects",
                        detail: "Open a project from My Projects to continue development while your pitch is in review."
                    )
                }
                .padding(16)
                .glassPanel()

                Button {
                    router.open(.projects)
                } label: {
                    Text("Open My Projects")
                        .font(STFont.body(15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(STColor.brandGradient))
                }

                if let webURL = vm.webOriginalsURL {
                    Link(destination: webURL) {
                        HStack {
                            Image(systemName: "safari.fill")
                            Text("Open Originals on the web")
                                .font(STFont.body(14, weight: .semibold))
                        }
                        .foregroundStyle(STColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(STColor.primary.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(STColor.background)
        .task { await vm.load(auth: auth) }
        .refreshable { await vm.load(auth: auth) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(STColor.accent)
                Text("Story Time Originals")
                    .font(STFont.display(22, weight: .bold))
                    .foregroundStyle(STColor.textPrimary)
            }
            Text("Pitch bold new films and series for the Story Time Originals competition. The iOS app keeps you connected to stats and projects — full submission flows run on the web.")
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(16)
        .glassPanel()
    }

    private func competitionSection(_ stats: CompetitionStatsResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Competition",
                trailing: stats.period?.name ?? "Current period"
            )
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatTile(
                    title: "Your rank",
                    value: stats.rank.map { "#\($0)" } ?? "—",
                    icon: "trophy.fill"
                )
                StatTile(
                    title: "Votes",
                    value: "\(stats.voteCount ?? 0)",
                    icon: "hand.thumbsup.fill"
                )
            }
            if let endDate = stats.period?.endDate {
                Text("Period ends \(endDate)")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
            }
        }
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(STColor.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Text(detail)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.textSecondary)
            }
        }
    }
}

@MainActor
private final class OriginalsViewModel: ObservableObject {
    @Published private(set) var stats: CompetitionStatsResponse?
    @Published private(set) var statsUnavailable = false

    var webOriginalsURL: URL? {
        URL(string: AppConfig.apiBaseURL.absoluteString + "/creator/originals")
    }

    private let client = APIClient.shared

    func load(auth: AuthService) async {
        do {
            stats = try await client.get("/api/competition/creator-stats")
            statsUnavailable = stats?.period == nil
        } catch let error as APIError {
            if case .unauthorized = error {
                Task { await auth.signOut() }
            }
            stats = nil
            statsUnavailable = true
        } catch {
            stats = nil
            statsUnavailable = true
        }
    }
}

private struct CompetitionStatsResponse: Decodable {
    var period: CompetitionPeriod?
    var rank: Int?
    var voteCount: Int?
}

private struct CompetitionPeriod: Decodable {
    var id: String?
    var name: String?
    var endDate: String?
}
