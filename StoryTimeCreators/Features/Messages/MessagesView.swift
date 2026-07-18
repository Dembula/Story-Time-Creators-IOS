import SwiftUI

private enum MessagesTab: String, CaseIterable, Identifiable {
    case network = "Network"
    case inbox = "Inbox"
    var id: String { rawValue }
}

enum MessageThreadRoute: Identifiable, Hashable {
    case network(peerId: String, title: String)
    case inbox(peerId: String, title: String)

    var id: String {
        switch self {
        case .network(let peer, _): return "n-\(peer)"
        case .inbox(let peer, _): return "i-\(peer)"
        }
    }

    var title: String {
        switch self {
        case .network(_, let t), .inbox(_, let t): return t
        }
    }

    var peerId: String {
        switch self {
        case .network(let p, _), .inbox(let p, _): return p
        }
    }

    var isNetwork: Bool {
        if case .network = self { return true }
        return false
    }
}

struct MessagesView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = MessagesHubViewModel()
    @State private var tab: MessagesTab = .network
    @State private var route: MessageThreadRoute?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Messages", selection: $tab) {
                    ForEach(MessagesTab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(16)

                threadList
            }
            .background(STColor.background)
            .navigationDestination(item: $route) { route in
                ConversationDetailView(route: route, vm: vm)
                    .environmentObject(auth)
            }
        }
        .task { await vm.loadAll(auth: auth) }
    }

    @ViewBuilder
    private var threadList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if tab == .network {
                    if vm.networkConversations.isEmpty {
                        EmptyStateView(
                            title: "No conversations yet",
                            subtitle: "Connect with creators, then message them from their profile.",
                            systemImage: "bubble.left.and.bubble.right"
                        )
                        .padding(.top, 40)
                    }
                    ForEach(vm.networkConversations) { conv in
                        let peer = conv.participants?.first
                        Button {
                            route = .network(peerId: peer?.id ?? "", title: peer?.label ?? "Creator")
                        } label: {
                            threadRow(
                                title: peer?.label ?? "Creator",
                                preview: conv.lastMessage?.body ?? "No messages yet"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    if vm.inboxThreads.isEmpty {
                        EmptyStateView(
                            title: "Marketplace inbox is empty",
                            subtitle: "Booking threads from cast, crew, locations, and catering show up here.",
                            systemImage: "tray"
                        )
                        .padding(.top, 40)
                    }
                    ForEach(vm.inboxThreads) { thread in
                        Button {
                            route = .inbox(peerId: thread.peerId, title: thread.title)
                        } label: {
                            threadRow(title: thread.title, preview: thread.preview)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await vm.loadAll(auth: auth) }
    }

    private func threadRow(title: String, preview: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(STColor.primary.opacity(0.18))
                .frame(width: 46, height: 46)
                .overlay {
                    Text(String(title.prefix(1)).uppercased())
                        .font(STFont.display(18, weight: .bold))
                        .foregroundStyle(STColor.primary)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                    .lineLimit(1)
                Text(preview)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(STColor.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel()
    }
}

// MARK: - Full-screen conversation

private struct ConversationDetailView: View {
    @EnvironmentObject private var auth: AuthService
    @ObservedObject var vm: MessagesHubViewModel
    let route: MessageThreadRoute

    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            messagesScroll
            inputBar
        }
        .background(STColor.background)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadThread() }
    }

    @ViewBuilder
    private var messagesScroll: some View {
        if isEmpty {
            EmptyStateView(title: "No messages yet", subtitle: "Say hello below.", systemImage: "bubble")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if route.isNetwork {
                            ForEach(vm.networkMessages) { msg in
                                bubble(text: msg.body ?? "", mine: msg.sender?.id == auth.currentUser?.id)
                                    .id(msg.id)
                            }
                        } else {
                            ForEach(vm.inboxMessages) { msg in
                                bubble(text: msg.body, mine: msg.senderId == auth.currentUser?.id)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messageCount) { _, _ in
                    withAnimation { proxy.scrollTo(lastMessageId, anchor: .bottom) }
                }
                .onAppear {
                    if let last = lastMessageId { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(STColor.surfaceElevated))
            Button {
                let text = draft
                draft = ""
                Task { await send(text) }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.black)
                    .padding(12)
                    .background(Circle().fill(STColor.brandGradient))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .overlay(alignment: .top) { Rectangle().fill(STColor.border).frame(height: 1) }
    }

    private func bubble(text: String, mine: Bool) -> some View {
        Text(text)
            .font(STFont.body(15))
            .foregroundStyle(mine ? .black : STColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(mine ? AnyShapeStyle(STColor.brandGradient) : AnyShapeStyle(STColor.surfaceElevated))
            )
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private var isEmpty: Bool {
        route.isNetwork ? vm.networkMessages.isEmpty : vm.inboxMessages.isEmpty
    }

    private var messageCount: Int {
        route.isNetwork ? vm.networkMessages.count : vm.inboxMessages.count
    }

    private var lastMessageId: String? {
        route.isNetwork ? vm.networkMessages.last?.id : vm.inboxMessages.last?.id
    }

    private func loadThread() async {
        if route.isNetwork {
            await vm.loadNetworkThread(peerId: route.peerId, auth: auth)
        } else {
            await vm.loadInboxThread(peerId: route.peerId, auth: auth)
        }
    }

    private func send(_ text: String) async {
        if route.isNetwork {
            await vm.sendNetwork(peerId: route.peerId, body: text, auth: auth)
        } else {
            await vm.sendInbox(peerId: route.peerId, body: text, auth: auth)
        }
    }
}

struct InboxThreadRow: Identifiable, Hashable {
    let peerId: String
    let title: String
    let preview: String
    var id: String { peerId }
}

// MARK: - Standalone network chat (used from a creator profile)

struct NetworkChatSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    let peerId: String
    let peerName: String

    @StateObject private var vm = NetworkChatViewModel()
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = vm.error {
                    Text(error)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(STColor.danger.opacity(0.1))
                }

                if vm.messages.isEmpty {
                    EmptyStateView(
                        title: "No messages yet",
                        subtitle: "Say hello to \(peerName).",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(vm.messages) { msg in
                                    let mine = msg.sender?.id == auth.currentUser?.id
                                    bubble(text: msg.body ?? "", mine: mine)
                                        .id(msg.id)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: vm.messages.count) { _, _ in
                            if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Message", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                    Button {
                        let text = draft
                        draft = ""
                        Task { await vm.send(peerId: peerId, body: text, auth: auth) }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.black)
                            .padding(10)
                            .background(Circle().fill(STColor.brandGradient))
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
                }
                .padding(16)
            }
            .background(STColor.background)
            .navigationTitle(peerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task { await vm.load(peerId: peerId, auth: auth) }
    }

    private func bubble(text: String, mine: Bool) -> some View {
        Text(text)
            .font(STFont.body(14))
            .foregroundStyle(mine ? .black : STColor.textPrimary)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(mine ? AnyShapeStyle(STColor.brandGradient) : AnyShapeStyle(STColor.surfaceElevated))
            )
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}

@MainActor
private final class NetworkChatViewModel: ObservableObject {
    @Published var messages: [NetworkChatMessage] = []
    @Published var error: String?
    @Published var isSending = false

    private let client = APIClient.shared

    func load(peerId: String, auth: AuthService) async {
        do {
            let thread: NetworkChatThreadResponse = try await client.get("/api/network/chats/\(peerId)")
            messages = thread.messages ?? []
            error = nil
        } catch let api as APIError {
            if case .forbidden = api {
                error = "You need an accepted connection with this creator before you can message them."
            } else {
                error = api.errorDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func send(peerId: String, body: String, auth: AuthService) async {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        defer { isSending = false }
        struct SendBody: Encodable { var body: String }
        do {
            let msg: NetworkChatMessage = try await client.post("/api/network/chats/\(peerId)", body: SendBody(body: body))
            messages.append(msg)
            error = nil
        } catch let api as APIError {
            if case .forbidden = api {
                error = "You need an accepted connection with this creator before you can message them."
            } else {
                error = api.errorDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
private final class MessagesHubViewModel: ObservableObject {
    @Published var networkConversations: [NetworkConversation] = []
    @Published var networkMessages: [NetworkChatMessage] = []
    @Published var inboxThreads: [InboxThreadRow] = []
    @Published var inboxMessages: [MarketplaceMessage] = []

    private let client = APIClient.shared

    func loadAll(auth: AuthService) async {
        if let chats: NetworkChatsResponse = try? await client.get("/api/network/chats") {
            networkConversations = chats.conversations ?? []
        }
        if let messages: [MarketplaceMessage] = try? await client.get("/api/messages") {
            inboxThreads = buildInboxThreads(from: messages, myId: auth.currentUser?.id)
        }
    }

    func loadNetworkThread(peerId: String, auth: AuthService) async {
        if let thread: NetworkChatThreadResponse = try? await client.get("/api/network/chats/\(peerId)") {
            networkMessages = thread.messages ?? []
        }
    }

    func loadInboxThread(peerId: String, auth: AuthService) async {
        if let messages: [MarketplaceMessage] = try? await client.get(
            "/api/messages",
            query: [URLQueryItem(name: "peerId", value: peerId)]
        ) {
            inboxMessages = messages
        }
    }

    func sendNetwork(peerId: String, body: String, auth: AuthService) async {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        struct SendBody: Encodable { var body: String }
        if let msg: NetworkChatMessage = try? await client.post("/api/network/chats/\(peerId)", body: SendBody(body: body)) {
            networkMessages.append(msg)
        }
    }

    func sendInbox(peerId: String, body: String, auth: AuthService) async {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let payload = SendMarketplaceMessageBody(body: body, receiverId: peerId)
        if let msg: MarketplaceMessage = try? await client.post("/api/messages", body: payload) {
            inboxMessages.append(msg)
        }
    }

    private func buildInboxThreads(from messages: [MarketplaceMessage], myId: String?) -> [InboxThreadRow] {
        guard let myId else { return [] }
        var map: [String: InboxThreadRow] = [:]
        for msg in messages {
            let peer = msg.senderId == myId ? msg.receiverId : msg.senderId
            let name = msg.senderId == myId ? msg.receiver?.name : msg.sender?.name
            let context = msg.locationBooking?.location?.name
                ?? msg.crewTeamRequest?.crewTeam?.companyName
                ?? msg.castingInquiry?.agency?.agencyName
                ?? msg.request?.equipment?.companyName
            map[peer] = InboxThreadRow(
                peerId: peer,
                title: name ?? context ?? "Conversation",
                preview: msg.body
            )
        }
        return map.values.sorted { $0.title < $1.title }
    }
}
