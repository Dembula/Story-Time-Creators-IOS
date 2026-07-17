import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Catalogue upload wizard aligned with web `/creator/upload`.
struct UploadView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var router: AppRouter
    @StateObject private var vm = UploadViewModel()
    @State private var posterItem: PhotosPickerItem?
    @State private var backdropItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var trailerItem: PhotosPickerItem?
    @State private var showMoreTypes = false

    var body: some View {
        VStack(spacing: 0) {
            stepHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NoPayBanner(
                        text: "Upload media and save drafts from your device. Review submission checkout stays on the web studio — no charges here."
                    )

                    switch vm.step {
                    case 1: typeStep
                    case 2: detailsStep
                    case 3: mediaStep
                    case 4: metadataStep
                    default: reviewStep
                    }

                    if let message = vm.statusMessage {
                        Text(message)
                            .font(STFont.body(13))
                            .foregroundStyle(vm.succeeded ? STColor.success : STColor.danger)
                    }

                    if vm.uploadProgress > 0, vm.uploadProgress < 1 {
                        ProgressView(value: vm.uploadProgress)
                            .tint(STColor.primary)
                    }
                }
                .padding(16)
            }
            navBar
        }
        .background(STColor.background)
        .onAppear {
            if let pid = router.selectedProjectId {
                vm.linkedProjectId = pid
            }
        }
    }

    // MARK: - Chrome

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Catalogue Upload")
                .font(STFont.display(22, weight: .bold))
                .foregroundStyle(STColor.textPrimary)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { n in
                    Capsule()
                        .fill(n <= vm.step ? STColor.primary : STColor.border)
                        .frame(height: 4)
                }
            }

            Text(stepTitle)
                .font(STFont.body(13, weight: .medium))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(STColor.background.opacity(0.95))
        .overlay(alignment: .bottom) { Rectangle().fill(STColor.border).frame(height: 1) }
    }

    private var stepTitle: String {
        switch vm.step {
        case 1: return "1 · Content type"
        case 2: return "2 · Title & details"
        case 3: return "3 · Media & assets"
        case 4: return "4 · Metadata"
        default: return "5 · Review & save draft"
        }
    }

    private var navBar: some View {
        HStack(spacing: 12) {
            if vm.step > 1 {
                Button("Back") { withAnimation(.easeInOut(duration: 0.2)) { vm.step -= 1 } }
                    .font(STFont.body(15, weight: .semibold))
                    .foregroundStyle(STColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(STColor.border))
            }

            Button {
                if vm.step < 5 {
                    withAnimation(.easeInOut(duration: 0.2)) { vm.step += 1 }
                } else {
                    Task { await vm.submit(auth: auth) }
                }
            } label: {
                HStack {
                    if vm.isSubmitting { ProgressView().tint(.black) }
                    Text(vm.step < 5 ? "Continue" : (vm.isSubmitting ? "Saving…" : "Save draft"))
                        .font(STFont.body(15, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(STColor.brandGradient))
            }
            .disabled(!vm.canAdvance || vm.isSubmitting)
            .opacity(vm.canAdvance ? 1 : 0.45)
        }
        .padding(16)
        .background(STColor.surface.opacity(0.98))
    }

    // MARK: - Steps

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            typeGrid(for: CatalogueContentType.primary)

            if showMoreTypes || CatalogueContentType.more.contains(vm.type) {
                Text("More formats")
                    .font(STFont.body(13, weight: .semibold))
                    .foregroundStyle(STColor.textSecondary)
                    .padding(.top, 4)
                typeGrid(for: CatalogueContentType.more)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMoreTypes.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showMoreTypes ? "chevron.up" : "chevron.down")
                    Text(showMoreTypes
                         ? "Hide extra formats"
                         : "View more formats (\(CatalogueContentType.more.count))")
                        .font(STFont.body(14, weight: .semibold))
                }
                .foregroundStyle(STColor.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(STColor.primary.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            if CatalogueContentType.more.contains(vm.type) {
                showMoreTypes = true
            }
        }
    }

    private func typeGrid(for types: [CatalogueContentType]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(types) { type in
                Button {
                    vm.type = type
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(vm.type == type ? .black : STColor.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(vm.type == type ? Color.white.opacity(0.9) : STColor.primary.opacity(0.15))
                            )
                        Text(type.label)
                            .font(STFont.body(15, weight: .bold))
                            .foregroundStyle(STColor.textPrimary)
                        Text(type.detail)
                            .font(STFont.body(11))
                            .foregroundStyle(STColor.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(STColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(vm.type == type ? STColor.primary : STColor.border, lineWidth: vm.type == type ? 1.5 : 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Title", text: $vm.title)
            fieldMultiline("Synopsis", text: $vm.description)
            fieldMultiline("Logline", text: $vm.logline)
            field("Tags (comma separated)", text: $vm.tags)

            Text("Genres")
                .font(STFont.body(12, weight: .medium))
                .foregroundStyle(STColor.textMuted)

            FlowGenreChips(selected: $vm.selectedGenres, options: CatalogueContentType.coreGenres)
        }
        .padding(16)
        .glassPanel()
    }

    private var mediaStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(vm.type.isLongForm
                 ? "Long-form titles use episode uploads on web. Add poster, trailer, and assets here for your draft."
                 : "Upload the same asset slots as the web studio: main video, trailer, poster, backdrop, and script.")
                .font(STFont.body(12))
                .foregroundStyle(STColor.textSecondary)

            PhotosPicker(selection: $posterItem, matching: .images) {
                assetLabel(
                    title: "Poster",
                    subtitle: vm.posterUrl == nil ? "Cover image" : "Uploaded",
                    icon: "photo",
                    done: vm.posterUrl != nil,
                    loading: vm.busySlot == .poster
                )
            }
            .onChange(of: posterItem) { _, item in
                Task { await vm.uploadPhotos(item, slot: .poster) }
            }

            PhotosPicker(selection: $backdropItem, matching: .images) {
                assetLabel(
                    title: "Backdrop",
                    subtitle: vm.backdropUrl == nil ? "Wide hero image" : "Uploaded",
                    icon: "rectangle.on.rectangle",
                    done: vm.backdropUrl != nil,
                    loading: vm.busySlot == .backdrop
                )
            }
            .onChange(of: backdropItem) { _, item in
                Task { await vm.uploadPhotos(item, slot: .backdrop) }
            }

            if !vm.type.isLongForm {
                PhotosPicker(selection: $videoItem, matching: .videos) {
                    assetLabel(
                        title: "Main video",
                        subtitle: vm.videoUrl == nil ? "Feature film / short" : "Uploaded",
                        icon: "film",
                        done: vm.videoUrl != nil,
                        loading: vm.busySlot == .video
                    )
                }
                .onChange(of: videoItem) { _, item in
                    Task { await vm.uploadPhotos(item, slot: .video) }
                }
            }

            PhotosPicker(selection: $trailerItem, matching: .videos) {
                assetLabel(
                    title: "Trailer",
                    subtitle: vm.trailerUrl == nil ? "Optional promo cut" : "Uploaded",
                    icon: "play.rectangle",
                    done: vm.trailerUrl != nil,
                    loading: vm.busySlot == .trailer
                )
            }
            .onChange(of: trailerItem) { _, item in
                Task { await vm.uploadPhotos(item, slot: .trailer) }
            }

            Button {
                vm.pendingImportSlot = .script
                vm.showFileImporter = true
            } label: {
                assetLabel(
                    title: "Script / document",
                    subtitle: vm.scriptUrl == nil ? "PDF or text" : "Uploaded",
                    icon: "doc.richtext",
                    done: vm.scriptUrl != nil,
                    loading: vm.busySlot == .script
                )
            }
            .buttonStyle(.plain)

            Button {
                vm.pendingImportSlot = vm.type.isLongForm ? .trailer : .video
                vm.showFileImporter = true
            } label: {
                assetLabel(
                    title: "Import from Files",
                    subtitle: "mp4, mov, images, pdf, audio",
                    icon: "folder.badge.plus",
                    done: false,
                    loading: false
                )
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $vm.showFileImporter,
                allowedContentTypes: [
                    .pdf, .plainText, .mpeg4Movie, .quickTimeMovie,
                    .jpeg, .png, .heic, .mpeg4Audio,
                ],
                allowsMultipleSelection: false
            ) { result in
                Task { await vm.importFile(result) }
            }
        }
        .padding(16)
        .glassPanel()
    }

    private var metadataStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Language", selection: $vm.language) {
                ForEach(CatalogueContentType.languages, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            field("Country", text: $vm.country)

            Picker("Age rating", selection: $vm.ageRating) {
                Text("Select").tag("")
                ForEach(CatalogueContentType.ageRatings, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            field("Year", text: $vm.year)
                .keyboardType(.numberPad)
            field("Duration (minutes)", text: $vm.duration)
                .keyboardType(.numberPad)

            if vm.type.isLongForm {
                field("Episode count", text: $vm.episodes)
                    .keyboardType(.numberPad)
            }
        }
        .padding(16)
        .glassPanel()
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            reviewRow("Type", vm.type.label)
            reviewRow("Title", vm.title.isEmpty ? "—" : vm.title)
            reviewRow("Genres", vm.selectedGenres.isEmpty ? "—" : vm.selectedGenres.joined(separator: ", "))
            reviewRow("Language", vm.language)
            reviewRow("Country", vm.country)
            reviewRow("Rating", vm.ageRating.isEmpty ? "—" : vm.ageRating)
            reviewRow("Poster", vm.posterUrl == nil ? "Missing" : "Ready")
            reviewRow("Main video", vm.type.isLongForm ? "Episodes on web" : (vm.videoUrl == nil ? "Optional for draft" : "Ready"))
            reviewRow("Trailer", vm.trailerUrl == nil ? "—" : "Ready")
            reviewRow("Script", vm.scriptUrl == nil ? "—" : "Ready")

            Text("Saves as DRAFT to My Catalogue — finish review & payment on the web studio when ready.")
                .font(STFont.body(12))
                .foregroundStyle(STColor.textSecondary)
                .padding(.top, 4)
        }
        .padding(16)
        .glassPanel()
    }

    // MARK: - Helpers

    private func assetLabel(title: String, subtitle: String, icon: String, done: Bool, loading: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(done ? STColor.success : STColor.primary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 11).fill(STColor.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(STFont.body(14, weight: .semibold)).foregroundStyle(STColor.textPrimary)
                Text(subtitle).font(STFont.body(11)).foregroundStyle(STColor.textMuted)
            }
            Spacer()
            if loading {
                ProgressView().tint(STColor.primary)
            } else if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(STColor.success)
            } else {
                Image(systemName: "plus.circle").foregroundStyle(STColor.textMuted)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(STColor.surfaceElevated))
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(STFont.body(13)).foregroundStyle(STColor.textMuted)
            Spacer()
            Text(value)
                .font(STFont.body(13, weight: .medium))
                .foregroundStyle(STColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(STFont.body(12, weight: .medium)).foregroundStyle(STColor.textMuted)
            TextField(title, text: text)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
        }
    }

    private func fieldMultiline(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(STFont.body(12, weight: .medium)).foregroundStyle(STColor.textMuted)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(3...8)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
        }
    }
}

