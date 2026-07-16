import SwiftUI

struct CateringView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var companies: [CateringCompany] = []
    @State private var isLoading = true
    @State private var bannerMessage: String?
    @State private var bookingCompany: CateringCompany?
    @State private var eventDate = ""
    @State private var headCount = ""
    @State private var bookingNote = ""

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading catering…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NoPayBanner(
                            text: "Browse catering companies and submit booking requests. On-set catering payments are disabled."
                        )

                        if let bannerMessage {
                            Text(bannerMessage)
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.success)
                        }

                        SectionHeader(title: "Catering Companies", trailing: "\(companies.count)")

                        if companies.isEmpty {
                            EmptyStateView(
                                title: "No catering companies listed",
                                subtitle: "Catering providers will appear here when available.",
                                systemImage: "fork.knife"
                            )
                        } else {
                            ForEach(companies) { company in
                                companyCard(company)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task { await loadCompanies() }
        .sheet(item: $bookingCompany) { company in
            bookingSheet(company: company)
        }
    }

    private func companyCard(_ company: CateringCompany) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(company.name)
                .font(STFont.body(15, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            if let cuisine = company.cuisine, !cuisine.isEmpty {
                Text(cuisine)
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.primary)
            }
            if let location = company.location, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textSecondary)
            }
            if let description = company.description, !description.isEmpty {
                Text(description)
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
                    .lineLimit(3)
            }
            Button("Request booking") {
                bookingCompany = company
                eventDate = ""
                headCount = ""
                bookingNote = ""
            }
            .font(STFont.body(13, weight: .semibold))
            .foregroundStyle(STColor.primary)
        }
        .padding(14)
        .glassPanel()
    }

    private func bookingSheet(company: CateringCompany) -> some View {
        NavigationStack {
            Form {
                Section("Company") { Text(company.name) }
                Section("Booking request") {
                    TextField("Event date (YYYY-MM-DD)", text: $eventDate)
                    TextField("Head count", text: $headCount)
                        .keyboardType(.numberPad)
                    TextField("Notes", text: $bookingNote, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("Catering Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { bookingCompany = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submitBooking(company: company) } }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func loadCompanies() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: CateringListResponse = try await APIClient.shared.get("/api/catering-companies")
            companies = response.all
        } catch {
            do {
                companies = try await APIClient.shared.get("/api/catering-companies")
            } catch {
                companies = []
            }
        }
    }

    @MainActor
    private func submitBooking(company: CateringCompany) async {
        let parsedHeadCount = Int(headCount.trimmingCharacters(in: .whitespacesAndNewlines))
        let body = CateringBookingBody(
            cateringCompanyId: company.id,
            eventDate: eventDate.stNilIfEmpty,
            headCount: parsedHeadCount,
            note: bookingNote.stNilIfEmpty,
            projectId: router.selectedProjectId,
            projectTitle: nil
        )
        do {
            let _: IdResponse = try await APIClient.shared.post("/api/catering-bookings", body: body)
            bookingCompany = nil
            flash("Booking request sent to \(company.name).")
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
