import SwiftUI

struct ProjectToolDetailView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService

    let projectId: String
    let tool: ProjectTool

    @StateObject private var vm: ProjectToolDetailViewModel

    init(projectId: String, tool: ProjectTool) {
        self.projectId = projectId
        self.tool = tool
        _vm = StateObject(wrappedValue: ProjectToolDetailViewModel(projectId: projectId, tool: tool))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch vm.state {
                case .loading where vm.displayMode == .loading:
                    LoadingStateView(message: "Loading \(tool.label)…")
                case .error(let message) where vm.displayMode == .loading:
                    ErrorStateView(message: message, retry: { Task { await vm.load(auth: auth) } })
                default:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if tool == .scriptReview {
                                NoPayBanner(
                                    text: "Executive paid script review is disabled in the Creators app. You can view your notes below; paid review checkout is not available on iOS."
                                )
                            }

                            toolContent

                            if vm.displayMode != .loading {
                                Button {
                                    Task { await vm.markInProgress(auth: auth) }
                                } label: {
                                    HStack {
                                        if vm.isMarkingProgress {
                                            ProgressView().tint(.black)
                                        }
                                        Text("Mark in progress")
                                            .font(STFont.body(15, weight: .semibold))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(STColor.brandGradient))
                                }
                                .disabled(vm.isMarkingProgress)
                            }

                            if let progressMessage = vm.progressMessage {
                                Text(progressMessage)
                                    .font(STFont.body(12))
                                    .foregroundStyle(STColor.success)
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
                router.projectPath = [.overview(projectId)]
                router.selectedTool = nil
            } label: {
                Label("Workspace", systemImage: "chevron.left")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.primary)
            }
            Spacer()
            Text(tool.label)
                .font(STFont.display(16, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            Spacer()
            Button {
                Task { await vm.load(auth: auth) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(STColor.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(STColor.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var toolContent: some View {
        switch vm.displayMode {
        case .ideas(let response):
            if let ideas = response.ideas, !ideas.isEmpty {
                ForEach(ideas) { idea in
                    contentCard(title: idea.title ?? "Idea", body: idea.summary ?? idea.notes)
                }
            } else {
                connectedFallback
            }

        case .script(let response):
            if let script = response.script {
                contentCard(title: script.title ?? "Script", body: script.text)
            } else if let versions = response.versions, !versions.isEmpty {
                ForEach(versions) { version in
                    contentCard(title: version.label ?? "Version", body: version.createdAt)
                }
            } else {
                connectedFallback
            }

        case .budget(let response):
            if let total = response.total {
                StatTile(title: "Total Budget", value: formatMoney(total, currency: response.currency), icon: "dollarsign.circle.fill")
            }
            if let lines = response.lines {
                ForEach(lines) { line in
                    contentCard(
                        title: line.category ?? "Line item",
                        body: [line.description, line.amount.map { formatMoney($0, currency: response.currency) }]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                }
            }

        case .schedule(let response):
            if let days = response.days, !days.isEmpty {
                ForEach(days) { day in
                    contentCard(
                        title: day.date ?? "Shoot day",
                        body: [day.location, day.callTime, day.notes].compactMap { $0 }.joined(separator: " · ")
                    )
                }
            } else {
                connectedFallback
            }

        case .casting(let response):
            if let roles = response.roles, !roles.isEmpty {
                ForEach(roles) { role in
                    contentCard(
                        title: role.name,
                        body: [role.importance, role.status, role.description].compactMap { $0 }.joined(separator: " · ")
                    )
                }
            } else {
                connectedFallback
            }

        case .scriptReview(let response):
            let noteBody = response.notes?.body ?? response.notes?.text ?? ""
            if !noteBody.isEmpty {
                contentCard(title: "Your notes", body: noteBody)
            }
            if let requests = response.requests, !requests.isEmpty {
                SectionHeader(title: "Review history")
                ForEach(Array(requests.enumerated()), id: \.offset) { _, request in
                    contentCard(title: request.status ?? "Request", body: request.submittedAt)
                }
            } else if noteBody.isEmpty {
                connectedFallback
            }

        case .summary(let lines):
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .glassPanel()
            }

        case .connected:
            connectedFallback

        case .loading:
            EmptyView()
        }
    }

    private var connectedFallback: some View {
        VStack(spacing: 10) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(STColor.primary)
            Text("Connected to API")
                .font(STFont.display(17, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            Text("Pull to refresh or tap the refresh button to reload this tool.")
                .font(STFont.body(13))
                .foregroundStyle(STColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassPanel()
    }

    private func contentCard(title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(STFont.body(15, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            if let body, !body.isEmpty {
                Text(body)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func formatMoney(_ amount: Double, currency: String?) -> String {
        let symbol = (currency ?? "ZAR").uppercased() == "ZAR" ? "R" : (currency ?? "")
        return "\(symbol)\(String(format: "%.2f", amount))"
    }
}

// MARK: - View Model

@MainActor
final class ProjectToolDetailViewModel: ObservableObject {
    enum DisplayMode {
        case loading
        case ideas(ProjectIdeasResponse)
        case script(ProjectScriptResponse)
        case budget(BudgetResponse)
        case schedule(ScheduleResponse)
        case casting(CastingRolesResponse)
        case scriptReview(ScriptReviewAPIResponse)
        case summary([String])
        case connected
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var displayMode: DisplayMode = .loading
    @Published private(set) var state: LoadState = .idle
    @Published var isMarkingProgress = false
    @Published var progressMessage: String?

    let projectId: String
    let tool: ProjectTool
    private let client = APIClient.shared

    init(projectId: String, tool: ProjectTool) {
        self.projectId = projectId
        self.tool = tool
    }

    func load(auth: AuthService) async {
        state = .loading
        displayMode = .loading
        progressMessage = nil

        let path = "/api/creator/projects/\(projectId)/\(tool.apiPathSegment)"

        do {
            if tool == .ideaDevelopment, let response: ProjectIdeasResponse = try? await client.get(path) {
                displayMode = .ideas(response)
            } else if tool == .scriptWriting, let response: ProjectScriptResponse = try? await client.get(path) {
                displayMode = .script(response)
            } else if tool == .budgetBuilder, let response: BudgetResponse = try? await client.get(path) {
                displayMode = .budget(response)
            } else if tool == .productionScheduling, let response: ScheduleResponse = try? await client.get(path) {
                displayMode = .schedule(response)
            } else if tool == .castingPortal, let response: CastingRolesResponse = try? await client.get(path) {
                displayMode = .casting(response)
            } else if tool == .scriptReview, let response: ScriptReviewAPIResponse = try? await client.get(path) {
                displayMode = .scriptReview(response)
            } else if let summary = try await fetchSummary(path: path) {
                displayMode = .summary(summary)
            } else {
                _ = try await client.get(path) as EmptyResponse
                displayMode = .connected
            }
            state = .loaded
        } catch {
            if let summary = try? await fetchSummary(path: path) {
                displayMode = .summary(summary)
                state = .loaded
            } else {
                state = .error(Self.mapError(error, auth: auth))
                displayMode = .connected
            }
        }
    }

    func markInProgress(auth: AuthService) async {
        isMarkingProgress = true
        progressMessage = nil
        defer { isMarkingProgress = false }

        let body = ToolProgressBody(
            phase: tool.phase.rawValue,
            toolId: tool.rawValue,
            status: "IN_PROGRESS",
            percent: 50
        )

        do {
            _ = try await client.patch(
                "/api/creator/projects/\(projectId)/tools/progress",
                body: body
            ) as ToolProgressPatchResponse
            progressMessage = "Marked \(tool.label) as in progress."
        } catch {
            progressMessage = Self.mapError(error, auth: auth)
        }
    }

    private func fetchSummary(path: String) async throws -> [String]? {
        guard let url = client.url(path) else { return nil }
        let (data, response) = try await client.session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return Self.flattenJSON(json, prefix: "", limit: 24)
    }

    private static func flattenJSON(_ object: Any, prefix: String, limit: Int) -> [String] {
        var lines: [String] = []
        func walk(_ value: Any, key: String) {
            guard lines.count < limit else { return }
            switch value {
            case let dict as [String: Any]:
                if dict.isEmpty {
                    lines.append("\(key): {}")
                } else {
                    for (childKey, child) in dict.sorted(by: { $0.key < $1.key }) {
                        walk(child, key: key.isEmpty ? childKey : "\(key).\(childKey)")
                    }
                }
            case let array as [Any]:
                lines.append("\(key): [\(array.count) items]")
            case let string as String:
                lines.append("\(key): \(string)")
            case let number as NSNumber:
                lines.append("\(key): \(number)")
            case is NSNull:
                lines.append("\(key): null")
            default:
                lines.append("\(key): \(String(describing: value))")
            }
        }
        walk(object, key: prefix)
        return lines.isEmpty ? nil : lines
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

// MARK: - API Types

private struct ToolProgressBody: Encodable {
    var phase: String
    var toolId: String
    var status: String
    var percent: Double
}

private struct ToolProgressPatchResponse: Decodable {
    var progress: ToolProgress?
}

struct ScriptReviewAPIResponse: Decodable {
    var notes: ScriptReviewNotes?
    var requests: [ScriptReviewRequestItem]?
}

struct ScriptReviewNotes: Decodable {
    var body: String?
    var text: String?
}

struct ScriptReviewRequestItem: Decodable {
    var status: String?
    var submittedAt: String?
}
