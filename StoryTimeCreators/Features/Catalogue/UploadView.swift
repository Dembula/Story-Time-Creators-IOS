import SwiftUI

struct UploadView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm = UploadViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Catalogue Upload")

                NoPayBanner(
                    text: "Save drafts and metadata here. Checkout and per-film upload payments are not available in the Creators iOS app — complete payment on the web studio when you are ready to publish."
                )

                VStack(alignment: .leading, spacing: 14) {
                    field("Title", text: $vm.title)
                    Picker("Type", selection: $vm.type) {
                        ForEach(vm.contentTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Logline")
                            .font(STFont.body(12, weight: .medium))
                            .foregroundStyle(STColor.textMuted)
                        TextField("Short description", text: $vm.logline, axis: .vertical)
                            .lineLimit(2...5)
                            .font(STFont.body(14))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                            .foregroundStyle(STColor.textPrimary)
                    }
                }
                .padding(16)
                .glassPanel()

                if let message = vm.statusMessage {
                    Text(message)
                        .font(STFont.body(13))
                        .foregroundStyle(vm.succeeded ? STColor.success : STColor.danger)
                        .padding(.horizontal, 4)
                }

                Button {
                    Task { await vm.submitDraft(auth: auth) }
                } label: {
                    HStack {
                        if vm.isSubmitting {
                            ProgressView().tint(.black)
                        }
                        Text("Save draft")
                            .font(STFont.body(15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(STColor.brandGradient))
                }
                .disabled(vm.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSubmitting)

                EmptyStateView(
                    title: "Draft only on iOS",
                    subtitle: "Video upload, licensing, and checkout remain on storytimecreators.com.",
                    systemImage: "arrow.up.doc"
                )
            }
            .padding(16)
        }
        .background(STColor.background)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(STFont.body(12, weight: .medium))
                .foregroundStyle(STColor.textMuted)
            TextField(title, text: text)
                .font(STFont.body(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.surfaceElevated))
                .foregroundStyle(STColor.textPrimary)
        }
    }
}

@MainActor
private final class UploadViewModel: ObservableObject {
    @Published var title = ""
    @Published var logline = ""
    @Published var type = "FILM"
    @Published var isSubmitting = false
    @Published var statusMessage: String?
    @Published var succeeded = false

    let contentTypes = ["FILM", "SHORT", "SERIES", "SHOW", "PODCAST", "DOCUMENTARY"]
    private let client = APIClient.shared

    func submitDraft(auth: AuthService) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isSubmitting = true
        statusMessage = nil
        defer { isSubmitting = false }

        let body = CreateContentDraftBody(
            title: trimmedTitle,
            type: type,
            logline: logline.nilIfEmpty,
            reviewStatus: "DRAFT"
        )

        do {
            _ = try await client.post("/api/creator/content", body: body) as CreateContentDraftResponse
            succeeded = true
            statusMessage = "Draft saved. Open the web studio to add media and publish."
            title = ""
            logline = ""
        } catch let error as APIError {
            if case .decoding = error {
                succeeded = true
                statusMessage = "Draft request sent. If it does not appear in My Catalogue, complete setup on the web studio."
                title = ""
                logline = ""
            } else {
                succeeded = false
                statusMessage = Self.mapError(error, auth: auth)
            }
        } catch {
            succeeded = false
            statusMessage = Self.mapError(error, auth: auth)
        }
    }

    private static func mapError(_ error: Error, auth: AuthService) -> String {
        if let api = error as? APIError, case .unauthorized = api {
            Task { await auth.signOut() }
            return api.errorDescription ?? "Please sign in again."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private struct CreateContentDraftBody: Encodable {
    var title: String
    var type: String
    var logline: String?
    var reviewStatus: String
}

private struct CreateContentDraftResponse: Decodable {
    var id: String?
    var title: String?
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