// MARK: - Types (matches web `content-types.ts`)

enum CatalogueContentType: String, CaseIterable, Identifiable {
    case movie = "MOVIE"
    case series = "SERIES"
    case show = "SHOW"
    case documentary = "DOCUMENTARY"
    case shortFilm = "SHORT_FILM"
    case podcast = "PODCAST"
    case comedySkit = "COMEDY_SKIT"
    case standUp = "STAND_UP"
    case animation = "ANIMATION"
    case sports = "SPORTS"
    case musicVideo = "MUSIC_VIDEO"
    case liveEvent = "LIVE_EVENT"
    case reality = "REALITY"
    case webSeries = "WEB_SERIES"
    case news = "NEWS"
    case educational = "EDUCATIONAL"

    var id: String { rawValue }

    /// Always visible on the upload type step.
    static let primary: [CatalogueContentType] = [
        .movie, .series, .show, .documentary, .shortFilm, .podcast,
    ]

    /// Revealed via “View more formats”.
    static let more: [CatalogueContentType] = [
        .comedySkit, .standUp, .animation, .sports, .musicVideo,
        .liveEvent, .reality, .webSeries, .news, .educational,
    ]

    var label: String {
        switch self {
        case .movie: return "Movie"
        case .series: return "Series"
        case .show: return "Show"
        case .documentary: return "Documentary"
        case .shortFilm: return "Short Film"
        case .podcast: return "Podcast"
        case .comedySkit: return "Comedy Skit"
        case .standUp: return "Stand-Up"
        case .animation: return "Animation"
        case .sports: return "Sports"
        case .musicVideo: return "Music Video"
        case .liveEvent: return "Live Event"
        case .reality: return "Reality"
        case .webSeries: return "Web Series"
        case .news: return "News"
        case .educational: return "Educational"
        }
    }

