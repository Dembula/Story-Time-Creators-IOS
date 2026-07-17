import SwiftUI

struct PhaseHubView: View {
    @EnvironmentObject private var router: AppRouter

    let phase: ProjectPhase

    @State private var projects: [CreatorProject] = []
    @State private var selectedProjectId: String?
    @State private var isLoading = true
    @State private var loadError: String?

    private var tools: [ProjectTool] { ProjectTool.hubTools(for: phase) }

    init(phase: ProjectPhase) {
        self.phase = phase
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading \(phase.title.lowercased()) tools…")
            } else if let loadError {
                ErrorStateView(message: loadError, retry: { Task { await loadProjects() } })
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        projectPicker
                        SectionHeader(
                            title: phase.title,
                            trailing: "\(tools.count) tools"
                        )
                        toolsGrid
                    }
                    .padding(16)
                }
            }
        }
        .task {
            if selectedProjectId == nil {
                selectedProjectId = router.selectedProjectId
            }
            await loadProjects()
        }
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project context")
                .font(STFont.body(12, weight: .semibold))
                .foregroundStyle(STColor.textMuted)
            Menu {
                Button("No project selected") {
                    selectedProjectId = nil
                    router.selectedProjectId = nil
                }
                ForEach(projects) { project in
                    Button(project.title) {
                        selectedProjectId = project.id
                        router.selectedProjectId = project.id
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(STColor.primary)
                    Text(selectedProjectTitle)
                        .font(STFont.body(15, weight: .medium))
                        .foregroundStyle(STColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(STColor.textMuted)
                }
                .padding(14)
                .glassPanel()
            }
        }
    }

    private var selectedProjectTitle: String {
        if let id = selectedProjectId,
           let project = projects.first(where: { $0.id == id }) {
            return project.title
        }
        return "Select a project"
    }

    private var toolsGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(tools) { tool in
                let needsProject = !tool.isMarketplaceStyle && selectedProjectId == nil
                ToolCard(
                    title: tool.label,
                    subtitle: toolSubtitle(for: tool),
                    systemImage: tool.systemImage
                ) {
                    openTool(tool)
                }
                .opacity(needsProject ? 0.45 : 1)
                .allowsHitTesting(!needsProject)
            }
        }
    }

    private func openTool(_ tool: ProjectTool) {
        if !tool.isMarketplaceStyle && selectedProjectId == nil {
            return
        }
        if let selectedProjectId {
            router.selectedProjectId = selectedProjectId
        }
        router.openTool(tool, projectId: selectedProjectId)
    }

    private func toolSubtitle(for tool: ProjectTool) -> String? {
        if tool.isMarketplaceStyle {
            return "Browse & manage contacts — no payments"
        }
        if selectedProjectId != nil {
            return "Opens activity report for this project"
        }
        return "Select a project above to open this tool"
    }

    @MainActor
    private func loadProjects() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let response: ProjectsResponse = try await APIClient.shared.get("/api/creator/projects")
            projects = response.projects
            if selectedProjectId == nil {
                selectedProjectId = router.selectedProjectId ?? projects.first?.id
            }
            if let selectedProjectId {
                router.selectedProjectId = selectedProjectId
            }
        } catch {
            projects = []
            loadError = error.localizedDescription
        }
    }
}
