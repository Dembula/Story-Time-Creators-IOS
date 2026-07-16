import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = NetworkViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .loading where vm.posts.isEmpty && vm.connections.isEmpty:
                LoadingStateView(message: "Loading network…")
            case .error(let message) where vm.posts.isEmpty && vm.connections.isEmpty:
                ErrorStateView(message: message, retry: { Task { await vm.load(auth: auth) } })
            default:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !vm.connections.isEmpty {
                            SectionHeader(title: "Connections", trailing: "\(vm.connections.count)")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vm.connections) { person in
                                        connectionChip(person)
                                    }
                                }
                            }
                        }

                        SectionHeader(title: "Feed", trailing: vm.posts.isEmpty ? nil : "\(vm.posts.count)")
                        if vm.posts.isEmpty {
                            EmptyStateView(
                                title: "No posts yet",
                                subtitle: "Follow creators and share updates from the web studio.",
                                systemImage: "person.3"
                            )
                        } else {
                            ForEach(vm.posts) { post in
                                postCard(post)
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

    private func connectionChip(_ person: NetworkPerson) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(STColor.primary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String((person.name ?? person.networkHandle ?? "?").prefix(1)).uppercased())
                        .font(STFont.display(18, weight: .bold))
                        .foregroundStyle(STColor.primary)
                }
            Text(person.name ?? person.networkHandle ?? "Creator")
                .font(STFont.body(12, weight: .medium))
                .foregroundStyle(STColor.textPrimary)
                .lineLimit(1)
                .frame(width: 88)
        }
        .padding(10)
        .glassPanel()
    }

    private func postCard(_ post: NetworkPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(post.authorName ?? "Creator")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Spacer()
                if let createdAt = post.createdAt {
                    Text(createdAt)
                        .font(STFont.body(11))
                        .foregroundStyle(STColor.textMuted)
                }
            }
            if let body = post.body, !body.isEmpty {
                Text(body)
                    .font(STFont.body(14))
                    .foregroundStyle(STColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let likes = post.likeCount, likes > 0 {
                Label("\(likes)", systemImage: "heart.fill")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
            }
        }
        .padding(14)
        .glassPanel()
    }
}

@MainActor
private final class NetworkViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var posts: [NetworkPost] = []
    @Published private(set) var connections: [NetworkPerson] = []
    @Published private(set) var state: LoadState = .idle

    private let client = APIClient.shared

    func load(auth: AuthService) async {
        state = .loading
        do {
            let feed = try await loadFeed()
            posts = feed.posts ?? []
            connections = feed.connections ?? []

            if connections.isEmpty {
                connections = try await loadConnections()
            }

            state = .loaded
        } catch {
            state = .error(Self.mapError(error, auth: auth))
        }
    }

    private func loadFeed() async throws -> NetworkFeedResponse {
        if let feed: NetworkFeedResponse = try? await client.get("/api/network/feed") {
            return feed
        }

        var response = NetworkFeedResponse(posts: nil, connections: nil)

        if let postsOnly: NetworkFeedResponse = try? await client.get("/api/network/posts") {
            response = NetworkFeedResponse(
                posts: postsOnly.posts,
                connections: postsOnly.connections
            )
        } else if let soft = try? await softDecodePosts() {
            response = NetworkFeedResponse(posts: soft, connections: nil)
        } else {
            throw APIError.decoding("Could not read network feed.")
        }

        return response
    }

    private func softDecodePosts() async throws -> [NetworkPost] {
        guard let url = client.url("/api/network/posts") else { throw APIError.invalidURL }
        let (data, response) = try await client.session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw APIError.network("Invalid response.") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8))
        }

        if let wrapped = try? JSONDecoder().decode(NetworkFeedResponse.self, from: data),
           let posts = wrapped.posts {
            return posts
        }

        if let posts = try? JSONDecoder().decode([NetworkPost].self, from: data) {
            return posts
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawPosts = json["posts"] as? [[String: Any]] else {
            return []
        }

        return rawPosts.compactMap { dict in
            guard let id = dict["id"] as? String else { return nil }
            return NetworkPost(
                id: id,
                body: dict["body"] as? String,
                authorName: (dict["authorName"] as? String) ?? (dict["author"] as? [String: Any])?["name"] as? String,
                authorId: dict["authorId"] as? String,
                createdAt: dict["createdAt"] as? String,
                likeCount: dict["likeCount"] as? Int
            )
        }
    }

    private func loadConnections() async throws -> [NetworkPerson] {
        guard let url = client.url("/api/network/connections") else { return [] }
        let (data, response) = try await client.session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var people: [NetworkPerson] = []
        for key in ["received", "sent"] {
            guard let rows = json[key] as? [[String: Any]] else { continue }
            for row in rows {
                let nestedKey = key == "received" ? "from" : "to"
                if let user = row[nestedKey] as? [String: Any], let id = user["id"] as? String {
                    people.append(NetworkPerson(
                        id: id,
                        name: user["name"] as? String,
                        headline: nil,
                        image: user["image"] as? String,
                        networkHandle: user["networkHandle"] as? String
                    ))
                }
            }
        }
        return people
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
