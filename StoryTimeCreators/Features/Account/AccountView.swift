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

                section("Public profile") {
                    field("Display name", text: $vm.name)
                    field("Professional name", text: $vm.professionalName)
                    field("Headline", text: $vm.headline)
                    field("Network handle", text: $vm.networkHandle)
                    field("Location", text: $vm.location)
                    field("Website", text: $vm.website)
                    bioField
                }

                section("Contact") {
                    field("Email", text: $vm.email)
                    field("Phone", text: $vm.phoneNumber)
                }

                section("Creator details") {
                    field("Primary role", text: $vm.primaryRole)
                    field("Skills", text: $vm.skills)
                    field("Expertise areas", text: $vm.expertiseAreas)
                    field("Years experience", text: $vm.yearsExperience)
                    field("Availability", text: $vm.availabilityStatus)
                }

                section("Security") {
                    field("Current password", text: $vm.currentPassword, secure: true)
                    field("New password", text: $vm.newPassword, secure: true)
                }

                if let saveMessage = vm.saveMessage {
                    Text(saveMessage)
                        .font(STFont.body(13))
                        .foregroundStyle(vm.saveSucceeded ? STColor.success : STColor.danger)
                }

                Button { Task { await vm.save(auth: auth) } } label: {
                    HStack {
                        if vm.isSaving { ProgressView().tint(.black) }
                        Text("Save changes")
                            .font(STFont.body(15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(STColor.brandGradient))
                }
                .disabled(vm.isSaving)

                if vm.user?.multiRole == true, let roles = vm.user?.platformRoles {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Platform roles")
                        Text(roles.joined(separator: ", "))
                            .font(STFont.body(12))
                            .foregroundStyle(STColor.textSecondary)
                    }
                    .padding(16)
                    .glassPanel()
                }

                Button(role: .destructive) { Task { await auth.signOut() } } label: {
                    Text("Sign out")
                        .font(STFont.body(15, weight: .semibold))
                        .foregroundStyle(STColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).stroke(STColor.danger.opacity(0.4)))
                }
            }
            .padding(16)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(STColor.primary.opacity(0.2))
                .frame(width: 72, height: 72)
                .overlay {
                    Text(String((vm.user?.displayName ?? "C").prefix(1)).uppercased())
                        .font(STFont.display(28, weight: .bold))
                        .foregroundStyle(STColor.primary)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.user?.displayName ?? "Creator")
                    .font(STFont.display(20, weight: .bold))
                    .foregroundStyle(STColor.textPrimary)
                if let email = vm.user?.email {
                    Text(email).font(STFont.body(13)).foregroundStyle(STColor.textSecondary)
                }
                if let score = vm.user?.reputationScore {
                    Text("Reputation \(Int(score))")
                        .font(STFont.body(11, weight: .semibold))
                        .foregroundStyle(STColor.accent)
                }
            }
            Spacer()
        }
        .padding(16)
        .glassPanel()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title)
            content()
        }
        .padding(16)
        .glassPanel()
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bio").font(STFont.body(12, weight: .medium)).foregroundStyle(STColor.textMuted)
            TextField("Tell creators about your work", text: $vm.bio, axis: .vertical)
                .lineLimit(4...10)
                .font(STFont.body(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
        }
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(STFont.body(12, weight: .medium)).foregroundStyle(STColor.textMuted)
            Group {
                if secure { SecureField(title, text: text) } else { TextField(title, text: text) }
            }
            .font(STFont.body(14))
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
            .foregroundStyle(STColor.textPrimary)
        }
    }
}

@MainActor
private final class AccountViewModel: ObservableObject {
    enum LoadState: Equatable { case idle, loading, loaded, error(String) }

    @Published private(set) var user: CreatorUser?
    @Published private(set) var state: LoadState = .idle
    @Published var name = ""
    @Published var professionalName = ""
    @Published var headline = ""
    @Published var bio = ""
    @Published var location = ""
    @Published var website = ""
    @Published var networkHandle = ""
    @Published var email = ""
    @Published var phoneNumber = ""
    @Published var primaryRole = ""
    @Published var skills = ""
    @Published var expertiseAreas = ""
    @Published var yearsExperience = ""
    @Published var availabilityStatus = ""
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var isSaving = false
    @Published var saveMessage: String?
    @Published var saveSucceeded = false

    private let client = APIClient.shared

    func refresh(auth: AuthService) async {
        state = .loading
        do {
            let me: CreatorUser = try await client.get("/api/me")
            user = me
            auth.applyProfile(me)
            bind(me)
            state = .loaded
        } catch {
            state = .error(mapError(error, auth: auth))
        }
    }

    func save(auth: AuthService) async {
        isSaving = true
        saveMessage = nil
        defer { isSaving = false }

        let body = AccountPatchBody(
            name: name.nilIfEmpty,
            email: email.nilIfEmpty,
            phoneNumber: phoneNumber.nilIfEmpty,
            bio: bio.nilIfEmpty,
            headline: headline.nilIfEmpty,
            location: location.nilIfEmpty,
            website: website.nilIfEmpty,
            networkHandle: networkHandle.nilIfEmpty,
            currentPassword: currentPassword.nilIfEmpty,
            newPassword: newPassword.nilIfEmpty
        )

        do {
            let updated: CreatorUser = try await client.patch("/api/me", body: body)
            user = updated
            auth.currentUser = updated
            bind(updated)
            currentPassword = ""
            newPassword = ""
            saveSucceeded = true
            saveMessage = "Profile saved."
        } catch {
            saveSucceeded = false
            saveMessage = mapError(error, auth: auth)
        }
    }

    private func bind(_ me: CreatorUser) {
        name = me.name ?? ""
        professionalName = me.professionalName ?? ""
        headline = me.headline ?? ""
        bio = me.bio ?? ""
        location = me.location ?? ""
        website = me.website ?? ""
        networkHandle = me.networkHandle ?? ""
        email = me.email ?? ""
        phoneNumber = me.phoneNumber ?? ""
    }

    private func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private struct AccountPatchBody: Encodable {
    var name: String?
    var email: String?
    var phoneNumber: String?
    var bio: String?
    var headline: String?
    var location: String?
    var website: String?
    var networkHandle: String?
    var currentPassword: String?
    var newPassword: String?
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