    var detail: String {
        switch self {
        case .movie: return "Feature film or theatrical-length title"
        case .series: return "Multi-episode scripted series"
        case .show: return "Variety, talk, or entertainment show"
        case .documentary: return "Feature or episodic documentary"
        case .shortFilm: return "Short-form narrative or experimental"
        case .podcast: return "Audio or video podcast series"
        case .comedySkit: return "Sketch comedy and short comedy bits"
        case .standUp: return "Stand-up specials and comedy sets"
        case .animation: return "Animated films, series, or shorts"
        case .sports: return "Matches, highlights, and sports coverage"
        case .musicVideo: return "Music videos and visual singles"
        case .liveEvent: return "Concerts, festivals, and live captures"
        case .reality: return "Reality and unscripted formats"
        case .webSeries: return "Episode-based web / digital series"
        case .news: return "News, current affairs, and reports"
        case .educational: return "Learning, tutorials, and explainers"
        }
    }

    var systemImage: String {
        switch self {
        case .movie, .shortFilm: return "film"
        case .documentary: return "doc.richtext"
        case .series, .webSeries: return "tv"
        case .show, .reality: return "star.circle"
        case .podcast: return "mic.fill"
        case .comedySkit, .standUp: return "face.smiling"
        case .animation: return "paintpalette.fill"
        case .sports: return "sportscourt.fill"
        case .musicVideo: return "music.note.tv"
        case .liveEvent: return "theatermasks.fill"
        case .news: return "newspaper.fill"
        case .educational: return "book.fill"
        }
    }

