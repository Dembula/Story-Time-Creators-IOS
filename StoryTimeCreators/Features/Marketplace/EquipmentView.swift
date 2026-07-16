import SwiftUI

struct EquipmentView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var equipment: [EquipmentItem] = []
    @State private var isLoading = true
    @State private var bannerMessage: String?
    @State private var requestItem: EquipmentItem?
    @State private var requestNote = ""
    @State private var requestStartDate = ""
    @State private var requestEndDate = ""

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading equipment…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NoPayBanner(
                            text: "Browse equipment listings and submit rental requests. Equipment hire payments are disabled."
                        )

                        if let bannerMessage {
                            Text(bannerMessage)
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.success)
                        }

                        SectionHeader(title: "Equipment", trailing: "\(equipment.count)")

                        if equipment.isEmpty {
                            EmptyStateView(
                                title: "No equipment listed",
                                subtitle: "Equipment companies will appear here when available.",
                                systemImage: "camera.fill"
                            )
                        } else {
                            ForEach(equipment) { item in
                                equipmentCard(item)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task { await loadEquipment() }
        .sheet(item: $requestItem) { item in
            requestSheet(item: item)
        }
    }

    private func equipmentCard(_ item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(STFont.body(15, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            if let category = item.category, !category.isEmpty {
                Text(category)
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.primary)
            }
            if let location = item.location, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textSecondary)
            }
            if let rate = item.dailyRate {
                Text("From R\(Int(rate))/day")
                    .font(STFont.body(12, weight: .medium))
                    .foregroundStyle(STColor.accent)
            }
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
                    .lineLimit(3)
            }
            Button("Request rental") {
                requestItem = item
                requestNote = router.selectedProjectId != nil ? "Rental for active project" : ""
                requestStartDate = ""
                requestEndDate = ""
            }
            .font(STFont.body(13, weight: .semibold))
            .foregroundStyle(STColor.primary)
        }
        .padding(14)
        .glassPanel()
    }

    private func requestSheet(item: EquipmentItem) -> some View {
        NavigationStack {
            Form {
                Section("Equipment") { Text(item.name) }
                Section("Request") {
                    TextField("Start date (YYYY-MM-DD)", text: $requestStartDate)
                    TextField("End date (YYYY-MM-DD)", text: $requestEndDate)
                    TextField("Notes", text: $requestNote, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("Equipment Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestItem = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submitRequest(item: item) } }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func loadEquipment() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: EquipmentListResponse = try await APIClient.shared.get("/api/equipment")
            equipment = response.all
        } catch {
            do {
                equipment = try await APIClient.shared.get("/api/equipment")
            } catch {
                equipment = []
            }
        }
    }

    @MainActor
    private func submitRequest(item: EquipmentItem) async {
        let body = EquipmentRequestBody(
            equipmentId: item.id,
            note: requestNote.stNilIfEmpty,
            startDate: requestStartDate.stNilIfEmpty,
            endDate: requestEndDate.stNilIfEmpty,
            projectId: router.selectedProjectId,
            projectTitle: nil
        )
        do {
            let _: IdResponse = try await APIClient.shared.post("/api/equipment-requests", body: body)
            requestItem = nil
            flash("Request sent for \(item.name).")
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

private extension String {
    var stNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
