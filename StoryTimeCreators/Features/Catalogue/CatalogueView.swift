import SwiftUI

struct CatalogueView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = CatalogueViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .loading where vm.items.isEmpty:
                LoadingStateView(message: "Loading catalogue…")
            case .error(let message) where vm.items.isEmpty:
                ErrorStateView(message: message, retry: { Task { await vm.load(auth: auth) } })
            default:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "My Catalogue", trailing: "\(vm.items.count)")

                        if vm.items.isEmpty {
                            EmptyStateView(
                                title: "No titles yet",
                                subtitle: "Upload a draft from the Upload screen to start building your catalogue.",
                                systemImage: "film.stack"
                            )
                        } else {
                            ForEach(vm.items) { item in
                                catalogueRow(item)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(STColor.background)
        .task { await vm.load(auth: auth) }
        .refreshable { await vm.load(auth: auth) }
    }

    private func catalogueRow(_ item: CatalogueItem) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(STColor.primary.opacity(0.15))
                .frame(width: 56, height: 72)
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(STColor.primary)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let type = item.type {
                        Text(type)
                            .font(STFont.body(11, weight: .medium))
                            .foregroundStyle(STColor.accent)
                    }
                    if let status = item.reviewStatus {
                        Text(status.replacingOccurrences(of: "_", with: " "))
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textMuted)
                    }
                }
                if let createdAt = item.createdAt {
                    Text(createdAt)
                        .font(STFont.body(11))
                        .foregroundStyle(STColor.textMuted)
                }
            }
            Spacer()
        }
        .padding(14)
        .glassPanel()
    }
}

@MainActor
private final class CatalogueViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var items: [CatalogueItem] = []
    @Published private(set) var state: LoadState = .idle

    private let client = APIClient.shared

    func load(auth: AuthService) async {
        state = .loading
        do {
            items = try await fetchContent()
            state = .loaded
        } catch {
            state = .error(Self.mapError(error, auth: auth))
        }
    }

    private func fetchContent() async throws -> [CatalogueItem] {
        if let response: ContentListResponse = try? await client.get("/api/creator/content") {
            return response.all
        }

        guard let url = client.url("/api/creator/content") else { throw APIError.invalidURL }
        let (data, response) = try await client.session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw APIError.network("Invalid response.") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8))
        }

        if let list = try? JSONDecoder().decode([CatalogueItem].self, from: data) {
            return list
        }

        if let wrapped = try? JSONDecoder().decode(ContentListResponse.self, from: data) {
            return wrapped.all
        }

        return []
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
