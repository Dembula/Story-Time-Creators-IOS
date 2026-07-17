import Foundation

enum MediaUploadService {
    static func upload(data: Data, fileName: String, contentType: String) async throws -> UploadCompleteResponse {
        let client = APIClient.shared
        let presign: PresignResponse = try await client.post(
            "/api/upload/content-media/presign",
            body: PresignRequest(fileName: fileName, size: data.count, contentType: contentType)
        )

        guard let uploadURL = URL(string: presign.uploadUrl) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        let mime = presign.headers?.contentType ?? presign.contentType
        request.setValue(mime, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await client.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 0, "Upload to storage failed.")
        }

        return try await client.post(
            "/api/upload/content-media/complete",
            body: UploadCompleteRequest(key: presign.key, contentType: mime, fileName: fileName)
        )
    }
}
