import SwiftUI

struct CommandCenterView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = CommandCenterViewModel()
    @State private var calendarMonth = Date()

    var body: some View {
        Group {
            switch vm.state {
            case .loading where vm.response == nil:
                LoadingStateView(message: "Loading command center…")
            case .error(let message) where vm.response == nil:
                ErrorStateView(message: message, retry: { Task { await vm.load(auth: auth) } })
            default:
                content
            }
        }
        .background(STColor.background)
        .task { await vm.load(auth: auth) }
        .refreshable { await vm.load(auth: auth) }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let overview = vm.response?.overview {
                    overviewStrip(overview)
                }
                revenueSection
                engagementSection
                productionSection
                topContentSection
                projectsSection
                calendarSection
                retentionSection
            }
            .padding(16)
        }
    }

    private func overviewStrip(_ overview: CommandCenterOverview) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                miniStat("Active projects", value: "\(overview.activeProjects ?? 0)", icon: "folder.fill")
                miniStat("Views (7d)", value: "\(overview.viewsLast7d ?? 0)", icon: "eye.fill")
                if let growth = overview.viewerGrowth7dPct {
                    miniStat("Growth", value: String(format: "%.1f%%", growth), icon: "chart.line.uptrend.xyaxis")
                }
                if let rate = overview.engagementRateApprox {
                    miniStat("Engagement", value: String(format: "%.1f%%", rate), icon: "heart.fill")
                }
                if let title = overview.topFilmTitle {
                    miniStat("Top title", value: title, icon: "star.fill")
                }
            }
        }
    }

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Revenue & watch time", trailing: vm.response?.analytics?.rangeKey?.uppercased())
            if let revenue = vm.response?.analytics?.revenue {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Revenue (ZAR)", value: formatZAR(revenue.amount), icon: "banknote.fill")
                    StatTile(title: "Your share", value: formatPercent(revenue.sharePercent), icon: "percent")
                    StatTile(title: "Watch time", value: formatDuration(revenue.watchTimeSeconds), icon: "clock.fill")
                    StatTile(title: "Views (period)", value: "\(revenue.totalViews ?? 0)", icon: "play.circle.fill")
                    StatTile(title: "Streams", value: "\(revenue.streamCount ?? 0)", icon: "film.fill")
                    StatTile(title: "Per view", value: formatZAR(revenue.perViewRand), icon: "chart.bar.fill")
                }
            } else {
                EmptyStateView(title: "No revenue data", subtitle: "Publish catalogue titles to start earning.", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
    }

    private var engagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Viewer engagement")
            if let e = vm.response?.analytics?.engagement {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Total views", value: "\(e.totalViews ?? 0)", icon: "eye.fill")
                    StatTile(title: "Unique watchers", value: "\(e.uniqueWatchers ?? 0)", icon: "person.2.fill")
                    StatTile(title: "Avg watch", value: formatDuration(e.averageWatchTimeSeconds), icon: "timer")
                    StatTile(title: "Comments", value: "\(e.totalComments ?? 0)", icon: "bubble.left.fill")
                    StatTile(title: "Ratings", value: "\(e.totalRatings ?? 0)", icon: "star.fill")
                    StatTile(title: "Watchlist adds", value: "\(e.watchlistCount ?? 0)", icon: "bookmark.fill")
                }
            }
        }
    }

    private var productionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Production pulse")
            if let p = vm.response?.production {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Shoot days", value: "\(p.shootDaysTotal ?? 0)", icon: "video.fill")
                    StatTile(title: "Open incidents", value: "\(p.openIncidents ?? 0)", icon: "exclamationmark.triangle.fill")
                    StatTile(title: "Call sheets", value: "\(p.callSheetsSaved ?? 0)", icon: "doc.richtext.fill")
                }
            }
        }
    }

    @ViewBuilder
    private var topContentSection: some View {
        let rows = vm.response?.analytics?.contentPerformance ?? []
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Top catalogue performance", trailing: "\(rows.count)")
                ForEach(rows.prefix(5)) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(STFont.body(14, weight: .semibold))
                                .foregroundStyle(STColor.textPrimary)
                            Text([row.type, row.reviewStatus].compactMap { $0 }.joined(separator: " · "))
                                .font(STFont.body(11))
                                .foregroundStyle(STColor.textMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(row.views ?? 0) views")
                                .font(STFont.body(12, weight: .medium))
                                .foregroundStyle(STColor.accent)
                            Text(formatDuration(row.watchTimeSeconds))
                                .font(STFont.body(11))
                                .foregroundStyle(STColor.textMuted)
                        }
                    }
                    .padding(12)
                    .glassPanel()
                }
            }
        }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My projects", trailing: "\(vm.projects.count)")
            if vm.projects.isEmpty {
                EmptyStateView(title: "No projects", subtitle: "Create a project to unlock the pipeline.", systemImage: "folder.badge.plus")
            } else {
                ForEach(vm.projects.prefix(6)) { project in
                    Button { router.openProject(project.id) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.title)
                                    .font(STFont.body(15, weight: .semibold))
                                    .foregroundStyle(STColor.textPrimary)
                                HStack(spacing: 8) {
                                    phaseBadge(project.phaseLabel)
                                    if let genre = project.genre { Text(genre).font(STFont.body(11)).foregroundStyle(STColor.textMuted) }
                                }
                                if let logline = project.logline, !logline.isEmpty {
                                    Text(logline)
                                        .font(STFont.body(12))
                                        .foregroundStyle(STColor.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            if let rollup = project.pipelineRollup?.overallPercent {
                                Text("\(Int(rollup))%")
                                    .font(STFont.mono(13, weight: .bold))
                                    .foregroundStyle(STColor.accent)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(STColor.textMuted)
                        }
                        .padding(14)
                        .glassPanel()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Calendar", trailing: "\(vm.calendarEvents.count) events")
            CalendarGridView(
                events: vm.calendarEvents,
                displayedMonth: $calendarMonth,
                onSelectEvent: { _ in }
            )
        }
        .onChange(of: calendarMonth) { _, newMonth in
            Task { await vm.loadCalendar(month: newMonth) }
        }
    }

    @ViewBuilder
    private var retentionSection: some View {
        if let retention = vm.response?.retention, let curve = retention.curve, !curve.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Audience retention", trailing: "n=\(retention.sampleSize ?? 0)")
                ForEach(curve) { point in
                    HStack {
                        Text("\(point.checkpoint)%")
                            .font(STFont.mono(12))
                            .foregroundStyle(STColor.textMuted)
                            .frame(width: 36, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(STColor.brandGradient)
                                .frame(width: geo.size.width * CGFloat(point.retainedPct / 100))
                        }
                        .frame(height: 8)
                        Text(String(format: "%.0f%%", point.retainedPct))
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func miniStat(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(STColor.primary)
            Text(value)
                .font(STFont.body(14, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
                .lineLimit(1)
            Text(title)
                .font(STFont.body(10))
                .foregroundStyle(STColor.textMuted)
        }
        .padding(12)
        .frame(width: 140, alignment: .leading)
        .glassPanel()
    }

    private func phaseBadge(_ label: String) -> some View {
        Text(label.uppercased())
            .font(STFont.body(10, weight: .bold))
            .foregroundStyle(STColor.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(STColor.primary.opacity(0.15)))
    }

    private func formatZAR(_ value: Double?) -> String {
        guard let value else { return "R0" }
        return String(format: "R%.2f", value)
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "0%" }
        return String(format: "%.1f%%", value)
    }

    private func formatDuration(_ seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "0m" }
        let hours = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}

@MainActor
private final class CommandCenterViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded, error(String)
    }

    @Published private(set) var response: CommandCenterAPIResponse?
    @Published private(set) var calendarEvents: [CommandCenterCalendarEvent] = []
    @Published private(set) var projects: [CreatorProject] = []
    @Published private(set) var state: LoadState = .idle

    private let client = APIClient.shared

    func load(auth: AuthService) async {
        state = .loading
        do {
            async let center: CommandCenterAPIResponse = client.get(
                "/api/creator/command-center",
                query: [URLQueryItem(name: "range", value: "month")]
            )
            async let calendar = loadCalendar(month: Date())
            async let projectList: ProjectsResponse = client.get("/api/creator/projects")

            let (c, cal, projs) = try await (center, calendar, projectList)
            response = c
            calendarEvents = cal
            projects = projs.projects
            state = .loaded
        } catch {
            state = .error(mapError(error, auth: auth))
        }
    }

    func loadCalendar(month: Date) async {
        let monthKey = DateParser.monthKey(month)
        do {
            let payload: CommandCenterCalendarPayload = try await client.get(
                "/api/creator/command-center/calendar",
                query: [URLQueryItem(name: "month", value: monthKey)]
            )
            calendarEvents = payload.events ?? []
        } catch {
            // keep existing events on failure
        }
    }

    private func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
