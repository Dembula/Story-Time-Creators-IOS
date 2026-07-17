import SwiftUI

struct PhaseHubView: View {
    @EnvironmentObject private var router: AppRouter

    let phase: ProjectPhase

    @State private var projects: [CreatorProject] = []
    @State private var selectedProjectId: String?
    @State private var isLoading = true
    @State private var loadError: String?

    private var tools: [ProjectTool] { ProjectTool.hubTools(for: phase) }
    private var marketplaceCount: Int { tools.filter(\.isMarketplaceStyle).count }
    private var reportCount: Int { tools.count - marketplaceCount }

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
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                        projectPicker
                        insightStrip
                        SectionHeader(title: "Tools", trailing: "\(tools.count)")
                        toolsGrid
                    }
                    .padding(16)
                }
            }
        }
        .background(STColor.background)
        .task {
            if selectedProjectId == nil {
                selectedProjectId = router.selectedProjectId
            }
            await loadProjects()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(phase.title.uppercased())
                .font(STFont.body(11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(STColor.accent)
            Text(phaseHeroTitle)
                .font(STFont.display(26, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
            Text(phaseHeroSubtitle)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            STColor.primary.opacity(0.28),
                            STColor.surface,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(STColor.primary.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var phaseHeroTitle: String {
        switch phase {
        case .preProduction: return "Shape the story"
        case .production: return "Run the shoot"
        case .postProduction: return "Finish & deliver"
        }
    }

    private var phaseHeroSubtitle: String {
        switch phase {
        case .preProduction:
            return "Ideas, scripts, cast, crew, locations, and readiness — with live activity from your project."
        case .production:
            return "Call sheets, continuity, dailies, expenses, and on-set ops in one place."
        case .postProduction:
            return "Music, packaging, and distribution into your catalogue upload pipeline."
        }
    }

    private var insightStrip: some View {
        HStack(spacing: 10) {
            insightChip(title: "Project tools", value: "\(reportCount)", icon: "chart.bar.doc.horizontal")
            insightChip(title: "Marketplaces", value: "\(marketplaceCount)", icon: "person.3.fill")
            insightChip(title: "Projects", value: "\(projects.count)", icon: "folder.fill")
        }
    }

    private func insightChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(STColor.primary)
            Text(value)
                .font(STFont.display(18, weight: .bold))
                .foregroundStyle(STColor.textPrimary)
            Text(title)
                .font(STFont.body(10))
                .foregroundStyle(STColor.textMuted)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active project")
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedProjectTitle)
                            .font(STFont.body(15, weight: .medium))
                            .foregroundStyle(STColor.textPrimary)
                        Text(selectedProjectId == nil
                             ? "Required for activity reports"
                             : "Reports & updates use this project")
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textMuted)
                    }
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
                    systemImage: tool.systemImage,
                    badge: tool.isMarketplaceStyle ? "Market" : "Live"
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
            return "Browse roster & inquire — payments stay on web"
        }
        if selectedProjectId != nil {
            return "Open live activity, versions, and workspace updates"
        }
        return "Select a project above to unlock this report"
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
