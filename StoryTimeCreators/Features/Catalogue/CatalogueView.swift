import SwiftUI

struct CatalogueView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = CatalogueViewModel()
    @State private var selected: CreatorContentItem?

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
                            EmptyStateView(title: "No titles yet", subtitle: "Upload from the Upload screen.", systemImage: "film.stack")
                        } else {
                            ForEach(vm.items) { item in
                                Button { selected = item } label: { catalogueRow(item) }
                                    .buttonStyle(.plain)
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
        .sheet(item: $selected) { item in
            ContentDetailView(item: item)
        }
    }

    private func catalogueRow(_ item: CreatorContentItem) -> some View {
        HStack(spacing: 14) {
            posterThumb(item.posterUrl)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if let type = item.type {
                        Text(friendlyType(type))
                            .font(STFont.body(11, weight: .medium))
                            .foregroundStyle(STColor.accent)
                    }
                    if let status = item.reviewStatus {
                        Text(status.replacingOccurrences(of: "_", with: " "))
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textMuted)
                    }
                }
                HStack(spacing: 12) {
                    Label("\(item._count?.watchSessions ?? 0)", systemImage: "eye")
                    Label("\(item._count?.comments ?? 0)", systemImage: "bubble.left")
                    if let rating = item.avgRating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                    }
                }
                .font(STFont.body(10))
                .foregroundStyle(STColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(STColor.textMuted)
        }
        .padding(14)
        .glassPanel()
    }

    private func friendlyType(_ raw: String) -> String {
        CatalogueContentType(rawValue: raw)?.label ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    @ViewBuilder
    private func posterThumb(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderPoster
                }
            }
            .frame(width: 56, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholderPoster
        }
    }

    private var placeholderPoster: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(STColor.primary.opacity(0.15))
            .frame(width: 56, height: 72)
            .overlay { Image(systemName: "film").foregroundStyle(STColor.primary) }
    }
}

struct ContentDetailView: View {
    let item: CreatorContentItem
    @Environment(\.dismiss) private var dismiss
    @State private var webDestination: WebDestination?
    @State private var showUploadFee = false
    @State private var payMessage: String?

    private struct WebDestination: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
    }

    private var needsPayment: Bool {
        (item.reviewStatus ?? "").uppercased() == "AWAITING_PAYMENT"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let poster = item.posterUrl, let url = URL(string: poster) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(STColor.primary.opacity(0.15))
                                    .overlay { Image(systemName: "film").foregroundStyle(STColor.primary) }
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Text(item.title).font(STFont.display(22, weight: .bold)).foregroundStyle(STColor.textPrimary)
                    metaGrid

                    if needsPayment {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Payment required")
                                .font(STFont.body(14, weight: .bold))
                                .foregroundStyle(STColor.textPrimary)
                            Text("This title is awaiting the pay-per-film upload fee. Pay with In-App Purchase so it can be submitted for admin review.")
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textSecondary)
                            if let payMessage {
                                Text(payMessage)
                                    .font(STFont.body(12))
                                    .foregroundStyle(STColor.success)
                            }
                            Button {
                                if AppConfig.Features.storeKitBillingEnabled {
                                    showUploadFee = true
                                } else {
                                    webDestination = WebDestination(
                                        url: AppConfig.creatorCatalogueURL,
                                        title: "Complete payment"
                                    )
                                }
                            } label: {
                                Text(AppConfig.Features.storeKitBillingEnabled ? "Pay upload fee (App Store)" : "Open studio payment")
                                    .font(STFont.body(14, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(STColor.brandGradient))
                            }
                        }
                        .padding(14)
                        .glassPanel()
                    }

                    if let description = item.description, !description.isEmpty {
                        Text(description).font(STFont.body(14)).foregroundStyle(STColor.textSecondary)
                    }
                    if let feedback = item.reviewFeedback ?? item.reviewNote, !feedback.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Review feedback").font(STFont.body(12, weight: .semibold)).foregroundStyle(STColor.textMuted)
                            Text(feedback).font(STFont.body(13)).foregroundStyle(STColor.textSecondary)
                        }
                        .padding(12)
                        .glassPanel()
                    }
                    if let seasons = item.seasons, !seasons.isEmpty {
                        SectionHeader(title: "Seasons", trailing: "\(seasons.count)")
                        ForEach(seasons) { season in
                            Text("Season \(season.seasonNumber ?? 0): \(season.title ?? "Untitled")")
                                .font(STFont.body(13))
                                .padding(10)
                                .glassPanel()
                        }
                    }
                }
                .padding(16)
            }
            .background(STColor.background)
            .navigationTitle("Title details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .sheet(item: $webDestination) { dest in
            AuthenticatedWebBrowser(url: dest.url, title: dest.title, mode: .account)
        }
        .sheet(isPresented: $showUploadFee) {
            UploadFeeStoreView(contentId: item.id, displayFee: "Upload fee") {
                payMessage = "Payment recorded. Pull to refresh My Catalogue — status should move to review."
                showUploadFee = false
            }
        }
    }

    private var metaGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(title: "Views", value: "\(item._count?.watchSessions ?? 0)", icon: "eye.fill")
            StatTile(title: "Comments", value: "\(item._count?.comments ?? 0)", icon: "bubble.left.fill")
            StatTile(title: "Ratings", value: "\(item._count?.ratings ?? 0)", icon: "star.fill")
            StatTile(title: "Status", value: (item.reviewStatus ?? "DRAFT").replacingOccurrences(of: "_", with: " "), icon: "checkmark.seal.fill")
        }
    }
}

@MainActor
private final class CatalogueViewModel: ObservableObject {
    enum LoadState: Equatable { case idle, loading, loaded, error(String) }
    @Published private(set) var items: [CreatorContentItem] = []
    @Published private(set) var state: LoadState = .idle
    private let client = APIClient.shared

    func load(auth: AuthService) async {
        state = .loading
        do {
            items = try await fetchContent()
            state = .loaded
        } catch {
            state = .error(mapError(error, auth: auth))
        }
    }

    private func fetchContent() async throws -> [CreatorContentItem] {
        if let list: [CreatorContentItem] = try? await client.get("/api/creator/content") {
            return list
        }
        guard let url = client.url("/api/creator/content") else { throw APIError.invalidURL }
        let (data, response) = try await client.session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.network("Failed to load catalogue.")
        }
        return (try? JSONDecoder().decode([CreatorContentItem].self, from: data)) ?? []
    }

    private func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return error.localizedDescription
    }
}
