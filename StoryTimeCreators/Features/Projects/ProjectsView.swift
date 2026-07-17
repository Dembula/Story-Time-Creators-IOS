import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = ProjectsViewModel()
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if let projectId = router.selectedProjectId,
               case .tool(let pid, let tool) = router.projectPath.last,
               pid == projectId {
                ProjectToolDetailView(projectId: pid, tool: tool)
            } else if let projectId = router.selectedProjectId,
                      let project = vm.project(withId: projectId) {
                ProjectWorkspaceView(
                    project: project,
                    onOpenTool: { tool in openTool(tool, projectId: projectId) },
                    onBack: { closeWorkspace() }
                )
            } else {
                projectList
            }
        }
        .background(STColor.background)
        .task { await vm.load(auth: auth) }
        .refreshable { await vm.load(auth: auth) }
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet { title, logline, type in
                Task {
                    if let project = await vm.createProject(
                        title: title,
                        logline: logline,
                        type: type,
                        auth: auth
                    ) {
                        router.openProject(project.id)
                    }
                }
            }
        }
    }

    private var projectList: some View {
        Group {
            switch vm.state {
            case .loading where vm.projects.isEmpty:
                LoadingStateView(message: "Loading projects…")
            case .error(let message) where vm.projects.isEmpty:
                ErrorStateView(message: message, retry: { Task { await vm.load(auth: auth) } })
            default:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SectionHeader(title: "My Projects", trailing: "\(vm.projects.count)")
                            Spacer()
                            Button {
                                showCreateSheet = true
                            } label: {
                                Label("New", systemImage: "plus.circle.fill")
                                    .font(STFont.body(14, weight: .semibold))
                                    .foregroundStyle(STColor.primary)
                            }
                        }

                        if vm.projects.isEmpty {
                            EmptyStateView(
                                title: "No projects yet",
                                subtitle: "Start a new film or series project to unlock the production pipeline.",
                                systemImage: "folder.badge.plus"
                            )
                        } else {
                            ForEach(vm.projects) { project in
                                projectRow(project)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func projectRow(_ project: CreatorProject) -> some View {
        Button {
            router.openProject(project.id)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(STFont.body(16, weight: .semibold))
                        .foregroundStyle(STColor.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        phaseBadge(project.phaseLabel)
                        if let status = project.status, !status.isEmpty {
                            Text(status.replacingOccurrences(of: "_", with: " "))
                                .font(STFont.body(11, weight: .medium))
                                .foregroundStyle(STColor.textMuted)
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
                if let rollup = project.pipelineRollup {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(rollup.overallPercent ?? 0))%")
                            .font(STFont.mono(14, weight: .bold))
                            .foregroundStyle(STColor.accent)
                        if let done = rollup.completedTools, let total = rollup.totalTools {
                            Text("\(done)/\(total) tools")
                                .font(STFont.body(10))
                                .foregroundStyle(STColor.textMuted)
                        }
                    }
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(STColor.textMuted)
            }
            .padding(14)
            .glassPanel()
        }
        .buttonStyle(.plain)
    }

    private func phaseBadge(_ label: String) -> some View {
        Text(label)
            .font(STFont.body(11, weight: .semibold))
            .foregroundStyle(STColor.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(STColor.primary.opacity(0.15)))
    }

    private func openTool(_ tool: ProjectTool, projectId: String) {
        router.selectedProjectId = projectId
        router.selectedTool = tool
        router.projectPath = [.overview(projectId), .tool(projectId, tool)]
        router.destination = .projects
    }

    private func closeWorkspace() {
        router.selectedProjectId = nil
        router.selectedTool = nil
        router.projectPath = []
    }
}

// MARK: - Workspace

struct ProjectWorkspaceView: View {
    let project: CreatorProject
    var onOpenTool: (ProjectTool) -> Void
    var onBack: () -> Void

    private var phase: ProjectPhase {
        ProjectPhaseResolver.resolve(project: project)
    }

    private var tools: [ProjectTool] {
        ProjectTool.tools(for: phase)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button(action: onBack) {
                        Label("Projects", systemImage: "chevron.left")
                            .font(STFont.body(14, weight: .semibold))
                            .foregroundStyle(STColor.primary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title)
                        .font(STFont.display(24, weight: .bold))
                        .foregroundStyle(STColor.textPrimary)
                    Text(project.phaseLabel)
                        .font(STFont.body(13, weight: .medium))
                        .foregroundStyle(STColor.accent)
                    if let logline = project.logline, !logline.isEmpty {
                        Text(logline)
                            .font(STFont.body(14))
                            .foregroundStyle(STColor.textSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel()

                if let rollup = project.pipelineRollup {
                    HStack(spacing: 12) {
                        StatTile(
                            title: "Pipeline",
                            value: "\(Int(rollup.overallPercent ?? 0))%",
                            icon: "chart.pie.fill"
                        )
                        StatTile(
                            title: "Tools Done",
                            value: "\(rollup.completedTools ?? 0)/\(rollup.totalTools ?? 0)",
                            icon: "checkmark.circle.fill"
                        )
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if let type = project.type {
                        StatTile(title: "Type", value: type, icon: "film.fill")
                    }
                    if let genre = project.genre {
                        StatTile(title: "Genre", value: genre, icon: "sparkles")
                    }
                    if let ideas = project.ideasCount {
                        StatTile(title: "Ideas", value: "\(ideas)", icon: "lightbulb.fill")
                    }
                    if let budget = project.budget, budget > 0 {
                        StatTile(title: "Budget", value: String(format: "R%.0f", budget), icon: "dollarsign.circle.fill")
                    }
                }

                SectionHeader(title: "\(phase.title) Tools", trailing: "\(tools.count)")
                ForEach(tools) { tool in
                    ToolCard(
                        title: tool.label,
                        subtitle: progressLabel(for: tool),
                        systemImage: ProjectToolIcon.symbol(for: tool)
                    ) {
                        onOpenTool(tool)
                    }
                }
            }
            .padding(16)
        }
    }

    private func progressLabel(for tool: ProjectTool) -> String? {
        guard let progress = project.projectToolProgress?.first(where: { $0.toolId == tool.rawValue }) else {
            return "Not started"
        }
        let status = progress.status?.replacingOccurrences(of: "_", with: " ") ?? "In progress"
        if let percent = progress.percent {
            return "\(status) · \(Int(percent))%"
        }
        return status
    }
}

// MARK: - Create Sheet

private struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var logline = ""
    @State private var type = "FILM"

    let onCreate: (String, String?, String) -> Void

    private let types = ["FILM", "SHORT", "SERIES", "DOCUMENTARY", "MUSIC_VIDEO"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Title", text: $title)
                    TextField("Logline", text: $logline, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title.trimmingCharacters(in: .whitespacesAndNewlines), logline.nilIfEmpty, type)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

// MARK: - View Model

@MainActor
private final class ProjectsViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var projects: [CreatorProject] = []
    @Published private(set) var state: LoadState = .idle
    @Published var createError: String?

    private let client = APIClient.shared

    func project(withId id: String) -> CreatorProject? {
        projects.first { $0.id == id }
    }

    func load(auth: AuthService) async {
        state = .loading
        do {
            let response: ProjectsResponse = try await client.get("/api/creator/projects")
            projects = response.projects
            state = .loaded
        } catch {
            state = .error(Self.mapError(error, auth: auth))
        }
    }

    func createProject(title: String, logline: String?, type: String, auth: AuthService) async -> CreatorProject? {
        createError = nil
        do {
            let body = CreateProjectBody(title: title, logline: logline, type: type, genre: nil)
            if let wrapped: CreateProjectResponse = try? await client.post("/api/creator/projects", body: body) {
                projects.insert(wrapped.project, at: 0)
                return wrapped.project
            }
            let created: CreatorProject = try await client.post("/api/creator/projects", body: body)
            projects.insert(created, at: 0)
            return created
        } catch {
            createError = Self.mapError(error, auth: auth)
            return nil
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

// MARK: - Helpers

enum ProjectPhaseResolver {
    static func resolve(project: CreatorProject) -> ProjectPhase {
        switch (project.phase ?? project.status ?? "").uppercased() {
        case "PRODUCTION": return .production
        case "POST_PRODUCTION", "POST-PRODUCTION": return .postProduction
        default: return .preProduction
        }
    }
}

enum ProjectToolIcon {
    static func symbol(for tool: ProjectTool) -> String {
        switch tool {
        case .ideaDevelopment: return "lightbulb.fill"
        case .scriptWriting, .scriptReview, .scriptBreakdown: return "doc.text.fill"
        case .budgetBuilder, .expenseTracker: return "dollarsign.circle.fill"
        case .productionScheduling, .callSheetGenerator: return "calendar"
        case .castingPortal: return "theatermasks.fill"
        case .crewMarketplace: return "wrench.and.screwdriver.fill"
        case .locationMarketplace: return "mappin.and.ellipse"
        case .equipmentPlanning, .equipmentTracking: return "camera.fill"
        case .controlCenter: return "slider.horizontal.3"
        case .editingStudio: return "scissors"
        case .distribution: return "arrow.up.forward.app.fill"
        default: return "square.grid.2x2.fill"
        }
    }
}

private struct CreateProjectResponse: Decodable {
    let project: CreatorProject
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
