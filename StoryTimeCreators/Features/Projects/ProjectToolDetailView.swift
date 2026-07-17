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
                        VStack(alignment: .leading, spacing: 16) {
                            if tool == .scriptReview {
                                NoPayBanner(text: "Executive paid script review is disabled on iOS. Internal notes and history still appear below.")
                            }

                            summaryCard

                            SectionHeader(
                                title: "Updates & activity",
                                trailing: "\(vm.rows.count)"
                            )

                            if vm.rows.isEmpty {
                                EmptyStateView(
                                    title: "No activity yet",
                                    subtitle: "Edits, submissions, and team actions will appear here as your team uses this tool on the web studio.",
                                    systemImage: "clock.arrow.circlepath"
                                )
                            } else {
                                ForEach(vm.rows) { row in
                                    activityRow(row)
                                }
                            }

                            Button {
                                Task { await vm.markInProgress(auth: auth) }
                            } label: {
                                HStack {
                                    if vm.isMarkingProgress { ProgressView().tint(.black) }
                                    Text("Mark in progress")
                                        .font(STFont.body(15, weight: .semibold))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(STColor.brandGradient))
                            }
                            .disabled(vm.isMarkingProgress)

                            if let msg = vm.progressMessage {
                                Text(msg).font(STFont.body(12)).foregroundStyle(STColor.success)
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
            Text(tool.label)
                .font(STFont.display(16, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            Spacer()
            Button { Task { await vm.load(auth: auth) } } label: {
                Image(systemName: "arrow.clockwise").foregroundStyle(STColor.textSecondary)
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tool report")
                .font(STFont.body(12, weight: .semibold))
                .foregroundStyle(STColor.textMuted)
            Text(vm.summaryText)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func activityRow(_ row: ToolActivityRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(STColor.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(STColor.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                if let detail = row.detail, !detail.isEmpty {
                    Text(detail)
                        .font(STFont.body(13))
                        .foregroundStyle(STColor.textSecondary)
                        .lineLimit(4)
                }
                HStack(spacing: 8) {
                    if let actor = row.actorName {
                        Label(actor, systemImage: "person.fill")
                    }
                    if let ts = row.timestamp {
                        Label(ts, systemImage: "clock")
                    }
                }
                .font(STFont.body(10))
                .foregroundStyle(STColor.textMuted)
            }
            Spacer()
        }
        .padding(12)
        .glassPanel()
    }
}

@MainActor
final class ProjectToolReportViewModel: ObservableObject {
    @Published private(set) var rows: [ToolActivityRow] = []
    @Published private(set) var summaryText = "Connected to your project workspace."
    @Published private(set) var isLoading = false
    @Published var isMarkingProgress = false
    @Published var progressMessage: String?
    @Published var errorMessage: String?

    let projectId: String
    let tool: ProjectTool
    private let client = APIClient.shared

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

        if let url = client.url(toolPath) {
            do {
                let (data, response) = try await client.session.data(from: url)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    combined += ToolReportBuilder.build(projectId: projectId, tool: tool, json: data)
                    summaryText = "Latest data from \(tool.label)."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        if let workspace: ProductionWorkspaceResponse = try? await client.get(
            "/api/creator/projects/\(projectId)/production-workspace"
        ) {
            let activity = ToolReportBuilder.merge(activity: workspace.activityFeed ?? [], tool: tool)
            combined = mergeRows(combined + activity)
            if let summary = workspace.taskSummary {
                let open = summary["OPEN"] ?? summary["IN_PROGRESS"] ?? 0
                summaryText += " · \(open) open workspace tasks."
            }
        }

        if combined.isEmpty {
            summaryText = "No recorded updates yet for \(tool.label). Start working in this tool on web or mark progress below."
        } else {
            combined.sort { ($0.timestamp ?? "") > ($1.timestamp ?? "") }
        }

        rows = combined
    }

    func markInProgress(auth: AuthService) async {
        isMarkingProgress = true
        progressMessage = nil
        defer { isMarkingProgress = false }

        struct Body: Encodable {
            var phase: String
            var toolId: String
            var status: String
            var percent: Double
        }

        do {
            _ = try await client.patch(
                "/api/creator/projects/\(projectId)/tools/progress",
                body: Body(phase: tool.phase.rawValue, toolId: tool.rawValue, status: "IN_PROGRESS", percent: 50)
            ) as OkResponse
            progressMessage = "Marked \(tool.label) as in progress."
        } catch {
            progressMessage = error.localizedDescription
        }
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
