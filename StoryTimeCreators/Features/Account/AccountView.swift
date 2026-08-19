import SwiftUI
import StoreKit

struct AccountView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = AccountViewModel()
    @State private var webDestination: WebDestination?
    @State private var showNativeEditor = false
    @State private var showPlanStore = false
    @State private var showDeleteAccount = false
    @State private var showManageSubscriptions = false

    private struct WebDestination: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
    }

    var body: some View {
        Group {
            switch vm.state {
            case .loading where vm.user == nil:
                LoadingStateView(message: "Loading profile…")
            case .error(let message) where vm.user == nil:
                ErrorStateView(message: message, retry: { Task { await vm.refresh(auth: auth) } })
            default:
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        profileHeader

                        if auth.needsPlanSetup {
                            planAlert
                        }

                        settingsGroup(title: "Studio") {
                            settingsRow(
                                title: "Creator plan & billing",
                                subtitle: vm.licenseSubtitle,
                                systemImage: "creditcard.fill"
                            ) {
                                if AppConfig.Features.storeKitBillingEnabled {
                                    showPlanStore = true
                                } else {
                                    openWeb(
                                        auth.needsPlanSetup
                                            ? (auth.pendingOnboardingPath.map { AppConfig.webURL(path: $0) } ?? AppConfig.creatorLicenseOnboardingURL)
                                            : AppConfig.creatorLicenseOnboardingURL,
                                        title: "Plan & billing"
                                    )
                                }
                            }
                            if AppConfig.Features.storeKitBillingEnabled {
                                settingsRow(
                                    title: "Manage subscription",
                                    subtitle: "Upgrade, downgrade, or cancel via Apple",
                                    systemImage: "arrow.triangle.2.circlepath"
                                ) {
                                    showManageSubscriptions = true
                                }
                            }
                            settingsRow(
                                title: "Web studio account",
                                subtitle: "Full settings, notifications, company seats",
                                systemImage: "safari"
                            ) {
                                openWeb(AppConfig.creatorAccountURL, title: "Studio account")
                            }
                            settingsRow(
                                title: "Command Center (web)",
                                subtitle: "Advanced analytics & exports",
                                systemImage: "chart.bar.doc.horizontal"
                            ) {
                                openWeb(AppConfig.creatorCommandCenterURL, title: "Command Center")
                            }
                        }

                        settingsGroup(title: "Catalogue") {
                            settingsRow(
                                title: "My Catalogue (web)",
                                subtitle: "Publish status, seasons, review notes",
                                systemImage: "film.stack"
                            ) {
                                openWeb(AppConfig.creatorCatalogueURL, title: "Catalogue")
                            }
                            settingsRow(
                                title: "Upload on web",
                                subtitle: "Episodes & advanced submission tools",
                                systemImage: "arrow.up.circle"
                            ) {
                                openWeb(AppConfig.creatorUploadURL, title: "Upload")
                            }
                            settingsRow(
                                title: "Originals & competitions",
                                subtitle: "Votes, entries, platform support",
                                systemImage: "trophy"
                            ) {
                                openWeb(AppConfig.creatorOriginalsURL, title: "Originals")
                            }
                        }

                        settingsGroup(title: "Profile") {
                            settingsRow(
                                title: "Edit profile",
                                subtitle: "Name, bio, network identity, password",
                                systemImage: "person.crop.circle"
                            ) {
                                showNativeEditor = true
                            }
                        }

                        settingsGroup(title: "About this app") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Story Time Creators")
                                    .font(STFont.body(14, weight: .semibold))
                                    .foregroundStyle(STColor.textPrimary)
                                Text(DeviceIdentity.deviceSummary)
                                    .font(STFont.body(12))
                                    .foregroundStyle(STColor.textMuted)
                                Text("Creator plans and per-film upload fees are available as In-App Purchases. Marketplace and multi-platform studio tools may also be managed on story-time.online.")
                                    .font(STFont.body(11))
                                    .foregroundStyle(STColor.textMuted)
                            }
                            .padding(14)
                        }

                        settingsGroup(title: "Privacy & data") {
                            aiConsentRow
                            settingsRow(
                                title: "Delete account",
                                subtitle: "Permanently remove your Story Time account and data",
                                systemImage: "trash.fill"
                            ) {
                                showDeleteAccount = true
                            }
                        }

                        Button(role: .destructive) {
                            Task { await auth.signOut() }
                        } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(STFont.body(15, weight: .semibold))
                                .foregroundStyle(STColor.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(STColor.danger.opacity(0.4))
                                )
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(STColor.background)
        .task {
            await vm.refresh(auth: auth)
            await auth.refreshPackageGate()
            await vm.loadLicense()
        }
        .refreshable {
            await vm.refresh(auth: auth)
            await auth.refreshPackageGate()
            await vm.loadLicense()
        }
        .sheet(item: $webDestination) { dest in
            AuthenticatedWebBrowser(
                url: dest.url,
                title: dest.title,
                mode: .account,
                onFinished: {
                    Task {
                        await auth.refreshPackageGate()
                        await vm.refresh(auth: auth)
                        await vm.loadLicense()
                    }
                }
            )
        }
        .sheet(isPresented: $showNativeEditor) {
            NavigationStack {
                ProfileEditorSheet(vm: vm)
                    .environmentObject(auth)
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showPlanStore) {
            CreatorPlanStoreView {
                Task {
                    await auth.refreshPackageGate()
                    await vm.loadLicense()
                }
            }
            .environmentObject(auth)
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountSheet()
                .environmentObject(auth)
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    private var aiConsentRow: some View {
        let consented = UserDefaults.standard.bool(forKey: "va_ai_data_consent_granted")
        return HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(STColor.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(STColor.primary.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI assistant data sharing")
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                Text(consented ? "Allowed — messages sent to OpenAI for responses" : "Not allowed")
                    .font(STFont.body(11))
                    .foregroundStyle(STColor.textMuted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "va_ai_data_consent_granted") },
                set: { UserDefaults.standard.set($0, forKey: "va_ai_data_consent_granted") }
            ))
            .labelsHidden()
            .tint(STColor.primary)
        }
        .padding(14)
    }

    private var planAlert: some View {
        Button {
            if AppConfig.Features.storeKitBillingEnabled {
                showPlanStore = true
            } else {
                openWeb(
                    auth.pendingOnboardingPath.map { AppConfig.webURL(path: $0) } ?? AppConfig.creatorLicenseOnboardingURL,
                    title: "Finish plan"
                )
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.black)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan setup incomplete")
                        .font(STFont.body(14, weight: .bold))
                        .foregroundStyle(.black)
                    Text("Choose pay-per-film (free to start) or purchase a plan with In-App Purchase.")
                        .font(STFont.body(12))
                        .foregroundStyle(.black.opacity(0.8))
                }
                Spacer()
                Text("Continue")
                    .font(STFont.body(12, weight: .bold))
                    .foregroundStyle(.black)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(STColor.brandGradient))
        }
        .buttonStyle(.plain)
    }

    private var profileHeader: some View {
        Button {
            showNativeEditor = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(STColor.primary.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text(String((vm.user?.displayName ?? "C").prefix(1)).uppercased())
                            .font(STFont.display(26, weight: .bold))
                            .foregroundStyle(STColor.primary)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.user?.displayName ?? "Creator")
                        .font(STFont.display(20, weight: .bold))
                        .foregroundStyle(STColor.textPrimary)
                    if let email = vm.user?.email {
                        Text(email).font(STFont.body(13)).foregroundStyle(STColor.textSecondary)
                    }
                    Text(vm.licenseSubtitle)
                        .font(STFont.body(11, weight: .semibold))
                        .foregroundStyle(STColor.accent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(STColor.textMuted)
            }
            .padding(16)
            .glassPanel()
        }
        .buttonStyle(.plain)
    }

    private func settingsGroup(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(STFont.body(12, weight: .bold))
                .foregroundStyle(STColor.textMuted)
                .tracking(0.6)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(STColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(STColor.border, lineWidth: 1)
                    )
            )
        }
    }

    private func settingsRow(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(STColor.primary)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(STColor.primary.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(STFont.body(14, weight: .semibold))
                        .foregroundStyle(STColor.textPrimary)
                    Text(subtitle)
                        .font(STFont.body(11))
                        .foregroundStyle(STColor.textMuted)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    private func openWeb(_ url: URL, title: String) {
        webDestination = WebDestination(url: url, title: title)
    }
}

// MARK: - Native profile editor

private struct ProfileEditorSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                Button {
                    Task {
                        await vm.save(auth: auth)
                        if vm.saveSucceeded { dismiss() }
                    }
                } label: {
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
            }
            .padding(16)
        }
        .background(STColor.background)
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
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

