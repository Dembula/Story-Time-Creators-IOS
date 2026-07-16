import SwiftUI

private enum CastingTab: String, CaseIterable, Identifiable {
    case roster = "My Roster"
    case agencies = "Agencies"
    case roles = "Project Roles"

    var id: String { rawValue }
}

struct CastingPortalView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var tab: CastingTab = .roster
    @State private var roster: [RosterContact] = []
    @State private var agencies: [CastingAgency] = []
    @State private var roles: [CastingRole] = []
    @State private var isLoading = true
    @State private var bannerMessage: String?
    @State private var showAddRoster = false
    @State private var editingContact: RosterContact?
    @State private var inquiryAgency: CastingAgency?
    @State private var inquiryMessage = ""
    @State private var inquiryRoleName = ""

    @State private var rosterForm = RosterFormState()

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading casting portal…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NoPayBanner(
                            text: "Browse agencies, manage your roster, and send casting inquiries. Audition listing fees and hire payments are disabled in the Creators app."
                        )

                        if let bannerMessage {
                            Text(bannerMessage)
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.success)
                                .padding(.horizontal, 4)
                        }

                        Picker("Section", selection: $tab) {
                            ForEach(CastingTab.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .roster:
                            rosterSection
                        case .agencies:
                            agenciesSection
                        case .roles:
                            rolesSection
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task { await loadAll() }
        .sheet(isPresented: $showAddRoster) {
            rosterEditorSheet(isNew: true)
        }
        .sheet(item: $editingContact) { contact in
            rosterEditorSheet(isNew: false, contact: contact)
        }
        .sheet(item: $inquiryAgency) { agency in
            inquirySheet(agency: agency)
        }
    }

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "My Cast Roster", trailing: "\(roster.count)")
                Spacer()
                Button {
                    rosterForm = RosterFormState()
                    showAddRoster = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(STColor.primary)
                }
            }

            if roster.isEmpty {
                EmptyStateView(
                    title: "No cast contacts yet",
                    subtitle: "Add performers you work with directly — no marketplace fees.",
                    systemImage: "person.crop.circle.badge.plus"
                )
            } else {
                ForEach(roster) { contact in
                    rosterRow(contact)
                }
            }
        }
    }

    private func rosterRow(_ contact: RosterContact) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                if let role = contact.role, !role.isEmpty {
                    Text(role)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.primary)
                }
                if let email = contact.email, !email.isEmpty {
                    Text(email)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textSecondary)
                }
                if let notes = contact.notes, !notes.isEmpty {
                    Text(notes)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer()
            Menu {
                Button("Edit") { editingContact = contact }
                Button("Remove", role: .destructive) {
                    Task { await deleteRoster(contact.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(STColor.textMuted)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private var agenciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Casting Agencies", trailing: "\(agencies.count)")

            if agencies.isEmpty {
                EmptyStateView(
                    title: "No agencies listed",
                    subtitle: "Agency listings will appear here when available.",
                    systemImage: "building.2"
                )
            } else {
                ForEach(agencies) { agency in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(agency.name)
                            .font(STFont.body(15, weight: .semibold))
                            .foregroundStyle(STColor.textPrimary)
                        if let location = agency.location, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textSecondary)
                        }
                        if let description = agency.description, !description.isEmpty {
                            Text(description)
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textMuted)
                                .lineLimit(3)
                        }
                        Button("Send inquiry") {
                            inquiryAgency = agency
                            inquiryMessage = ""
                            inquiryRoleName = ""
                        }
                        .font(STFont.body(13, weight: .semibold))
                        .foregroundStyle(STColor.primary)
                    }
                    .padding(14)
                    .glassPanel()
                }
            }
        }
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Project Roles")

            if router.selectedProjectId == nil {
                EmptyStateView(
                    title: "Select a project",
                    subtitle: "Choose a project from Pre-Production or the phase hub to view casting roles.",
                    systemImage: "folder"
                )
            } else if roles.isEmpty {
                EmptyStateView(
                    title: "No roles yet",
                    subtitle: "Casting roles for this project will appear here.",
                    systemImage: "theatermasks"
                )
            } else {
                ForEach(roles) { role in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(role.name)
                                .font(STFont.body(15, weight: .semibold))
                                .foregroundStyle(STColor.textPrimary)
                            Spacer()
                            if let status = role.status, !status.isEmpty {
                                Text(status)
                                    .font(STFont.body(11, weight: .medium))
                                    .foregroundStyle(STColor.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(STColor.surfaceElevated))
                            }
                        }
                        if let importance = role.importance, !importance.isEmpty {
                            Text(importance)
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.primary)
                        }
                        if let description = role.description, !description.isEmpty {
                            Text(description)
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textSecondary)
                        }
                    }
                    .padding(14)
                    .glassPanel()
                }
            }
        }
    }

    private func rosterEditorSheet(isNew: Bool, contact: RosterContact? = nil) -> some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $rosterForm.name)
                    TextField("Role type", text: $rosterForm.roleType)
                    TextField("Email", text: $rosterForm.contactEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
                Section("Notes") {
                    TextField("Notes", text: $rosterForm.notes, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Past work", text: $rosterForm.pastWork, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle(isNew ? "Add Cast" : "Edit Cast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddRoster = false
                        editingContact = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if isNew {
                                await createRoster()
                            } else if let contact {
                                await updateRoster(contact.id)
                            }
                        }
                    }
                    .disabled(rosterForm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let contact {
                    rosterForm = RosterFormState(contact: contact)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func inquirySheet(agency: CastingAgency) -> some View {
        NavigationStack {
            Form {
                Section("Agency") {
                    Text(agency.name)
                }
                Section("Inquiry") {
                    TextField("Role name (optional)", text: $inquiryRoleName)
                    TextField("Message", text: $inquiryMessage, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("Send Inquiry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { inquiryAgency = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await sendInquiry(agency: agency) }
                    }
                    .disabled(inquiryMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        async let rosterLoad: Void = loadRoster()
        async let agenciesLoad: Void = loadAgencies()
        async let rolesLoad: Void = loadRoles()
        _ = await (rosterLoad, agenciesLoad, rolesLoad)
    }

    @MainActor
    private func loadRoster() async {
        do {
            roster = try await APIClient.shared.get("/api/creator/cast-roster")
        } catch {
            roster = []
        }
    }

    @MainActor
    private func loadAgencies() async {
        do {
            agencies = try await APIClient.shared.get("/api/casting-agencies")
        } catch {
            agencies = []
        }
    }

    @MainActor
    private func loadRoles() async {
        guard let projectId = router.selectedProjectId else {
            roles = []
            return
        }
        do {
            let response: CastingRolesResponse = try await APIClient.shared.get(
                "/api/creator/projects/\(projectId)/casting"
            )
            roles = response.roles ?? []
        } catch {
            roles = []
        }
    }

    @MainActor
    private func createRoster() async {
        let body = CreateCastRosterBody(
            name: rosterForm.name.trimmingCharacters(in: .whitespacesAndNewlines),
            roleType: rosterForm.roleType.nilIfEmpty,
            contactEmail: rosterForm.contactEmail.nilIfEmpty,
            notes: rosterForm.notes.nilIfEmpty,
            pastWork: rosterForm.pastWork.nilIfEmpty
        )
        do {
            let created: RosterContact = try await APIClient.shared.post("/api/creator/cast-roster", body: body)
            roster.insert(created, at: 0)
            showAddRoster = false
            flash("Cast member added.")
        } catch {
            flash(error.localizedDescription)
        }
    }

    @MainActor
    private func updateRoster(_ id: String) async {
        let body = UpdateCastRosterBody(
            name: rosterForm.name.nilIfEmpty,
            roleType: rosterForm.roleType.nilIfEmpty,
            contactEmail: rosterForm.contactEmail.nilIfEmpty,
            notes: rosterForm.notes.nilIfEmpty,
            pastWork: rosterForm.pastWork.nilIfEmpty
        )
        do {
            let updated: RosterContact = try await APIClient.shared.patch("/api/creator/cast-roster/\(id)", body: body)
            if let index = roster.firstIndex(where: { $0.id == id }) {
                roster[index] = updated
            }
            editingContact = nil
            flash("Contact updated.")
        } catch {
            flash(error.localizedDescription)
        }
    }

    @MainActor
    private func deleteRoster(_ id: String) async {
        do {
            let _: OkResponse = try await APIClient.shared.delete("/api/creator/cast-roster/\(id)")
            roster.removeAll { $0.id == id }
            flash("Contact removed.")
        } catch {
            flash(error.localizedDescription)
        }
    }

    @MainActor
    private func sendInquiry(agency: CastingAgency) async {
        let project = router.selectedProjectId
        let body = CastInquiryBody(
            agencyId: agency.id,
            projectName: nil,
            roleName: inquiryRoleName.nilIfEmpty,
            message: inquiryMessage.trimmingCharacters(in: .whitespacesAndNewlines),
            talentId: nil,
            projectId: project
        )
        do {
            let _: IdResponse = try await APIClient.shared.post("/api/casting-agencies/inquiries", body: body)
            inquiryAgency = nil
            flash("Inquiry sent to \(agency.name).")
        } catch {
            flash(error.localizedDescription)
        }
    }

    @MainActor
    private func flash(_ message: String) {
        bannerMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            if bannerMessage == message { bannerMessage = nil }
        }
    }
}

private struct RosterFormState {
    var name = ""
    var roleType = ""
    var contactEmail = ""
    var notes = ""
    var pastWork = ""

    init() {}

    init(contact: RosterContact) {
        name = contact.name
        roleType = contact.role ?? ""
        contactEmail = contact.email ?? ""
        notes = contact.notes ?? ""
        pastWork = contact.pastWork ?? ""
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
