import Foundation
import Combine

@MainActor
final class VAController: ObservableObject {
    @Published var isOpen = false
    @Published var messages: [(role: String, text: String)] = []
    @Published var suggestions: [String] = []
    @Published var isSending = false
    @Published var statusAvailable = false

    var projectId: String?

    func open(projectId: String? = nil) {
        self.projectId = projectId
        isOpen = true
        Task {
            await loadStatus()
            await loadContext(projectId: projectId)
        }
    }

    func close() {
        isOpen = false
    }

    func loadStatus() async {
        do {
            let status: ModocStatus = try await APIClient.shared.get("/api/modoc/status")
            statusAvailable = status.available ?? false
        } catch {
            statusAvailable = false
        }
    }

    func loadContext(projectId: String?) async {
        var query: [URLQueryItem] = []
        if let projectId {
            query.append(URLQueryItem(name: "projectId", value: projectId))
        }
        do {
            let context: ModocContext = try await APIClient.shared.get("/api/modoc/context", query: query)
            suggestions = context.suggestions ?? []
            if messages.isEmpty, let greeting = context.greeting, !greeting.isEmpty {
                messages.append((role: "assistant", text: greeting))
            }
        } catch {
            suggestions = []
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        isSending = true
        messages.append((role: "user", text: trimmed))

        let payloadMessages = messages.map { ChatUIMessage(role: $0.role, content: $0.text) }
        var pageContext: [String: String]?
        if let projectId {
            pageContext = ["projectId": projectId]
        }

        let body = ChatPostBody(
            messages: payloadMessages,
            scope: "creator",
            pageContext: pageContext,
            conversationId: nil
        )

        messages.append((role: "assistant", text: ""))
        let assistantIndex = messages.count - 1

        do {
            let stream = try await APIClient.shared.streamChat(path: "/api/modoc/chat", body: body)
            for try await chunk in stream {
                var current = messages[assistantIndex]
                current.text += chunk
                messages[assistantIndex] = current
            }
            if messages[assistantIndex].text.isEmpty {
                var current = messages[assistantIndex]
                current.text = "I'm here when you need help with your project."
                messages[assistantIndex] = current
            }
        } catch {
            var current = messages[assistantIndex]
            if current.text.isEmpty {
                current.text = "Sorry, I couldn't connect right now. \(error.localizedDescription)"
            } else {
                current.text += "\n\n(Streaming interrupted.)"
            }
            messages[assistantIndex] = current
        }

        isSending = false
    }

    func applySuggestion(_ suggestion: String) {
        Task { await send(suggestion) }
    }
}
