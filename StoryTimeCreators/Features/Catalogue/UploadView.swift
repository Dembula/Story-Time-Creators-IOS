import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct UploadView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = UploadViewModel()
    @State private var posterItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Catalogue Upload")

                NoPayBanner(
                    text: "Upload media and save drafts from your device. Checkout and per-film upload payments stay on the web studio — no charges in this app."
                )

                VStack(alignment: .leading, spacing: 14) {
                    field("Title", text: $vm.title)
                    Picker("Type", selection: $vm.type) {
                        ForEach(vm.contentTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    fieldMultiline("Description", text: $vm.description)
                    fieldMultiline("Logline", text: $vm.logline)
                }
                .padding(16)
                .glassPanel()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Media from device")
                    PhotosPicker(selection: $posterItem, matching: .images) {
                        uploadButtonLabel("Choose poster image", icon: "photo", loading: vm.isUploadingPoster)
                    }
                    .onChange(of: posterItem) { _, item in
                        Task { await vm.uploadPhotoItem(item, kind: .poster, auth: auth) }
                    }

                    PhotosPicker(selection: $videoItem, matching: .videos) {
                        uploadButtonLabel("Choose video file", icon: "film", loading: vm.isUploadingVideo)
                    }
                    .onChange(of: videoItem) { _, item in
                        Task { await vm.uploadPhotoItem(item, kind: .video, auth: auth) }
                    }

                    Button { showFileImporter = true } label: {
                        uploadButtonLabel("Import script or document", icon: "doc", loading: false)
                    }
                    .fileImporter(
                        isPresented: $showFileImporter,
                        allowedContentTypes: [.pdf, .plainText, .mpeg4Movie, .quickTimeMovie, .image],
                        allowsMultipleSelection: false
                    ) { result in
                        Task { await vm.importFile(result, auth: auth) }
                    }

                    if let poster = vm.posterUrl {
                        Label("Poster uploaded", systemImage: "checkmark.circle.fill")
                            .font(STFont.body(12))
                            .foregroundStyle(STColor.success)
                        Text(poster).font(STFont.body(10)).foregroundStyle(STColor.textMuted).lineLimit(1)
                    }
                    if let video = vm.videoUrl {
                        Label("Video uploaded", systemImage: "checkmark.circle.fill")
                            .font(STFont.body(12))
                            .foregroundStyle(STColor.success)
                        Text(video).font(STFont.body(10)).foregroundStyle(STColor.textMuted).lineLimit(1)
                    }
                }
                .padding(16)
                .glassPanel()

                if let message = vm.statusMessage {
                    Text(message)
                        .font(STFont.body(13))
                        .foregroundStyle(vm.succeeded ? STColor.success : STColor.danger)
                }

                if vm.uploadProgress > 0 && vm.uploadProgress < 1 {
                    ProgressView(value: vm.uploadProgress)
                        .tint(STColor.primary)
                }

                Button { Task { await vm.submit(auth: auth) } } label: {
                    HStack {
                        if vm.isSubmitting { ProgressView().tint(.black) }
                        Text(vm.isSubmitting ? "Saving…" : "Save catalogue entry")
                            .font(STFont.body(15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(STColor.brandGradient))
                }
                .disabled(vm.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSubmitting)
            }
            .padding(16)
        }
        .background(STColor.background)
    }

    private func uploadButtonLabel(_ title: String, icon: String, loading: Bool) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(STColor.primary)
            Text(title).font(STFont.body(14, weight: .medium)).foregroundStyle(STColor.textPrimary)
            Spacer()
            if loading { ProgressView().tint(STColor.primary) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(STFont.body(12, weight: .medium)).foregroundStyle(STColor.textMuted)
            TextField(title, text: text).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
        }
    }

    private func fieldMultiline(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(STFont.body(12, weight: .medium)).foregroundStyle(STColor.textMuted)
            TextField(title, text: text, axis: .vertical).lineLimit(2...6).padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
        }
    }
}

@MainActor
private final class UploadViewModel: ObservableObject {
    enum MediaKind { case poster, video }

    @Published var title = ""
    @Published var logline = ""
    @Published var description = ""
    @Published var type = "FILM"
    @Published var posterUrl: String?
    @Published var videoUrl: String?
    @Published var isSubmitting = false
    @Published var isUploadingPoster = false
    @Published var isUploadingVideo = false
    @Published var uploadProgress: Double = 0
    @Published var statusMessage: String?
    @Published var succeeded = false
    @Published var savedContentId: String?

    let contentTypes = ["FILM", "SHORT", "SERIES", "SHOW", "PODCAST", "DOCUMENTARY"]
    private let client = APIClient.shared

    func uploadPhotoItem(_ item: PhotosPickerItem?, kind: MediaKind, auth: AuthService) async {
        guard let item else { return }
        if kind == .poster { isUploadingPoster = true } else { isUploadingVideo = true }
        defer {
            isUploadingPoster = false
            isUploadingVideo = false
            uploadProgress = 0
        }
        do {
            let data: Data
            let contentType: String
            let fileName: String
            if kind == .poster {
                guard let loaded = try await item.loadTransferable(type: Data.self) else { return }
                data = loaded
                contentType = "image/jpeg"
                fileName = "poster-\(UUID().uuidString).jpg"
            } else {
                if let movie = try await item.loadTransferable(type: Data.self) {
                    data = movie
                    contentType = "video/mp4"
                    fileName = "video-\(UUID().uuidString).mp4"
                } else { return }
            }
            uploadProgress = 0.2
            let result = try await MediaUploadService.upload(data: data, fileName: fileName, contentType: contentType)
            uploadProgress = 1
            let url = result.storageRef ?? result.publicUrl ?? result.sourceUrl
            if kind == .poster { posterUrl = url } else { videoUrl = url }
            statusMessage = kind == .poster ? "Poster uploaded." : "Video uploaded."
            succeeded = true
        } catch {
            statusMessage = error.localizedDescription
            succeeded = false
        }
    }

    func importFile(_ result: Result<[URL], Error>, auth: AuthService) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let contentType = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "application/octet-stream"
            let result = try await MediaUploadService.upload(data: data, fileName: url.lastPathComponent, contentType: contentType)
            if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
                videoUrl = result.storageRef ?? result.publicUrl
            } else {
                posterUrl = result.storageRef ?? result.publicUrl
            }
            statusMessage = "File uploaded."
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
            type: type,
            description: description.nilIfEmpty,
            posterUrl: posterUrl,
            videoUrl: videoUrl,
            reviewStatus: "DRAFT"
        )

        do {
            if let item: CreatorContentItem = try? await client.post("/api/creator/content", body: body) {
                savedContentId = item.id
                succeeded = true
                statusMessage = "Catalogue entry saved."
            } else {
                _ = try await client.post("/api/creator/content", body: body) as OkResponse
                succeeded = true
                statusMessage = "Catalogue entry saved."
            }
        } catch {
            succeeded = false
            statusMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
