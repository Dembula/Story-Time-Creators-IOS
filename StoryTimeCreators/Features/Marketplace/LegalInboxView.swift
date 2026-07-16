import SwiftUI

struct LegalInboxView: View {
    @State private var waiting: [LegalInboxItem] = []
    @State private var pending: [LegalInboxItem] = []
    @State private var completed: [LegalInboxItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading legal inbox…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Contract Inbox", systemImage: "doc.text.fill")
                                .font(STFont.display(18, weight: .semibold))
                                .foregroundStyle(STColor.textPrimary)
                            Text("Agreements sent to you for review and signature across your projects.")
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textSecondary)
                        }

                        inboxSection(
                            title: "Waiting for you",
                            items: waiting,
                            empty: "No contracts need your signature.",
                            highlight: true
                        )
                        inboxSection(
                            title: "In progress",
                            items: pending,
                            empty: "No contracts awaiting counter-signature."
                        )
                        inboxSection(
                            title: "Completed",
                            items: Array(completed.prefix(20)),
                            empty: "No executed contracts yet."
                        )
                    }
                    .padding(16)
                }
            }
        }
        .task { await loadInbox() }
    }

    private func inboxSection(
        title: String,
        items: [LegalInboxItem],
        empty: String,
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(STFont.body(13, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)

            if items.isEmpty {
                Text(empty)
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    inboxRow(item, highlight: highlight)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(highlight ? STColor.primary.opacity(0.06) : STColor.surface.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(highlight ? STColor.primary.opacity(0.22) : STColor.border, lineWidth: 1)
                )
        )
    }

    private func inboxRow(_ item: LegalInboxItem, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Label(item.title, systemImage: "doc.text")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Spacer()
                if let label = item.statusLabel ?? item.status {
                    Text(label)
                        .font(STFont.body(10, weight: .medium))
                        .foregroundStyle(STColor.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().stroke(STColor.border))
                }
            }

            Text(itemSubtitle(item))
                .font(STFont.body(11))
                .foregroundStyle(STColor.textSecondary)

            if let action = item.requiredAction, !action.isEmpty {
                Text(action)
                    .font(STFont.body(11))
                    .foregroundStyle(STColor.accent)
            }

            if let deadline = item.signatureDeadline, !deadline.isEmpty {
                Text("Sign by \(deadline)")
                    .font(STFont.body(10))
                    .foregroundStyle(STColor.textMuted)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(highlight ? STColor.primary.opacity(0.08) : STColor.surfaceElevated)
        )
    }

    private func itemSubtitle(_ item: LegalInboxItem) -> String {
        var parts = [item.projectTitle]
        if let sender = item.senderName, !sender.isEmpty {
            parts.append("From \(sender)")
        }
        return parts.joined(separator: " · ")
    }

    @MainActor
    private func loadInbox() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: LegalInboxResponse = try await APIClient.shared.get("/api/creator/legal/inbox")
            waiting = response.buckets?.waitingForYou ?? []
            pending = response.buckets?.pending ?? []
            completed = response.buckets?.completed ?? []
        } catch {
            waiting = []
            pending = []
            completed = []
        }
    }
}
