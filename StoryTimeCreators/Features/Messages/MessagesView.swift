import SwiftUI

private enum MessagesTab: String, CaseIterable, Identifiable {
    case network = "Network"
    case inbox = "Inbox"
    var id: String { rawValue }
}

struct MessagesView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = MessagesHubViewModel()
    @State private var tab: MessagesTab = .network
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Messages", selection: $tab) {
                ForEach(MessagesTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)

            if tab == .network {
                networkPane
            } else {
                inboxPane
            }
        }
        .background(STColor.background)
        .task { await vm.loadAll(auth: auth) }
        .refreshable { await vm.loadAll(auth: auth) }
        .onChange(of: vm.selectedNetworkPeerId) { _, peer in
            if let peer { Task { await vm.loadNetworkThread(peerId: peer, auth: auth) } }
        }
        .onChange(of: vm.selectedInboxPeerId) { _, peer in
            if let peer { Task { await vm.loadInboxThread(peerId: peer, auth: auth) } }
        }
    }

    private var networkPane: some View {
        HStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.networkConversations) { conv in
                        let peer = conv.participants?.first
                        Button {
                            vm.selectedNetworkPeerId = peer?.id
                        } label: {
                            threadRow(
                                title: peer?.label ?? "Creator",
                                preview: conv.lastMessage?.body ?? "No messages yet",
                                selected: vm.selectedNetworkPeerId == peer?.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: vm.selectedNetworkPeerId == nil ? .infinity : 280)
            .overlay(alignment: .trailing) { Rectangle().fill(STColor.border).frame(width: 1) }

            if vm.selectedNetworkPeerId != nil {
                conversationColumn(
                    title: vm.selectedNetworkTitle,
                    empty: vm.networkMessages.isEmpty,
                    bubbles: vm.networkMessages.map { ($0.body ?? "", $0.sender?.id == auth.currentUser?.id, $0.sender?.label) },
                    onSend: {
                        let text = draft
                        draft = ""
                        if let peer = vm.selectedNetworkPeerId {
                            Task { await vm.sendNetwork(peerId: peer, body: text, auth: auth) }
                        }
                    }
                )
            } else {
                EmptyStateView(title: "Network messages", subtitle: "Connect with creators to chat.", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var inboxPane: some View {
        HStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.inboxThreads) { thread in
                        Button { vm.selectedInboxPeerId = thread.peerId } label: {
                            threadRow(title: thread.title, preview: thread.preview, selected: vm.selectedInboxPeerId == thread.peerId)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: vm.selectedInboxPeerId == nil ? .infinity : 280)
            .overlay(alignment: .trailing) { Rectangle().fill(STColor.border).frame(width: 1) }

            if vm.selectedInboxPeerId != nil {
                conversationColumn(
                    title: vm.selectedInboxTitle,
                    empty: vm.inboxMessages.isEmpty,
                    bubbles: vm.inboxMessages.map { ($0.body, $0.senderId == auth.currentUser?.id, $0.sender?.name) },
                    onSend: {
                        let text = draft
                        draft = ""
                        if let peer = vm.selectedInboxPeerId {
                            Task { await vm.sendInbox(peerId: peer, body: text, auth: auth) }
                        }
                    }
                )
            } else {
                EmptyStateView(title: "Marketplace inbox", subtitle: "Booking threads from cast, crew, locations, and catering.", systemImage: "tray")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func threadRow(title: String, preview: String, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(STFont.body(14, weight: .semibold)).foregroundStyle(STColor.textPrimary)
            Text(preview).font(STFont.body(12)).foregroundStyle(STColor.textMuted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(selected ? STColor.primary.opacity(0.14) : STColor.surface))
    }

    private func conversationColumn(
        title: String,
        empty: Bool,
        bubbles: [(String, Bool, String?)],
        onSend: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(STFont.display(16, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .overlay(alignment: .bottom) { Rectangle().fill(STColor.border).frame(height: 1) }

            if empty {
                EmptyStateView(title: "No messages yet", subtitle: "Say hello below.", systemImage: "bubble")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(bubbles.enumerated()), id: \.offset) { _, bubble in
                            messageBubble(text: bubble.0, mine: bubble.1, sender: bubble.2)
                        }
                    }
                    .padding(16)
                }
            }

            HStack(spacing: 10) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.black)
                        .padding(10)
                        .background(Circle().fill(STColor.brandGradient))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
    }

    private func messageBubble(text: String, mine: Bool, sender: String?) -> some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
            if !mine, let sender {
                Text(sender).font(STFont.body(10, weight: .semibold)).foregroundStyle(STColor.textMuted)
            }
            Text(text)
                .font(STFont.body(14))
                .foregroundStyle(mine ? .black : STColor.textPrimary)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(mine ? AnyShapeStyle(STColor.brandGradient) : AnyShapeStyle(STColor.surfaceElevated))
                )
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}

struct InboxThreadRow: Identifiable, Hashable {
    let peerId: String
    let title: String
    let preview: String
    var id: String { peerId }
}

@MainActor
private final class MessagesHubViewModel: ObservableObject {
    @Published var networkConversations: [NetworkConversation] = []
    @Published var networkMessages: [NetworkChatMessage] = []
    @Published var inboxThreads: [InboxThreadRow] = []
    @Published var inboxMessages: [MarketplaceMessage] = []
    @Published var selectedNetworkPeerId: String?
    @Published var selectedInboxPeerId: String?

    var selectedNetworkTitle: String {
        networkConversations
            .first(where: { $0.participants?.contains(where: { $0.id == selectedNetworkPeerId }) == true })?
            .participants?.first?.label ?? "Chat"
    }

    var selectedInboxTitle: String {
        inboxThreads.first(where: { $0.peerId == selectedInboxPeerId })?.title ?? "Messages"
    }

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
