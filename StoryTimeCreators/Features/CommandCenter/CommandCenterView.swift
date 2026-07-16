import SwiftUI

struct CommandCenterView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = CommandCenterViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .loading where vm.payload == nil:
                LoadingStateView(message: "Loading command center…")
            case .error(let message) where vm.payload == nil:
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
            VStack(alignment: .leading, spacing: 20) {
                if let stats = vm.payload?.stats {
                    statsGrid(stats)
                }

                if let projects = vm.payload?.recentProjects, !projects.isEmpty {
                    SectionHeader(title: "Recent Projects", trailing: "\(projects.count)")
                    ForEach(projects) { project in
                        projectRow(project)
                    }
                } else if vm.state != .loading {
                    EmptyStateView(
                        title: "No recent projects",
                        subtitle: "Create a project to start your pipeline.",
                        systemImage: "folder"
                    )
                }

                SectionHeader(title: "Calendar", trailing: vm.calendarEvents.count > 0 ? "\(vm.calendarEvents.count) events" : nil)
                if vm.calendarEvents.isEmpty {
                    EmptyStateView(
                        title: "No upcoming events",
                        subtitle: "Shoot days, tasks, and milestones appear here.",
                        systemImage: "calendar"
                    )
                } else {
                    ForEach(vm.calendarEvents) { event in
                        calendarRow(event)
                    }
                }
            }
            .padding(16)
        }
    }

    private func statsGrid(_ stats: CommandCenterStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Projects", value: "\(stats.projectCount ?? 0)", icon: "folder.fill")
            StatTile(title: "Catalogue", value: "\(stats.catalogueCount ?? 0)", icon: "film.stack.fill")
            StatTile(title: "Watch Hours", value: formatHours(stats.watchHours), icon: "play.circle.fill")
            StatTile(title: "Revenue (ZAR)", value: formatCurrency(stats.revenueZar), icon: "chart.line.uptrend.xyaxis")
            StatTile(title: "Unread Messages", value: "\(stats.messagesUnread ?? 0)", icon: "bubble.left.fill")
            StatTile(title: "Connections", value: "\(stats.networkConnections ?? 0)", icon: "person.2.fill")
        }
    }

    private func projectRow(_ project: CreatorProject) -> some View {
        Button {
            router.openProject(project.id)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(STFont.body(15, weight: .semibold))
                        .foregroundStyle(STColor.textPrimary)
                        .lineLimit(1)
                    Text(project.phaseLabel)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textSecondary)
                    if let logline = project.logline, !logline.isEmpty {
                        Text(logline)
                            .font(STFont.body(12))
                            .foregroundStyle(STColor.textMuted)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if let percent = project.pipelineRollup?.overallPercent {
                    Text("\(Int(percent))%")
                        .font(STFont.mono(13, weight: .semibold))
                        .foregroundStyle(STColor.accent)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
            }
            .padding(14)
            .glassPanel()
        }
        .buttonStyle(.plain)
    }

    private func calendarRow(_ event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(STColor.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                if let starts = event.startsAt {
                    Text(starts)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textSecondary)
                }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(14)
        .glassPanel()
    }

    private func formatHours(_ value: Double?) -> String {
        guard let value else { return "0" }
        return String(format: "%.1f", value)
    }

    private func formatCurrency(_ value: Double?) -> String {
        guard let value else { return "R0" }
        return String(format: "R%.0f", value)
    }
}

@MainActor
private final class CommandCenterViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var payload: CommandCenterPayload?
    @Published private(set) var calendarEvents: [CalendarEvent] = []
    @Published private(set) var state: LoadState = .idle

    private let client = APIClient.shared

    func load(auth: AuthService) async {
        state = .loading
        do {
            async let centerTask = loadCommandCenter()
            async let calendarTask = loadCalendar()
            async let projectsTask = loadRecentProjectsFallback()

            let (center, calendar, projects) = try await (centerTask, calendarTask, projectsTask)

            var merged = center
            if merged.recentProjects?.isEmpty != false, !projects.isEmpty {
                merged.recentProjects = projects
            }
            if merged.calendarEvents?.isEmpty != false, !calendar.isEmpty {
                merged.calendarEvents = calendar
            }

            payload = merged
            calendarEvents = merged.calendarEvents ?? calendar
            state = .loaded
        } catch {
            state = .error(Self.mapError(error, auth: auth))
        }
    }

    private func loadCommandCenter() async throws -> CommandCenterPayload {
        do {
            return try await client.get(
                "/api/creator/command-center",
                query: [URLQueryItem(name: "range", value: "month")]
            )
        } catch let error as APIError {
            if case .decoding = error {
                return try await loadCommandCenterMapped()
            }
            throw error
        }
    }

    private func loadCommandCenterMapped() async throws -> CommandCenterPayload {
        guard let url = client.url(
            "/api/creator/command-center",
            query: [URLQueryItem(name: "range", value: "month")]
        ) else { throw APIError.invalidURL }

        let (data, response) = try await client.session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw APIError.network("Invalid response.") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding("Unexpected command center shape.")
        }

        var stats = CommandCenterStats()
        if let overview = json["overview"] as? [String: Any] {
            stats.projectCount = overview["activeProjects"] as? Int
            stats.watchHours = (overview["viewsLast7d"] as? Int).map { Double($0) / 60.0 }
        }
        if let analytics = json["analytics"] as? [String: Any],
           let revenue = analytics["revenue"] as? [String: Any] {
            stats.revenueZar = revenue["totalRand"] as? Double ?? revenue["revenue"] as? Double
            stats.catalogueCount = analytics["contentCount"] as? Int
        }

        return CommandCenterPayload(
            range: "month",
            stats: stats,
            recentProjects: nil,
            calendarEvents: nil,
            revenue: nil,
            ecosystem: nil
        )
    }

    private func loadCalendar() async throws -> [CalendarEvent] {
        do {
            let response: CalendarEventsResponse = try await client.get("/api/creator/command-center/calendar")
            return response.events ?? []
        } catch {
            return []
        }
    }

    private func loadRecentProjectsFallback() async throws -> [CreatorProject] {
        do {
            let response: ProjectsResponse = try await client.get("/api/creator/projects")
            return Array((response.projects).prefix(6))
        } catch {
            return []
        }
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
