import SwiftUI

struct LocationsView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var locations: [LocationListing] = []
    @State private var isLoading = true
    @State private var bannerMessage: String?
    @State private var bookingLocation: LocationListing?
    @State private var bookingNote = ""
    @State private var bookingStartDate = ""
    @State private var bookingEndDate = ""

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading locations…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NoPayBanner(
                            text: "Browse locations and submit booking requests. Location hire payments are disabled — inquire only."
                        )

                        if let bannerMessage {
                            Text(bannerMessage)
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.success)
                        }

                        SectionHeader(title: "Locations", trailing: "\(locations.count)")

                        if locations.isEmpty {
                            EmptyStateView(
                                title: "No locations listed",
                                subtitle: "Location listings will appear here when available.",
                                systemImage: "mappin.and.ellipse"
                            )
                        } else {
                            ForEach(locations) { location in
                                locationCard(location)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task { await loadLocations() }
        .sheet(item: $bookingLocation) { location in
            bookingSheet(location: location)
        }
    }

    private func locationCard(_ location: LocationListing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.name)
                .font(STFont.body(15, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            HStack(spacing: 12) {
                if let type = location.type, !type.isEmpty {
                    Label(type, systemImage: "building.2")
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textSecondary)
                }
                if let city = location.city, !city.isEmpty {
                    Label(city, systemImage: "mappin")
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textSecondary)
                }
            }
            if let rate = location.dailyRate {
                Text("From R\(Int(rate))/day")
                    .font(STFont.body(12, weight: .medium))
                    .foregroundStyle(STColor.primary)
            }
            if let description = location.description, !description.isEmpty {
                Text(description)
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
                    .lineLimit(3)
            }
            Button("Request booking") {
                bookingLocation = location
                bookingNote = ""
                bookingStartDate = ""
                bookingEndDate = ""
            }
            .font(STFont.body(13, weight: .semibold))
            .foregroundStyle(STColor.primary)
        }
        .padding(14)
        .glassPanel()
    }

    private func bookingSheet(location: LocationListing) -> some View {
        NavigationStack {
            Form {
                Section("Location") { Text(location.name) }
                Section("Booking request") {
                    TextField("Start date (YYYY-MM-DD)", text: $bookingStartDate)
                    TextField("End date (YYYY-MM-DD)", text: $bookingEndDate)
                    TextField("Message / notes", text: $bookingNote, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("Request Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { bookingLocation = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submitBooking(location: location) } }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func loadLocations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: LocationListResponse = try await APIClient.shared.get("/api/locations")
            locations = response.all
        } catch {
            do {
                locations = try await APIClient.shared.get("/api/locations")
            } catch {
                locations = []
            }
        }
    }

    @MainActor
    private func submitBooking(location: LocationListing) async {
        let body = LocationBookingBody(
            locationId: location.id,
            note: bookingNote.stNilIfEmpty,
            shootType: nil,
            startDate: bookingStartDate.stNilIfEmpty,
            endDate: bookingEndDate.stNilIfEmpty,
            crewSize: nil,
            projectId: router.selectedProjectId,
            projectTitle: nil
        )
        do {
            let _: IdResponse = try await APIClient.shared.post("/api/location-bookings", body: body)
            bookingLocation = nil
            flash("Booking request sent for \(location.name).")
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
