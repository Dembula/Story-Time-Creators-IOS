import SwiftUI

private enum NetworkTab: String, CaseIterable, Identifiable {
    case feed = "Feed"
    case discover = "Discover"
    case connections = "Connections"
    var id: String { rawValue }
}

struct NetworkView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = NetworkHubViewModel()
    @State private var tab: NetworkTab = .feed
    @State private var discoverQuery = ""
    @State private var composeText = ""
    @State private var profileRoute: ProfileRoute?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Network", selection: $tab) {
                ForEach(NetworkTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Group {
                switch tab {
                case .feed: feedTab
                case .discover: discoverTab
                case .connections: connectionsTab
                }
            }
        }
        .background(STColor.background)
        .task { await vm.loadAll(auth: auth) }
        .refreshable { await vm.loadAll(auth: auth) }
        .sheet(item: $profileRoute) { route in
            CreatorProfileView(userId: route.id)
                .environmentObject(auth)
        }
    }

    private var feedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                composeBox
                if vm.posts.isEmpty && vm.state != .loading {
                    EmptyStateView(title: "Your feed is quiet", subtitle: "Follow creators in Discover to see their updates here.", systemImage: "person.3")
                }
                ForEach(vm.posts) { post in
                    postCard(post)
                }
            }
            .padding(16)
        }
    }

    private var composeBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share an update")
                .font(STFont.body(13, weight: .semibold))
                .foregroundStyle(STColor.textMuted)
            TextField("What's happening on your production?", text: $composeText, axis: .vertical)
                .lineLimit(2...5)
                .font(STFont.body(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
            Button {
                let text = composeText
                composeText = ""
                Task { await vm.createPost(body: text, auth: auth) }
            } label: {
                Text("Post")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(STColor.brandGradient))
            }
            .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isPosting)
        }
        .padding(14)
        .glassPanel()
    }

    private func postCard(_ post: EnrichedNetworkPost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { profileRoute = ProfileRoute(id: post.authorId ?? post.author?.id ?? "") } label: {
                HStack(spacing: 10) {
                    avatar(name: post.author?.label ?? "C", imageURL: post.author?.image)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.author?.label ?? "Creator")
                            .font(STFont.body(14, weight: .semibold))
                            .foregroundStyle(STColor.textPrimary)
                        if let headline = post.author?.headline {
                            Text(headline)
                                .font(STFont.body(11))
                                .foregroundStyle(STColor.textMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if let date = post.createdDate {
                        Text(relative(date))
                            .font(STFont.body(10))
                            .foregroundStyle(STColor.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            if let body = post.body, !body.isEmpty {
                Text(body)
                    .font(STFont.body(14))
                    .foregroundStyle(STColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let project = post.project?.title {
                Label(project, systemImage: "folder.fill")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.primary)
            }

            HStack(spacing: 16) {
                Label("\(post.likeCount ?? 0)", systemImage: post.likedByViewer == true ? "heart.fill" : "heart")
                    .font(STFont.body(12))
                    .foregroundStyle(post.likedByViewer == true ? STColor.primary : STColor.textMuted)
                Label("\(post.commentCount ?? 0)", systemImage: "bubble.right")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private var discoverTab: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(STColor.textMuted)
                TextField("Search creators", text: $discoverQuery)
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await vm.searchCreators(query: discoverQuery, auth: auth) } }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
            .padding(16)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.discovered) { creator in
                        discoverRow(creator)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onAppear { Task { await vm.searchCreators(query: "", auth: auth) } }
    }

    private func discoverRow(_ creator: DiscoverCreator) -> some View {
        HStack(spacing: 12) {
            Button { profileRoute = ProfileRoute(id: creator.id) } label: {
                avatar(name: creator.label, imageURL: creator.image)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(creator.label)
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                if let headline = creator.headline ?? creator.location {
                    Text(headline)
                        .font(STFont.body(11))
                        .foregroundStyle(STColor.textMuted)
                        .lineLimit(1)
                }
                Text("\(creator.followerCount ?? 0) followers")
                    .font(STFont.body(10))
                    .foregroundStyle(STColor.textSecondary)
            }
            Spacer()
            VStack(spacing: 6) {
                Button {
                    Task { await vm.toggleFollow(userId: creator.id, auth: auth) }
                } label: {
                    Text(creator.following == true ? "Following" : "Follow")
                        .font(STFont.body(11, weight: .semibold))
                        .foregroundStyle(creator.following == true ? STColor.textPrimary : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(creator.following == true ? STColor.surfaceElevated : STColor.primary))
                }
                if creator.connectionStatus != "ACCEPTED" {
                    Button {
                        Task { await vm.connect(userId: creator.id, auth: auth) }
                    } label: {
                        Text(connectionLabel(creator.connectionStatus))
                            .font(STFont.body(10, weight: .medium))
                            .foregroundStyle(STColor.accent)
                    }
                }
            }
        }
        .padding(12)
        .glassPanel()
    }

    private var connectionsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let received = vm.connections.received, !received.isEmpty {
                    SectionHeader(title: "Requests received", trailing: "\(received.count)")
                    ForEach(received) { req in
                        connectionRequestRow(req, incoming: true)
                    }
                }
                if let sent = vm.connections.sent, !sent.isEmpty {
                    SectionHeader(title: "Sent requests", trailing: "\(sent.count)")
                    ForEach(sent) { req in
                        connectionRequestRow(req, incoming: false)
                    }
                }
                if (vm.connections.received ?? []).isEmpty && (vm.connections.sent ?? []).isEmpty {
                    EmptyStateView(title: "No connection requests", subtitle: "Connect with creators from Discover.", systemImage: "person.2")
                }
            }
            .padding(16)
        }
    }

    private func connectionRequestRow(_ req: ConnectionRequestRow, incoming: Bool) -> some View {
        let person = incoming ? req.from : req.to
        return HStack {
            avatar(name: person?.label ?? "?", imageURL: person?.image)
            VStack(alignment: .leading, spacing: 4) {
                Text(person?.label ?? "Creator")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Text(req.message ?? req.status ?? "")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if incoming && req.status == "PENDING" {
                HStack(spacing: 8) {
                    Button { Task { await vm.respondConnection(requestId: req.id, accept: true, auth: auth) } } label: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(STColor.success)
                    }
                    Button { Task { await vm.respondConnection(requestId: req.id, accept: false, auth: auth) } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(STColor.danger)
                    }
                }
            }
        }
        .padding(12)
        .glassPanel()
    }

    private func avatar(name: String, imageURL: String?) -> some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initialsAvatar(name)
                    }
                }
            } else {
                initialsAvatar(name)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private func initialsAvatar(_ name: String) -> some View {
        Circle()
            .fill(STColor.primary.opacity(0.2))
            .overlay {
                Text(String(name.prefix(1)).uppercased())
                    .font(STFont.display(16, weight: .bold))
                    .foregroundStyle(STColor.primary)
            }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func connectionLabel(_ status: String?) -> String {
        switch status {
        case "PENDING_SENT": return "Pending"
        case "PENDING_RECEIVED": return "Respond"
        default: return "Connect"
        }
    }
}

private struct ProfileRoute: Identifiable {
    let id: String
}

// MARK: - Profile

struct CreatorProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    let userId: String
    @StateObject private var vm = CreatorProfileViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = vm.profile {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) {
                            Circle().fill(STColor.primary.opacity(0.2)).frame(width: 72, height: 72)
                                .overlay {
                                    Text(String((profile.user?.label ?? "C").prefix(1)))
                                        .font(STFont.display(28, weight: .bold))
                                        .foregroundStyle(STColor.primary)
                                }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.user?.label ?? "Creator")
                                    .font(STFont.display(20, weight: .bold))
                                if let headline = profile.user?.headline {
                                    Text(headline).font(STFont.body(13)).foregroundStyle(STColor.textSecondary)
                                }
                                Text("\(profile.followerCount ?? 0) followers · \(profile.followingCount ?? 0) following")
                                    .font(STFont.body(11)).foregroundStyle(STColor.textMuted)
                            }
                        }
                        if let bio = profile.user?.bio, !bio.isEmpty {
                            Text(bio).font(STFont.body(14)).foregroundStyle(STColor.textSecondary)
                        }
                            HStack(spacing: 10) {
                            Button { Task { await vm.toggleFollow(userId: userId, auth: auth) } } label: {
                                Text(profile.following == true ? "Following" : "Follow")
                                    .font(STFont.body(14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(profile.following == true ? STColor.textPrimary : .black)
                                    .background(
                                        Capsule().fill(
                                            profile.following == true
                                                ? AnyShapeStyle(STColor.surfaceElevated)
                                                : AnyShapeStyle(STColor.brandGradient)
                                        )
                                    )
                            }
                            if profile.connectionStatus != "ACCEPTED" {
                                Button { Task { await vm.connect(userId: userId, auth: auth) } } label: {
                                    Text("Connect")
                                        .font(STFont.body(14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Capsule().stroke(STColor.primary, lineWidth: 1))
                                        .foregroundStyle(STColor.primary)
                                }
                            }
                        }
                        if let contents = profile.contents, !contents.isEmpty {
                            SectionHeader(title: "Published titles")
                            ForEach(contents) { item in
                                Text(item.title).font(STFont.body(14)).foregroundStyle(STColor.textPrimary).padding(10).glassPanel()
                            }
                        }
                        if let posts = profile.posts, !posts.isEmpty {
                            SectionHeader(title: "Posts")
                            ForEach(posts.prefix(10)) { post in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(post.body ?? "").font(STFont.body(13)).foregroundStyle(STColor.textSecondary)
                                    Text(DateParser.display(post.createdAt)).font(STFont.body(10)).foregroundStyle(STColor.textMuted)
                                }
                                .padding(10).glassPanel()
                            }
                        }
                    }
                    .padding(16)
                } else if vm.isLoading {
                    LoadingStateView()
                }
            }
            .background(STColor.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task { await vm.load(userId: userId, auth: auth) }
    }
}