// MARK: - View model

@MainActor
final class AccountViewModel: ObservableObject {
    enum LoadState: Equatable { case idle, loading, loaded, error(String) }

    @Published private(set) var user: CreatorUser?
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var licenseType: String?
    @Published private(set) var licenseStatus: String?

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

    var licenseSubtitle: String {
        let type = friendlyLicense(licenseType)
        let status = (licenseStatus ?? "").isEmpty ? "—" : licenseStatus!
        return "\(type) · \(status)"
    }

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

    func loadLicense() async {
        struct LicenseEnvelope: Decodable {
            var license: LicenseBody?
            struct LicenseBody: Decodable {
                var type: String?
                var status: String?
            }
        }
        if let env: LicenseEnvelope = try? await client.get("/api/creator/distribution-license") {
            licenseType = env.license?.type
            licenseStatus = env.license?.status
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
            professionalName: professionalName.nilIfEmpty,
            primaryRole: primaryRole.nilIfEmpty,
            skills: skills.nilIfEmpty,
            expertiseAreas: expertiseAreas.nilIfEmpty,
            yearsExperience: Int(yearsExperience),
            availabilityStatus: availabilityStatus.nilIfEmpty,
            currentPassword: currentPassword.nilIfEmpty,
            newPassword: newPassword.nilIfEmpty
        )

        do {
            let updated: CreatorUser = try await client.patch("/api/me", body: body)
            user = updated
            auth.applyProfile(updated)
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
        primaryRole = me.primaryRole ?? ""
        skills = me.skills ?? ""
        expertiseAreas = me.expertiseAreas ?? ""
        if let years = me.yearsExperience {
            yearsExperience = "\(years)"
        } else {
            yearsExperience = ""
        }
        availabilityStatus = me.availabilityStatus ?? ""
    }

    private func friendlyLicense(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "No plan loaded" }
        if raw.contains("PER_FILM") || raw.contains("PER_UPLOAD") { return "Pay per film" }
        if raw.contains("PIPELINE") && raw.contains("_M") { return "Pipeline · monthly" }
        if raw.contains("PIPELINE") { return "Pipeline · yearly" }
        if raw.contains("UPLOAD") { return "Catalogue unlimited" }
        if raw.contains("YEARLY") { return "Yearly upload" }
        return raw.replacingOccurrences(of: "_", with: " ")
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
    var professionalName: String?
    var primaryRole: String?
    var skills: String?
    var expertiseAreas: String?
    var yearsExperience: Int?
    var availabilityStatus: String?
    var currentPassword: String?
    var newPassword: String?
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Account deletion (App Store 5.1.1(v))

struct DeleteAccountSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("This permanently deletes your Story Time account and associated data. This cannot be undone.")
                        .font(STFont.body(14))
                        .foregroundStyle(STColor.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account password")
                            .font(STFont.body(12, weight: .medium))
                            .foregroundStyle(STColor.textMuted)
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                            .foregroundStyle(STColor.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type DELETE to confirm")
                            .font(STFont.body(12, weight: .medium))
                            .foregroundStyle(STColor.textMuted)
                        TextField("DELETE", text: $confirmation)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                            .foregroundStyle(STColor.textPrimary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(STFont.body(13))
                            .foregroundStyle(STColor.danger)
                    }

                    Button {
                        Task { await delete() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(isWorking ? "Deleting…" : "Delete account permanently")
                                .font(STFont.body(15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(STColor.danger.opacity(canSubmit ? 1 : 0.4))
                        )
                    }
                    .disabled(!canSubmit || isWorking)
                    .buttonStyle(.plain)

                    Text("If you have trouble here, you can also complete deletion at story-time.online with your password.")
                        .font(STFont.body(11))
                        .foregroundStyle(STColor.textMuted)
                }
                .padding(20)
            }
            .background(STColor.background)
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(STColor.primary)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var canSubmit: Bool {
        !password.isEmpty && confirmation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }

    private func delete() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.deleteAccount(
                password: password,
                confirmation: confirmation.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
