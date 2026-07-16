import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = MessagesViewModel()
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 0) {
            threadList
                .frame(maxWidth: vm.selectedThread == nil ? .infinity : 280)

            if let thread = vm.selectedThread {
                conversationPane(thread)
            } else if !vm.threads.isEmpty {
                EmptyStateView(
                    title: "Select a thread",
                    subtitle: "Choose a conversation to read and reply.",
                    systemImage: "bubble.left.and.bubble.right"
                )
                .frame(maxWidth: .infinity)
            }
        }
        .background(STColor.background)
        .task { await vm.load(auth: auth) }
        .refreshable { await vm.load(auth: auth) }
    }

    private var threadList: some View {
        Group {
            switch vm.state {
            case .loading where vm.threads.isEmpty:
                LoadingStateView(message: "Loading messages…")
            case .error(let message) where vm.threads.isEmpty:
                ErrorStateView(message: message, retry: { Task { await vm.load(auth: auth) } })
            default:
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Inbox", trailing: "\(vm.threads.count)")
                        .padding(16)

                    if vm.threads.isEmpty {
                        EmptyStateView(
                            title: "No messages",
                            subtitle: "Marketplace and direct messages appear here.",
                            systemImage: "tray"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(vm.threads) { thread in
                                    threadRow(thread)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(STColor.border).frame(width: 1)
        }
    }

    private func threadRow(_ thread: MessageThread) -> some View {
        Button {
            Task { await vm.selectThread(thread, auth: auth) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.counterpartName ?? thread.subject ?? "Conversation")
                        .font(STFont.body(14, weight: .semibold))
                        .foregroundStyle(STColor.textPrimary)
                        .lineLimit(1)
                    if let preview = thread.preview, !preview.isEmpty {
                        Text(preview)
                            .font(STFont.body(12))
                            .foregroundStyle(STColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if let unread = thread.unreadCount, unread > 0 {
                    Text("\(unread)")
                        .font(STFont.mono(11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(STColor.primary))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(vm.selectedThread?.id == thread.id ? STColor.primary.opacity(0.12) : STColor.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private func conversationPane(_ thread: MessageThread) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(thread.counterpartName ?? thread.subject ?? "Messages")
                    .font(STFont.display(16, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(STColor.border).frame(height: 1)
            }

            if vm.isLoadingMessages {
                LoadingStateView(message: "Loading conversation…")
            } else if vm.messages.isEmpty {
                EmptyStateView(
                    title: "No messages yet",
                    subtitle: "Send the first message below.",
                    systemImage: "bubble"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.messages) { message in
                            messageBubble(message)
                        }
                    }
                    .padding(16)
                }
            }

            HStack(spacing: 10) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(STFont.body(14))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))

                Button {
                    let text = draft
                    draft = ""
                    Task { await vm.send(text: text, auth: auth) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.black)
                        .padding(10)
                        .background(Circle().fill(STColor.brandGradient))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
            }
            .padding(12)
            .background(STColor.background)
            .overlay(alignment: .top) {
                Rectangle().fill(STColor.border).frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = message.senderName {
                Text(name)
                    .font(STFont.body(11, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
            }
            Text(message.text)
                .font(STFont.body(14))
                .foregroundStyle(STColor.textPrimary)
            if let createdAt = message.createdAt {
                Text(createdAt)
                    .font(STFont.body(10))
                    .foregroundStyle(STColor.textMuted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}

@MainActor
private final class MessagesViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var threads: [MessageThread] = []
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var selectedThread: MessageThread?
    @Published private(set) var state: LoadState = .idle
    @Published var isLoadingMessages = false
    @Published var isSending = false

    private let client = APIClient.shared
    private var threadContext: [String: String] = [:]

    func load(auth: AuthService) async {
        state = .loading
        do {
            if let response: MessagesResponse = try? await client.get("/api/messages"),
               let threads = response.threads, !threads.isEmpty {
                self.threads = threads
                if let embedded = response.messages {
                    messages = embedded
                }
            } else {
                let raw = try await loadRawMessages()
                threads = Self.buildThreads(from: raw, meId: auth.currentUser?.id)
            }
            state = .loaded
        } catch {
            state = .error(Self.mapError(error, auth: auth))
        }
    }

    func selectThread(_ thread: MessageThread, auth: AuthService) async {
        selectedThread = thread
        threadContext = thread.context
        isLoadingMessages = true
        defer { isLoadingMessages = false }

        do {
            messages = try await loadMessages(for: thread, auth: auth)
        } catch {
            messages = []
        }
    }

    func send(text: String, auth: AuthService) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, selectedThread != nil else { return }

        isSending = true
        defer { isSending = false }

        var body = SendMessageBody(body: trimmed)
        if let receiverId = threadContext["receiverId"] {
            body.receiverId = receiverId
        }
        if let requestId = threadContext["requestId"] {
            body.requestId = requestId
        }
        if let locationBookingId = threadContext["locationBookingId"] {
            body.locationBookingId = locationBookingId
        }
        if let crewTeamRequestId = threadContext["crewTeamRequestId"] {
            body.crewTeamRequestId = crewTeamRequestId
        }
        if let castingInquiryId = threadContext["castingInquiryId"] {
            body.castingInquiryId = castingInquiryId
        }
        if let cateringBookingId = threadContext["cateringBookingId"] {
            body.cateringBookingId = cateringBookingId
        }

        do {
            let sent: ChatMessage = try await client.post("/api/messages", body: body)
            messages.append(sent)
            await load(auth: auth)
        } catch {
            _ = Self.mapError(error, auth: auth)
        }
    }

    private func loadRawMessages() async throws -> [RawMessage] {
        guard let url = client.url("/api/messages") else { throw APIError.invalidURL }
        let (data, response) = try await client.session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw APIError.network("Invalid response.") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8))
        }
        return (try? JSONDecoder().decode([RawMessage].self, from: data)) ?? []
    }

    private func loadMessages(for thread: MessageThread, auth: AuthService) async throws -> [ChatMessage] {
        var query: [URLQueryItem] = []
        for (key, value) in thread.context {
            query.append(URLQueryItem(name: key, value: value))
        }

        if query.isEmpty, let peerId = thread.context["receiverId"] {
            query = [URLQueryItem(name: "peerId", value: peerId)]
        }

        if !query.isEmpty {
            let raw: [RawMessage] = try await client.get("/api/messages", query: query)
            return raw.map(\.asChatMessage)
        }

        return messages.filter { _ in thread.id == selectedThread?.id }
    }

    private static func buildThreads(from messages: [RawMessage], meId: String?) -> [MessageThread] {
        guard !messages.isEmpty else { return [] }

        var grouped: [String: [RawMessage]] = [:]
        for message in messages {
            let key: String
            if let requestId = message.requestId {
                key = "request:\(requestId)"
            } else if let bookingId = message.locationBookingId {
                key = "location:\(bookingId)"
            } else if let crewId = message.crewTeamRequestId {
                key = "crew:\(crewId)"
            } else if let castingId = message.castingInquiryId {
                key = "casting:\(castingId)"
            } else if let cateringId = message.cateringBookingId {
                key = "catering:\(cateringId)"
            } else if let peer = message.peerId(relativeTo: meId) {
                key = "peer:\(peer)"
            } else {
                key = "msg:\(message.id)"
            }
            grouped[key, default: []].append(message)
        }

        return grouped.map { key, items in
            let sorted = items.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
            let latest = sorted.last
            let counterpart = latest?.counterpartName(relativeTo: meId) ?? "Conversation"
            return MessageThread(
                id: key,
                subject: latest?.threadSubject,
                preview: latest?.body,
                updatedAt: latest?.createdAt,
                unreadCount: nil,
                counterpartName: counterpart
            )
        }
        .sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

// MARK: - Message API Types

private struct RawMessage: Decodable {
    let id: String
    var body: String?
    var createdAt: String?
    var senderId: String?
    var receiverId: String?
    var requestId: String?
    var locationBookingId: String?
    var crewTeamRequestId: String?
    var castingInquiryId: String?
    var cateringBookingId: String?
    var sender: RawSender?
    var receiver: RawSender?

    var asChatMessage: ChatMessage {
        ChatMessage(
            id: id,
            body: body,
            content: nil,
            createdAt: createdAt,
            senderId: senderId,
            senderName: sender?.name
        )
    }

    func peerId(relativeTo meId: String?) -> String? {
        guard let meId else { return receiverId ?? senderId }
        if senderId == meId { return receiverId }
        if receiverId == meId { return senderId }
        return receiverId ?? senderId
    }

    func counterpartName(relativeTo meId: String?) -> String? {
        guard let meId else { return sender?.name ?? receiver?.name }
        if senderId == meId { return receiver?.name }
        if receiverId == meId { return sender?.name }
        return sender?.name ?? receiver?.name
    }

    var threadSubject: String? {
        if requestId != nil { return "Equipment inquiry" }
        if locationBookingId != nil { return "Location booking" }
        if crewTeamRequestId != nil { return "Crew request" }
        if castingInquiryId != nil { return "Casting inquiry" }
        if cateringBookingId != nil { return "Catering booking" }
        return nil
    }
}

private struct RawSender: Decodable {
    var name: String?
}

private struct SendMessageBody: Encodable {
    var body: String
    var receiverId: String?
    var requestId: String?
    var locationBookingId: String?
    var crewTeamRequestId: String?
    var castingInquiryId: String?
    var cateringBookingId: String?
}

private extension MessageThread {
    var context: [String: String] {
        if id.hasPrefix("peer:") {
            return ["receiverId": String(id.dropFirst(5))]
        }
        if id.hasPrefix("request:") {
            return ["requestId": String(id.dropFirst(8))]
        }
        if id.hasPrefix("location:") {
            return ["locationBookingId": String(id.dropFirst(9))]
        }
        if id.hasPrefix("crew:") {
            return ["crewTeamRequestId": String(id.dropFirst(5))]
        }
        if id.hasPrefix("casting:") {
            return ["castingInquiryId": String(id.dropFirst(8))]
        }
        if id.hasPrefix("catering:") {
            return ["cateringBookingId": String(id.dropFirst(9))]
        }
        return [:]
    }
}