@MainActor
private final class NetworkHubViewModel: ObservableObject {
    @Published var posts: [EnrichedNetworkPost] = []
    @Published var discovered: [DiscoverCreator] = []
    @Published var connections = NetworkConnectionsResponse(received: nil, sent: nil)
    @Published var state: LoadState = .idle
    @Published var isPosting = false

    enum LoadState: Equatable { case idle, loading, loaded, error(String) }

    private let client = APIClient.shared

    func loadAll(auth: AuthService) async {
        state = .loading
        do {
            async let feed: NetworkPostsResponse = client.get(
                "/api/network/posts",
                query: [URLQueryItem(name: "mode", value: "feed"), URLQueryItem(name: "limit", value: "30")]
            )
            async let conn: NetworkConnectionsResponse = client.get("/api/network/connections")
            let (f, c) = try await (feed, conn)
            posts = f.posts ?? []
            connections = c
            state = .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func searchCreators(query: String, auth: AuthService) async {
        var q = [URLQueryItem]()
        if !query.isEmpty { q.append(URLQueryItem(name: "q", value: query)) }
        if let response: NetworkCreatorsResponse = try? await client.get("/api/network/creators", query: q) {
            discovered = response.creators ?? []
        }
    }

    func createPost(body: String, auth: AuthService) async {
        isPosting = true
        defer { isPosting = false }
        if let post: EnrichedNetworkPost = try? await client.post(
            "/api/network/posts",
            body: CreateNetworkPostBody(body: body)
        ) {
            posts.insert(post, at: 0)
        }
    }

    func toggleFollow(userId: String, auth: AuthService) async {
        if let idx = discovered.firstIndex(where: { $0.id == userId }) {
            let following = discovered[idx].following == true
            if following {
                _ = try? await client.delete("/api/network/follow/\(userId)") as FollowResponse
                discovered[idx].following = false
            } else {
                _ = try? await client.post("/api/network/follow/\(userId)") as FollowResponse
                discovered[idx].following = true
            }
        }
    }

    func connect(userId: String, auth: AuthService) async {
        struct StatusResponse: Decodable { var status: String? }
        _ = try? await client.post("/api/network/connect/\(userId)", body: ConnectBody(message: nil)) as StatusResponse
        await searchCreators(query: discoverQueryFallback(), auth: auth)
    }

    func respondConnection(requestId: String, accept: Bool, auth: AuthService) async {
        struct PatchBody: Encodable { var action: String }
        _ = try? await client.patch(
            "/api/network/connections/\(requestId)",
            body: PatchBody(action: accept ? "accept" : "decline")
        ) as OkResponse
        await loadAll(auth: auth)
    }

    private func discoverQueryFallback() -> String { "" }
}

private struct FollowResponse: Decodable { var following: Bool? }

@MainActor
private final class CreatorProfileViewModel: ObservableObject {
    @Published var profile: NetworkProfileResponse?
    @Published var isLoading = false
    private let client = APIClient.shared

    func load(userId: String, auth: AuthService) async {
        isLoading = true
        defer { isLoading = false }
        profile = try? await client.get("/api/network/profile/\(userId)")
    }

    func toggleFollow(userId: String, auth: AuthService) async {
        let following = profile?.following == true
        if following {
            _ = try? await client.delete("/api/network/follow/\(userId)") as FollowResponse
            profile?.following = false
        } else {
            _ = try? await client.post("/api/network/follow/\(userId)") as FollowResponse
            profile?.following = true
        }
    }

    func connect(userId: String, auth: AuthService) async {
        struct StatusResponse: Decodable { var status: String? }
        _ = try? await client.post("/api/network/connect/\(userId)", body: ConnectBody(message: nil)) as StatusResponse
        await load(userId: userId, auth: auth)
    }
}
