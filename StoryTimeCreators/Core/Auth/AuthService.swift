import Foundation
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: CreatorUser?
    @Published var lastError: String?
    @Published var isBusy = false

    private let client = APIClient.shared

    func applyProfile(_ user: CreatorUser) {
        currentUser = user
    }

    func restoreSession() async {
        do {
            let me: CreatorUser = try await client.get("/api/me")
            guard me.isCreatorPortalEligible else {
                clearLocalSession()
                return
            }
            currentUser = me
            isAuthenticated = true
        } catch {
            clearLocalSession()
        }
    }

    func signIn(email: String, password: String) async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        do {
            let csrf: CSRFResponse = try await client.get("/api/auth/csrf")
            let fields: [String: String] = [
                "csrfToken": csrf.csrfToken,
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                "password": password,
                "selectedRole": AppConfig.creatorRole,
                "json": "true",
                "redirect": "false",
                "callbackUrl": "/creator/command-center",
            ]
            let (data, http) = try await client.postForm(
                path: "/api/auth/callback/credentials-creator",
                fields: fields
            )

            if !(200..<400).contains(http.statusCode) {
                let msg = String(data: data, encoding: .utf8) ?? "Sign in failed."
                throw APIError.http(http.statusCode, msg)
            }

            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = obj["error"] as? String, !error.isEmpty {
                    throw APIError.http(
                        401,
                        error == "CredentialsSignin"
                            ? "Invalid email or password."
                            : error
                    )
                }
            }

            let me: CreatorUser = try await client.get("/api/me")
            guard me.isCreatorPortalEligible else {
                clearSessionCookies()
                throw APIError.http(
                    403,
                    "This app is for content creator accounts only."
                )
            }
            currentUser = me
            isAuthenticated = true
        } catch let api as APIError {
            lastError = api.errorDescription
            clearLocalSession()
        } catch {
            lastError = error.localizedDescription
            clearLocalSession()
        }
    }

    func signOut() async {
        do {
            let csrf: CSRFResponse = try await client.get("/api/auth/csrf")
            _ = try? await client.postForm(
                path: "/api/auth/signout",
                fields: ["csrfToken": csrf.csrfToken, "json": "true", "callbackUrl": "/"]
            )
        } catch {
            // Clear locally regardless
        }
        clearSessionCookies()
        clearLocalSession()
    }

    private func clearLocalSession() {
        currentUser = nil
        isAuthenticated = false
    }

    private func clearSessionCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: AppConfig.apiBaseURL) else { return }
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

private struct CSRFResponse: Decodable {
    let csrfToken: String
}
