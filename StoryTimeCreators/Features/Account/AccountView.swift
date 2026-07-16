import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = AccountViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .loading where vm.user == nil:
                LoadingStateView(message: "Loading profile…")
            case .error(let message) where vm.user == nil:
                ErrorStateView(message: message, retry: { Task { await vm.refresh(auth: auth) } })
            default:
                formContent
            }
        }
        .background(STColor.background)
        .task { await vm.refresh(auth: auth) }
        .refreshable { await vm.refresh(auth: auth) }
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Profile")
                    field("Name", text: $vm.name)
                    field("Headline", text: $vm.headline)
                    field("Location", text: $vm.location)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bio")
                            .font(STFont.body(12, weight: .medium))
                            .foregroundStyle(STColor.textMuted)
                        TextField("Tell creators about your work", text: $vm.bio, axis: .vertical)
                            .lineLimit(4...8)
                            .font(STFont.body(14))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                            .foregroundStyle(STColor.textPrimary)
                    }
                }
                .padding(16)
                .glassPanel()

                if let saveMessage = vm.saveMessage {
                    Text(saveMessage)
                        .font(STFont.body(13))
                        .foregroundStyle(vm.saveSucceeded ? STColor.success : STColor.danger)
                }

                Button {
                    Task { await vm.save(auth: auth) }
                } label: {
                    HStack {
                        if vm.isSaving {
                            ProgressView().tint(.black)
                        }
                        Text("Save changes")
                            .font(STFont.body(15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(STColor.brandGradient))
                }
                .disabled(vm.isSaving)

                Button(role: .destructive) {
                    Task { await auth.signOut() }
                } label: {
                    Text("Sign out")
                        .font(STFont.body(15, weight: .semibold))
                        .foregroundStyle(STColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(STColor.danger.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(16)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(STColor.primary.opacity(0.2))
                .frame(width: 64, height: 64)
                .overlay {
                    Text(String((vm.user?.displayName ?? "C").prefix(1)).uppercased())
                        .font(STFont.display(24, weight: .bold))
                        .foregroundStyle(STColor.primary)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.user?.displayName ?? "Creator")
                    .font(STFont.display(20, weight: .bold))
                    .foregroundStyle(STColor.textPrimary)
                if let email = vm.user?.email {
                    Text(email)
                        .font(STFont.body(13))
                        .foregroundStyle(STColor.textSecondary)
                }
                if let role = vm.user?.effectiveRole, !role.isEmpty {
                    Text(role.replacingOccurrences(of: "_", with: " "))
                        .font(STFont.body(11, weight: .semibold))
                        .foregroundStyle(STColor.accent)
                }
            }
            Spacer()
        }
        .padding(16)
        .glassPanel()
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(STFont.body(12, weight: .medium))
                .foregroundStyle(STColor.textMuted)
            TextField(title, text: text)
                .font(STFont.body(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                .foregroundStyle(STColor.textPrimary)
        }
    }
}

@MainActor
private final class AccountViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var user: CreatorUser?
    @Published private(set) var state: LoadState = .idle
    @Published var name = ""
    @Published var headline = ""
    @Published var bio = ""
    @Published var location = ""
    @Published var isSaving = false
    @Published var saveMessage: String?
    @Published var saveSucceeded = false

    private let client = APIClient.shared

    func refresh(auth: AuthService) async {
        state = .loading
        saveMessage = nil
        do {
            let me: CreatorUser = try await client.get("/api/me")
            apply(me)
            state = .loaded
        } catch {
            if let current = auth.currentUser {
                apply(current)
                state = .loaded
            } else {
                state = .error(Self.mapError(error, auth: auth))
            }
        }
    }

    func save(auth: AuthService) async {
        isSaving = true
        saveMessage = nil
        defer { isSaving = false }

        let body = UpdateProfileBody(
            name: name.nilIfEmpty,
            headline: headline.nilIfEmpty,
            bio: bio.nilIfEmpty,
            location: location.nilIfEmpty
        )

        do {
            let updated: CreatorUser = try await client.patch("/api/me", body: body)
            apply(updated)
            saveSucceeded = true
            saveMessage = "Profile updated."
        } catch {
            saveSucceeded = false
            saveMessage = Self.mapError(error, auth: auth)
        }
    }

    private func apply(_ user: CreatorUser) {
        self.user = user
        name = user.name ?? ""
        headline = user.headline ?? ""
        bio = user.bio ?? ""
        location = user.location ?? ""
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private struct UpdateProfileBody: Encodable {
    var name: String?
    var headline: String?
    var bio: String?
    var location: String?
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
