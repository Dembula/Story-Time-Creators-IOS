import SwiftUI

struct MusicScoringView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var tracks: [MusicTrack] = []
    @State private var isLoading = true
    @State private var bannerMessage: String?
    @State private var searchText = ""
    @State private var selectedTrack: MusicTrack?
    @State private var selectionNotes = ""
    @State private var selectionUsage = "score"

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading music catalogue…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NoPayBanner(
                            text: "Browse the music catalogue and add tracks to your project. Sync licensing payments are disabled — selections are saved as project references."
                        )

                        if let bannerMessage {
                            Text(bannerMessage)
                                .font(STFont.body(13))
                                .foregroundStyle(STColor.success)
                        }

                        if router.selectedProjectId == nil {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .foregroundStyle(STColor.accent)
                                Text("Select a project from the phase hub to save music selections.")
                                    .font(STFont.body(12))
                                    .foregroundStyle(STColor.textSecondary)
                            }
                            .padding(12)
                            .glassPanel()
                        }

                        TextField("Search tracks", text: $searchText)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(STColor.surfaceElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(STColor.border, lineWidth: 1)
                                    )
                            )

                        SectionHeader(title: "Catalogue", trailing: "\(filteredTracks.count)")

                        if filteredTracks.isEmpty {
                            EmptyStateView(
                                title: "No tracks found",
                                subtitle: "Published music will appear here when available.",
                                systemImage: "music.note.list"
                            )
                        } else {
                            ForEach(filteredTracks) { track in
                                trackCard(track)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task { await loadTracks() }
        .sheet(item: $selectedTrack) { track in
            selectionSheet(track: track)
        }
    }

    private var filteredTracks: [MusicTrack] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tracks }
        return tracks.filter { track in
            track.title.lowercased().contains(query)
                || (track.artistName?.lowercased().contains(query) ?? false)
                || (track.genre?.lowercased().contains(query) ?? false)
                || (track.mood?.lowercased().contains(query) ?? false)
        }
    }

    private func trackCard(_ track: MusicTrack) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(STColor.primary)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                if let artist = track.artistName, !artist.isEmpty {
                    Text(artist)
                        .font(STFont.body(12))
                        .foregroundStyle(STColor.textSecondary)
                }
                HStack(spacing: 8) {
                    if let genre = track.genre, !genre.isEmpty {
                        Text(genre)
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.primary)
                    }
                    if let mood = track.mood, !mood.isEmpty {
                        Text(mood)
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textMuted)
                    }
                    if let duration = track.duration {
                        Text(formatDuration(duration))
                            .font(STFont.mono(11))
                            .foregroundStyle(STColor.textMuted)
                    }
                }
            }

            Spacer()

            if router.selectedProjectId != nil {
                Button("Select") {
                    selectedTrack = track
                    selectionNotes = ""
                    selectionUsage = "score"
                }
                .font(STFont.body(12, weight: .semibold))
                .foregroundStyle(STColor.accent)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private func selectionSheet(track: MusicTrack) -> some View {
        NavigationStack {
            Form {
                Section("Track") {
                    Text(track.title)
                    if let artist = track.artistName { Text(artist) }
                }
                Section("Project selection") {
                    Picker("Usage", selection: $selectionUsage) {
                        Text("Score").tag("score")
                        Text("Source").tag("source")
                        Text("Theme").tag("theme")
                        Text("Other").tag("other")
                    }
                    TextField("Notes", text: $selectionNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(STColor.background)
            .navigationTitle("Add to Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selectedTrack = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveSelection(track: track) } }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    @MainActor
    private func loadTracks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            tracks = try await APIClient.shared.get("/api/music/catalogue")
            return
        } catch {}

        do {
            tracks = try await APIClient.shared.get("/api/music")
        } catch {
            tracks = []
        }
    }

    @MainActor
    private func saveSelection(track: MusicTrack) async {
        guard let projectId = router.selectedProjectId else {
            flash("Select a project first.")
            return
        }
        let body = MusicSelectionBody(
            trackId: track.id,
            usage: selectionUsage,
            notes: selectionNotes.stNilIfEmpty
        )
        do {
            let _: MusicSelectionResponse = try await APIClient.shared.post(
                "/api/creator/projects/\(projectId)/music-selection",
                body: body
            )
            selectedTrack = nil
            flash("Added \"\(track.title)\" to project.")
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
