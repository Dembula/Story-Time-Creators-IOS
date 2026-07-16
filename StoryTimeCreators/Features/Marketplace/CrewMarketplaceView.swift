import SwiftUI

private enum CrewTab: String, CaseIterable, Identifiable {
    case roster = "My Roster"
    case teams = "Crew Teams"

    var id: String { rawValue }
}

struct CrewMarketplaceView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var tab: CrewTab = .roster
    @State private var roster: [RosterContact] = []
    @State private var teams: [CrewTeam] = []
    @State private var isLoading = true
    @State private var bannerMessage: String?
    @State private var showAddRoster = false
    @State private var requestTeam: CrewTeam?
    @State private var requestMessage = ""
    @State private var rosterForm = CrewRosterFormState()

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading crew marketplace…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NoPayBanner(
                            text: "Browse crew teams and manage your own roster. Team hire payments are disabled — send requests and inquiries only."
                        )

                        if let bannerMessage {
                            Text(bannerMessage)
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.success)
                        }

                        Picker("Section", selection: $tab) {
                            ForEach(CrewTab.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .roster:
                            rosterSection
                        case .teams:
                            teamsSection
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task { await loadAll() }
        .sheet(isPresented: $showAddRoster) {
            crewRosterSheet
        }
        .sheet(item: $requestTeam) { team in
            teamRequestSheet(team: team)
        }
    }

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "My Crew Roster", trailing: "\(roster.count)")
                Spacer()
                Button {
                    rosterForm = CrewRosterFormState()
                    showAddRoster = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(STColor.primary)
                }
            }

            if roster.isEmpty {
                EmptyStateView(
                    title: "No crew contacts yet",
                    subtitle: "Add crew members you work with directly.",
                    systemImage: "person.badge.plus"
                )
            } else {
                ForEach(roster) { contact in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.name)
                                .font(STFont.body(15, weight: .semibold))
                                .foregroundStyle(STColor.textPrimary)
                            if let role = contact.role, !role.isEmpty {
                                Text([role, contact.department].compactMap { $0 }.joined(separator: " · "))
                                    .font(STFont.body(12))
                                    .foregroundStyle(STColor.textSecondary)
                            }
                            if let email = contact.email, !email.isEmpty {
                                Text(email)
                                    .font(STFont.body(12))
                                    .foregroundStyle(STColor.textMuted)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task { await deleteRoster(contact.id) }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(STColor.danger)
                        }
                    }
                    .padding(14)
                    .glassPanel()
                }
            }
        }
    }

    private var teamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Crew Teams", trailing: "\(teams.count)")

            if teams.isEmpty {
                EmptyStateView(
                    title: "No crew teams listed",
                    subtitle: "Production crew companies will appear here when available.",
                    systemImage: "person.3"
                )
            } else {
                ForEach(teams) { team in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(team.name)
                            .font(STFont.body(15, weight: .semibold))
                            .foregroundStyle(STColor.textPrimary)
                        if let specialty = team.specialty, !specialty.isEmpty {
                            Text(specialty)
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.primary)
                        }
                        if let location = team.location, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textSecondary)
                        }
                        if let description = team.description, !description.isEmpty {
                            Text(description)
                                .font(STFont.body(12))
                                .foregroundStyle(STColor.textMuted)
                                .lineLimit(3)
                        }
                        Button("Request team") {
                            requestTeam = team
                            requestMessage = ""
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

    private var crewRosterSheet: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $rosterForm.name)
                    TextField("Role", text: $rosterForm.role)
                    TextField("Department", text: $rosterForm.department)
                    TextField("Email", text: $rosterForm.contactEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $rosterForm.phone)
                        .keyboardType(.phonePad)
                }
                Section("Notes") {
                    TextField("Notes", text: $rosterForm.notes, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Past projects", text: $rosterForm.pastProjects, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("Add Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddRoster = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await createRoster() } }
                        .disabled(rosterForm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func teamRequestSheet(team: CrewTeam) -> some View {
        NavigationStack {
            Form {
                Section("Team") { Text(team.name) }
                Section("Request") {
                    TextField("Message", text: $requestMessage, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("Request Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestTeam = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await sendTeamRequest(team: team) } }
                        .disabled(requestMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        async let r: Void = loadRoster()
        async let t: Void = loadTeams()
        _ = await (r, t)
    }

    @MainActor
    private func loadRoster() async {
        do {
            roster = try await APIClient.shared.get("/api/creator/crew-roster")
        } catch {
            roster = []
        }
    }

    @MainActor
    private func loadTeams() async {
        do {
            teams = try await APIClient.shared.get("/api/crew-teams")
        } catch {
            teams = []
        }
    }

    @MainActor
    private func createRoster() async {
        let trimmed = rosterForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let body = CreateCrewRosterBody(
            name: trimmed,
            role: rosterForm.role.stNilIfEmpty,
            department: rosterForm.department.stNilIfEmpty,
            contactEmail: rosterForm.contactEmail.stNilIfEmpty,
            phone: rosterForm.phone.stNilIfEmpty,
            notes: rosterForm.notes.stNilIfEmpty,
            pastProjects: rosterForm.pastProjects.stNilIfEmpty
        )
        do {
            let created: RosterContact = try await APIClient.shared.post("/api/creator/crew-roster", body: body)
            roster.insert(created, at: 0)
            showAddRoster = false
            flash("Crew member added.")
        } catch {
            flash(error.localizedDescription)
        }
    }

    @MainActor
    private func deleteRoster(_ id: String) async {
        do {
            let _: OkResponse = try await APIClient.shared.delete("/api/creator/crew-roster/\(id)")
            roster.removeAll { $0.id == id }
            flash("Contact removed.")
        } catch {
            flash(error.localizedDescription)
        }
    }

    @MainActor
    private func sendTeamRequest(team: CrewTeam) async {
        let body = CrewTeamRequestBody(
            crewTeamId: team.id,
            projectName: nil,
            message: requestMessage.trimmingCharacters(in: .whitespacesAndNewlines),
            projectId: router.selectedProjectId
        )
        do {
            let _: IdResponse = try await APIClient.shared.post("/api/crew-teams/requests", body: body)
            requestTeam = nil
            flash("Request sent to \(team.name).")
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

private struct CrewRosterFormState {
    var name = ""
    var role = ""
    var department = ""
    var contactEmail = ""
    var phone = ""
    var notes = ""
    var pastProjects = ""
}

private extension String {
    var stNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