    var isLongForm: Bool {
        switch self {
        case .series, .show, .podcast, .webSeries, .reality, .news:
            return true
        default:
            return false
        }
    }

    static let languages = [
        "English", "isiZulu", "isiXhosa", "Afrikaans", "Sesotho", "Setswana",
        "Sepedi", "Xitsonga", "siSwati", "Tshivenda", "isiNdebele",
        "French", "Portuguese", "Swahili", "Other",
    ]

    static let ageRatings = ["G", "PG", "PG-13", "16", "18", "R"]

    static let coreGenres = [
        "Action", "Adventure", "Animation", "Comedy", "Crime", "Documentary",
        "Drama", "Family", "Fantasy", "Horror", "Music", "Mystery",
        "Romance", "Sci-Fi", "Sport", "Thriller", "War", "Western",
        "Indie", "Coming-of-Age", "Dark Comedy", "Romantic Comedy",
    ]
}

enum UploadAssetSlot: String {
    case poster, backdrop, video, trailer, script
}

// MARK: - Genre chips

private struct FlowGenreChips: View {
    @Binding var selected: Set<String>
    let options: [String]

    var body: some View {
        FlexibleChipWrap(items: options) { genre in
            let on = selected.contains(genre)
            Button {
                if on { selected.remove(genre) } else { selected.insert(genre) }
            } label: {
                Text(genre)
                    .font(STFont.body(12, weight: .medium))
                    .foregroundStyle(on ? .black : STColor.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(on ? AnyShapeStyle(STColor.brandGradient) : AnyShapeStyle(STColor.surfaceElevated))
                    )
                    .overlay(Capsule().stroke(STColor.border.opacity(on ? 0 : 1)))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Simple wrapping layout for genre chips.
private struct FlexibleChipWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

// MARK: - View model

@MainActor
private final class UploadViewModel: ObservableObject {
    @Published var step = 1
    @Published var type: CatalogueContentType = .movie
    @Published var title = ""
    @Published var logline = ""
    @Published var description = ""
    @Published var tags = ""
    @Published var selectedGenres: Set<String> = []
    @Published var language = "English"
    @Published var country = "South Africa"
    @Published var ageRating = ""
    @Published var year = ""
    @Published var duration = ""
    @Published var episodes = ""

    @Published var posterUrl: String?
    @Published var backdropUrl: String?
    @Published var videoUrl: String?
    @Published var trailerUrl: String?
    @Published var scriptUrl: String?

    @Published var linkedProjectId: String?
    @Published var savedContentId: String?
    @Published var isSubmitting = false
    @Published var busySlot: UploadAssetSlot?
    @Published var uploadProgress: Double = 0
    @Published var statusMessage: String?
    @Published var succeeded = false
    @Published var showFileImporter = false
    @Published var pendingImportSlot: UploadAssetSlot = .script

    private let client = APIClient.shared

    var canAdvance: Bool {
        switch step {
        case 1: return true
        case 2: return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return true
        }
    }

    func uploadPhotos(_ item: PhotosPickerItem?, slot: UploadAssetSlot) async {
        guard let item else { return }
        busySlot = slot
        uploadProgress = 0.15
        defer {
            busySlot = nil
            uploadProgress = 0
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let isImage = slot == .poster || slot == .backdrop
            let contentType = isImage ? "image/jpeg" : "video/mp4"
            let ext = isImage ? "jpg" : "mp4"
            let fileName = "\(slot.rawValue)-\(UUID().uuidString).\(ext)"
            uploadProgress = 0.4
            let result = try await MediaUploadService.upload(data: data, fileName: fileName, contentType: contentType)
            applyURL(result.resolvedURL, to: slot)
            statusMessage = "\(slot.rawValue.capitalized) uploaded."
            succeeded = true
            uploadProgress = 1
        } catch {
            statusMessage = error.localizedDescription
            succeeded = false
        }
    }

    func importFile(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let slot = resolveSlot(for: url, preferred: pendingImportSlot)
        busySlot = slot
        defer { busySlot = nil }

        do {
            let data = try Data(contentsOf: url)
            let contentType = mimeType(for: url)
            let uploaded = try await MediaUploadService.upload(
                data: data,
                fileName: url.lastPathComponent,
                contentType: contentType
            )
            applyURL(uploaded.resolvedURL, to: slot)
            statusMessage = "File uploaded to \(slot.rawValue)."
            succeeded = true
        } catch {
            statusMessage = error.localizedDescription
            succeeded = false
        }
    }

    func submit(auth: AuthService) async {
        isSubmitting = true
        statusMessage = nil
        defer { isSubmitting = false }

        let body = CreateContentBody(
            contentId: savedContentId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type.rawValue,
            description: description.nilIfEmpty ?? logline.nilIfEmpty,
            posterUrl: posterUrl,
            backdropUrl: backdropUrl,
            videoUrl: type.isLongForm ? nil : videoUrl,
            trailerUrl: trailerUrl,
            scriptUrl: scriptUrl,
            category: selectedGenres.sorted().joined(separator: ", ").nilIfEmpty,
            tags: tags.nilIfEmpty,
            language: language.nilIfEmpty,
            country: country.nilIfEmpty,
            ageRating: ageRating.nilIfEmpty,
            year: Int(year),
            duration: Int(duration),
            episodes: type.isLongForm ? Int(episodes) : nil,
            linkedProjectId: linkedProjectId,
            reviewStatus: "DRAFT"
        )

        do {
            if let item: CreatorContentItem = try? await client.post("/api/creator/content", body: body) {
                savedContentId = item.id
            } else {
                _ = try await client.post("/api/creator/content", body: body) as OkResponse
            }
            succeeded = true
            statusMessage = "Draft saved to My Catalogue."
        } catch {
            succeeded = false
            statusMessage = error.localizedDescription
        }
    }

    private func applyURL(_ url: String?, to slot: UploadAssetSlot) {
        switch slot {
        case .poster: posterUrl = url
        case .backdrop: backdropUrl = url
        case .video: videoUrl = url
        case .trailer: trailerUrl = url
        case .script: scriptUrl = url
        }
    }

    private func resolveSlot(for url: URL, preferred: UploadAssetSlot) -> UploadAssetSlot {
        let ext = url.pathExtension.lowercased()
        if ["pdf", "txt", "doc", "docx"].contains(ext) { return .script }
        if ["jpg", "jpeg", "png", "heic", "webp"].contains(ext) {
            return preferred == .backdrop ? .backdrop : .poster
        }
        if ["mp3", "wav", "m4a", "aac", "flac"].contains(ext) { return .trailer }
        if preferred == .trailer { return .trailer }
        return type.isLongForm ? .trailer : .video
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "m4a": return "audio/mp4"
        default: return "application/octet-stream"
        }
    }
}

private extension UploadCompleteResponse {
    var resolvedURL: String? { storageRef ?? publicUrl ?? sourceUrl }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
