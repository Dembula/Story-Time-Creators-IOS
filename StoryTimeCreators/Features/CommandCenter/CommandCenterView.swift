import SwiftUI

struct CommandCenterView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = CommandCenterViewModel()
    @State private var calendarMonth = Date()
    @State private var calendarSheet: CalendarSheetRoute?

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
            VStack(alignment: .leading, spacing: 24) {
                welcomeHero
                if let overview = vm.response?.overview {
                    spotlight(overview)
                }
                projectsSection
                revenueSection
                engagementSection
                productionSection
                topContentSection
                calendarSection
                retentionSection
                aiSection
            }
            .padding(16)
        }
    }

    private var welcomeHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMMAND CENTER")
                .font(STFont.body(11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(STColor.accent)
            Text(greeting)
                .font(STFont.display(28, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
            Text("Your production pulse, catalogue performance, and calendar — live from the studio.")
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [STColor.primary.opacity(0.32), STColor.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(STColor.primary.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private var greeting: String {
        let name = auth.currentUser?.displayName.components(separatedBy: " ").first ?? "Creator"
        return "Hey, \(name)"
    }

    private func spotlight(_ overview: CommandCenterOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today’s snapshot")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                spotlightTile(
                    title: "Active projects",
                    value: "\(overview.activeProjects ?? 0)",
                    icon: "folder.fill",
                    accent: true
                )
                spotlightTile(
                    title: "Views · 7 days",
                    value: "\(overview.viewsLast7d ?? 0)",
                    icon: "eye.fill",
                    accent: false
                )
                spotlightTile(
                    title: "Growth",
                    value: overview.viewerGrowth7dPct.map { String(format: "%.1f%%", $0) } ?? "—",
                    icon: "chart.line.uptrend.xyaxis",
                    accent: false
                )
                spotlightTile(
                    title: "Engagement",
                    value: overview.engagementRateApprox.map { String(format: "%.1f%%", $0) } ?? "—",
                    icon: "heart.fill",
                    accent: false
                )
            }

            if let title = overview.topFilmTitle {
                HStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(STColor.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top performing title")
                            .font(STFont.body(11, weight: .medium))
                            .foregroundStyle(STColor.textMuted)
                        Text(title)
                            .font(STFont.body(15, weight: .semibold))
                            .foregroundStyle(STColor.textPrimary)
                        if let views = overview.topFilmViews {
                            Text("\(views) views")
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textSecondary)
                        }
                    }
                    Spacer()
                    if let revenue = overview.topFilmRevenueRand {
                        Text(formatZAR(revenue))
                            .font(STFont.mono(13, weight: .bold))
                            .foregroundStyle(STColor.accent)
                    }
                }
                .padding(14)
                .glassPanel()
            }
        }
    }

    private func spotlightTile(title: String, value: String, icon: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accent ? .black : STColor.primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(accent ? AnyShapeStyle(STColor.brandGradient) : AnyShapeStyle(STColor.primary.opacity(0.15)))
                )
            Text(value)
                .font(STFont.display(22, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(STFont.body(11))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Revenue & watch time", trailing: vm.response?.analytics?.rangeKey?.uppercased())
            if let revenue = vm.response?.analytics?.revenue {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Period revenue")
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textMuted)
                        Text(formatZAR(revenue.amount))
                            .font(STFont.display(28, weight: .bold))
                            .foregroundStyle(STColor.textPrimary)
                        Text("Share \(formatPercent(revenue.sharePercent))")
                            .font(STFont.body(12, weight: .medium))
                            .foregroundStyle(STColor.accent)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [STColor.primary.opacity(0.25), STColor.surface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                    VStack(spacing: 10) {
                        miniMetric("Watch", formatDuration(revenue.watchTimeSeconds))
                        miniMetric("Views", "\(revenue.totalViews ?? 0)")
                    }
                    .frame(width: 110)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Streams", value: "\(revenue.streamCount ?? 0)", icon: "film.fill")
                    StatTile(title: "Per view", value: formatZAR(revenue.perViewRand), icon: "chart.bar.fill")
                    StatTile(title: "Per stream", value: formatZAR(revenue.perStreamRand), icon: "play.circle.fill")
                }
            } else {
                EmptyStateView(title: "No revenue data", subtitle: "Publish catalogue titles to start earning.", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
    }

    private func miniMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(STFont.body(10)).foregroundStyle(STColor.textMuted)
            Text(value).font(STFont.body(14, weight: .bold)).foregroundStyle(STColor.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
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
                    StatTile(title: "Watchlist", value: "\(e.watchlistCount ?? 0)", icon: "bookmark.fill")
                }
            }
        }
    }

    private var productionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Production pulse")
            if let p = vm.response?.production {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Shoot days", value: "\(p.shootDaysTotal ?? 0)", icon: "video.fill")
                    StatTile(title: "Incidents", value: "\(p.openIncidents ?? 0)", icon: "exclamationmark.triangle.fill")
                    StatTile(title: "Call sheets", value: "\(p.callSheetsSaved ?? 0)", icon: "doc.richtext.fill")
                }
                if let tasks = p.tasksByStatus, !tasks.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(tasks.keys.sorted(), id: \.self) { key in
                            VStack(spacing: 4) {
                                Text("\(tasks[key] ?? 0)")
                                    .font(STFont.body(14, weight: .bold))
                                    .foregroundStyle(STColor.textPrimary)
                                Text(key.replacingOccurrences(of: "_", with: " "))
                                    .font(STFont.body(9))
                                    .foregroundStyle(STColor.textMuted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var topContentSection: some View {
        let rows = vm.response?.analytics?.contentPerformance ?? []
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Top catalogue", trailing: "\(min(rows.count, 5))")
                ForEach(Array(rows.prefix(5).enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(STFont.mono(14, weight: .bold))
                            .foregroundStyle(index == 0 ? .black : STColor.accent)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(index == 0 ? AnyShapeStyle(STColor.brandGradient) : AnyShapeStyle(STColor.primary.opacity(0.15)))
                            )
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
                            Text("\(row.views ?? 0)")
                                .font(STFont.body(13, weight: .bold))
                                .foregroundStyle(STColor.textPrimary)
                            Text(formatDuration(row.watchTimeSeconds))
                                .font(STFont.body(10))
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
            HStack {
                SectionHeader(title: "My projects", trailing: "\(vm.projects.count)")
                Spacer(minLength: 8)
                Button("See all") { router.open(.projects) }
                    .font(STFont.body(12, weight: .semibold))
                    .foregroundStyle(STColor.primary)
            }
            if vm.projects.isEmpty {
                EmptyStateView(title: "No projects", subtitle: "Create a project to unlock the pipeline.", systemImage: "folder.badge.plus")
            } else {
                ForEach(vm.projects.prefix(4)) { project in
                    Button { router.openProject(project.id) } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(STColor.primary.opacity(0.18))
                                .frame(width: 48, height: 48)
                                .overlay {
                                    Image(systemName: "film.stack")
                                        .foregroundStyle(STColor.primary)
                                }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.title)
                                    .font(STFont.body(15, weight: .semibold))
                                    .foregroundStyle(STColor.textPrimary)
                                HStack(spacing: 8) {
                                    phaseBadge(project.phaseLabel)
                                    if let genre = project.genre {
                                        Text(genre).font(STFont.body(11)).foregroundStyle(STColor.textMuted)
                                    }
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
                                VStack(spacing: 2) {
                                    Text("\(Int(rollup))%")
                                        .font(STFont.mono(13, weight: .bold))
                                        .foregroundStyle(STColor.accent)
                                    Text("done")
                                        .font(STFont.body(9))
                                        .foregroundStyle(STColor.textMuted)
                                }
                            }
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
            HStack {
                SectionHeader(title: "Calendar", trailing: "\(vm.calendarEvents.count) events")
                Spacer()
                Button {
                    calendarSheet = .new
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(STFont.body(14, weight: .semibold))
                        .foregroundStyle(STColor.primary)
                }
            }
            CalendarGridView(
                events: vm.calendarEvents,
                displayedMonth: $calendarMonth,
                onSelectEvent: { event in
                    if event.editable == true {
                        calendarSheet = .edit(event)
                    }
                }
            )
        }
        .onChange(of: calendarMonth) { _, newMonth in
            Task { await vm.loadCalendar(month: newMonth) }
        }
        .sheet(item: $calendarSheet) { route in
            switch route {
            case .new:
                CalendarEventEditorSheet(
                    event: nil,
                    defaultDate: calendarMonth,
                    projects: vm.projectOptions,
                    onSave: { body in await vm.createEvent(body, month: calendarMonth) },
                    onDelete: nil
                )
            case .edit(let event):
                CalendarEventEditorSheet(
                    event: event,
                    defaultDate: calendarMonth,
                    projects: vm.projectOptions,
                    onSave: { body in
                        await vm.updateEvent(id: event.id, body: UpdateCalendarEventBody(
                            title: body.title,
                            description: body.description,
                            startAt: body.startAt,
                            endAt: body.endAt,
                            allDay: body.allDay,
                            visibility: body.visibility,
                            projectId: body.projectId,
                            assigneeId: body.assigneeId
                        ), month: calendarMonth)
                    },
                    onDelete: { await vm.deleteEvent(id: event.id, month: calendarMonth) }
                )
            }
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
                                .frame(width: max(4, geo.size.width * CGFloat(point.retainedPct / 100)))
                        }
                        .frame(height: 8)
                        Text(String(format: "%.0f%%", point.retainedPct))
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .glassPanel()
        }
    }

    @ViewBuilder
    private var aiSection: some View {
        if let ai = vm.response?.ai {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "MODOC activity")
                HStack(spacing: 10) {
                    StatTile(title: "Chats", value: "\(ai.modocConversationsInRange ?? 0)", icon: "bubble.left.and.bubble.right.fill")
                    StatTile(title: "Messages", value: "\(ai.modocUserMessagesInRange ?? 0)", icon: "text.bubble.fill")
                }
                if let tasks = ai.topTasks, !tasks.isEmpty {
                    ForEach(tasks.prefix(3)) { task in
                        HStack {
                            Text(task.task)
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.textPrimary)
                            Spacer()
                            Text("\(task.count)")
                                .font(STFont.mono(12, weight: .bold))
                                .foregroundStyle(STColor.accent)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
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
            async let calendar = fetchCalendar(month: Date())
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
        calendarEvents = await fetchCalendar(month: month)
    }

    /// Returns nil on success, or an error message.
    func createEvent(_ body: CreateCalendarEventBody, month: Date) async -> String? {
        do {
            _ = try await client.post("/api/creator/command-center/calendar", body: body) as IdResponse
            await loadCalendar(month: month)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func updateEvent(id: String, body: UpdateCalendarEventBody, month: Date) async -> String? {
        do {
            _ = try await client.patch("/api/creator/command-center/calendar/\(id)", body: body) as OkResponse
            await loadCalendar(month: month)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func deleteEvent(id: String, month: Date) async -> String? {
        do {
            _ = try await client.delete("/api/creator/command-center/calendar/\(id)") as OkResponse
            await loadCalendar(month: month)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    var projectOptions: [CreatorProject] { projects }

    private func fetchCalendar(month: Date) async -> [CommandCenterCalendarEvent] {
        let monthKey = DateParser.monthKey(month)
        do {
            let payload: CommandCenterCalendarPayload = try await client.get(
                "/api/creator/command-center/calendar",
                query: [URLQueryItem(name: "month", value: monthKey)]
            )
            return payload.events ?? []
        } catch {
            return calendarEvents
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

enum CalendarSheetRoute: Identifiable {
    case new
    case edit(CommandCenterCalendarEvent)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let event): return event.id
        }
    }
}
