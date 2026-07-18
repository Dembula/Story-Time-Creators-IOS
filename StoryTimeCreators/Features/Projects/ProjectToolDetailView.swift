import SwiftUI

struct ProjectToolDetailView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService

    let projectId: String
    let tool: ProjectTool

    @StateObject private var vm: ProjectToolReportViewModel

    init(projectId: String, tool: ProjectTool) {
        self.projectId = projectId
        self.tool = tool
        _vm = StateObject(wrappedValue: ProjectToolReportViewModel(projectId: projectId, tool: tool))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if vm.isLoading && vm.rows.isEmpty {
                    LoadingStateView(message: "Loading \(tool.label)…")
                } else if let error = vm.errorMessage, vm.rows.isEmpty {
                    ErrorStateView(message: error, retry: { Task { await vm.load(auth: auth) } })
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if tool == .scriptReview {
                                NoPayBanner(text: "Executive paid script review is disabled on iOS. Internal notes and history still appear below.")
                            }

                            heroCard
                            metricsRow

                            SectionHeader(
                                title: "Latest updates",
                                trailing: "\(vm.rows.count)"
                            )

                            if vm.rows.isEmpty {
                                EmptyStateView(
                                    title: "No activity yet",
                                    subtitle: "When your team edits this tool on the web studio, versions, notes, and tasks land here.",
                                    systemImage: "sparkles.rectangle.stack"
                                )
                            } else {
                                ForEach(Array(vm.rows.enumerated()), id: \.element.id) { index, row in
                                    activityRow(row, index: index)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await vm.load(auth: auth) }
                }
            }
        }
        .background(STColor.background)
        .task { await vm.load(auth: auth) }
    }

    private var header: some View {
        HStack {
            Button {
                router.leaveToolDetail()
            } label: {
                Label(backLabel, systemImage: "chevron.left")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.primary)
            }
            Spacer()
            Button { Task { await vm.load(auth: auth) } } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(STColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(STColor.surfaceElevated))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(STColor.border).frame(height: 1) }
    }

    private var backLabel: String {
        switch router.toolReturnDestination {
        case .preProduction: return "Pre-Production"
        case .production: return "Production"
        case .postProduction: return "Post-Production"
        case .projects: return "Workspace"
        default: return "Back"
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13).fill(STColor.brandGradient))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.label)
                        .font(STFont.display(20, weight: .bold))
                        .foregroundStyle(STColor.textPrimary)
                    Text(tool.phase.title)
                        .font(STFont.body(12, weight: .medium))
                        .foregroundStyle(STColor.accent)
                }
            }
            Text(vm.summaryText)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(STColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(STColor.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricTile("Updates", "\(vm.rows.count)", "bolt.fill")
            metricTile("Actors", "\(vm.uniqueActors)", "person.2.fill")
            metricTile("Fresh", vm.latestStamp.isEmpty ? "—" : vm.latestStamp, "clock.fill")
        }
    }

    private func metricTile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(STColor.primary)
            Text(value)
                .font(STFont.body(13, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(STFont.body(10))
                .foregroundStyle(STColor.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func activityRow(_ row: ToolActivityRow, index: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Circle()
                    .fill(STColor.primary)
                    .frame(width: 10, height: 10)
                    .padding(.top, 16)
                if index < vm.rows.count - 1 {
                    Rectangle()
                        .fill(STColor.primary.opacity(0.25))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }
            .frame(width: 20, alignment: .top)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(STColor.accent)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(STColor.primary.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.title)
                            .font(STFont.body(14, weight: .semibold))
                            .foregroundStyle(STColor.textPrimary)
                        Spacer(minLength: 8)
                        if let kind = row.kind, !kind.isEmpty {
                            Text(kind.replacingOccurrences(of: "_", with: " "))
                                .font(STFont.body(9, weight: .bold))
                                .foregroundStyle(STColor.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(STColor.primary.opacity(0.15)))
                        }
                    }
                    if let detail = row.detail, !detail.isEmpty {
                        Text(detail)
                            .font(STFont.body(13))
                            .foregroundStyle(STColor.textSecondary)
                            .lineLimit(5)
                    }
                    HStack(spacing: 10) {
                        if let actor = row.actorName {
                            Label(actor, systemImage: "person.fill")
                        }
                        if let ts = row.timestamp, !ts.isEmpty {
                            Label(ts, systemImage: "clock")
                        }
                    }
                    .font(STFont.body(10))
                    .foregroundStyle(STColor.textMuted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(STColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(STColor.border, lineWidth: 1)
                    )
            )
            .padding(.leading, 8)
            .padding(.bottom, 10)
        }
    }
}

@MainActor
final class ProjectToolReportViewModel: ObservableObject {
    @Published private(set) var rows: [ToolActivityRow] = []
    @Published private(set) var summaryText = "Connected to your project workspace."
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let projectId: String
    let tool: ProjectTool
    private let client = APIClient.shared

    var uniqueActors: Int {
        Set(rows.compactMap(\.actorName).filter { !$0.isEmpty }).count
    }

    var latestStamp: String {
        rows.compactMap(\.timestamp).first(where: { !$0.isEmpty }) ?? ""
    }

    init(projectId: String, tool: ProjectTool) {
        self.projectId = projectId
        self.tool = tool
    }

    func load(auth: AuthService) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let toolPath = "/api/creator/projects/\(projectId)/\(tool.apiPathSegment)"
        var combined: [ToolActivityRow] = []
        var toolHit = false

        if let url = client.url(toolPath) {
            do {
                let (data, response) = try await client.session.data(from: url)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    combined += ToolReportBuilder.build(projectId: projectId, tool: tool, json: data)
                    toolHit = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        var openTasks = 0
        if let workspace: ProductionWorkspaceResponse = try? await client.get(
            "/api/creator/projects/\(projectId)/production-workspace"
        ) {
            let activity = ToolReportBuilder.merge(activity: workspace.activityFeed ?? [], tool: tool)
            combined = mergeRows(combined + activity)
            if let summary = workspace.taskSummary {
                openTasks = summary["OPEN"] ?? summary["IN_PROGRESS"] ?? 0
            }
        }

        combined = mergeRows(combined)
        combined.sort { ($0.timestamp ?? "") > ($1.timestamp ?? "") }

        if combined.isEmpty {
            summaryText = "No recorded updates yet for \(tool.label). Work in the web studio to seed the timeline."
        } else {
            var parts = ["\(combined.count) update\(combined.count == 1 ? "" : "s")"]
            if toolHit { parts.append("synced from \(tool.label)") }
            if openTasks > 0 { parts.append("\(openTasks) open workspace tasks") }
            summaryText = parts.joined(separator: " · ")
        }

        rows = combined
    }

    private func mergeRows(_ input: [ToolActivityRow]) -> [ToolActivityRow] {
        var seen = Set<String>()
        var out: [ToolActivityRow] = []
        for row in input {
            if seen.insert(row.id).inserted { out.append(row) }
        }
        return out
    }
}
