import Foundation
import AuthenticationServices
import Combine
import UIKit

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: CreatorUser?
    @Published var lastError: String?
    @Published var isBusy = false

    private let client = APIClient.shared
    private var webAuthSession: ASWebAuthenticationSession?

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

    func signIn(email: String, password: String, selectedRole: String = AppConfig.creatorRole) async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        do {
            let csrf: CSRFResponse = try await client.get("/api/auth/csrf")
            let fields: [String: String] = [
                "csrfToken": csrf.csrfToken,
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                "password": password,
                "selectedRole": selectedRole,
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

            // NextAuth may return JSON with url / error
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = obj["error"] as? String, !error.isEmpty {
                    throw APIError.http(401, error == "CredentialsSignin"
                        ? "Invalid email or password, or no creator account for this type."
                        : error)
                }
            }

            let me: CreatorUser = try await client.get("/api/me")
            guard me.isCreatorPortalEligible else {
                throw APIError.forbidden
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

    func signInWithApple() {
        lastError = nil
        startOAuth(provider: "apple")
    }

    func signInWithGoogle() {
        lastError = nil
        startOAuth(provider: "google")
    }

    func signInWithGitHub() {
        lastError = nil
        startOAuth(provider: "github")
    }

    /// Native Apple credential path — exchanges via NextAuth Apple OAuth web flow when possible.
    func completeNativeApple(identityToken: String?, email: String?, fullName: PersonNameComponents?) async {
        // Prefer the production NextAuth Apple provider (session cookies) via ASWebAuthenticationSession.
        // Native token exchange requires a dedicated backend endpoint; use OAuth web completion for parity.
        startOAuth(provider: "apple")
        _ = identityToken
        _ = email
        _ = fullName
    }

    func handleOAuthCallback(url: URL) {
        Task { await finishOAuth() }
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

    private func startOAuth(provider: String) {
        isBusy = true
        let callback = AppConfig.oauthCallbackURL.absoluteString
        let encoded = callback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? callback
        guard let url = URL(string: "\(AppConfig.apiBaseURL.absoluteString)/api/auth/signin/\(provider)?callbackUrl=\(encoded)") else {
            lastError = "Could not start \(provider) sign-in."
            isBusy = false
            return
        }

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: AppConfig.oauthCallbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                if let error {
                    if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.lastError = error.localizedDescription
                    }
                    return
                }
                _ = callbackURL
                await self.finishOAuth()
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        session.start()
    }

    private func finishOAuth() async {
        do {
            let me: CreatorUser = try await client.get("/api/me")
            guard me.isCreatorPortalEligible else {
                lastError = "Signed in, but this account is not a creator portal user. Use Creator Sign In on the web to attach a creator role, then try again."
                clearLocalSession()
                return
            }
            currentUser = me
            isAuthenticated = true
        } catch {
            lastError = "Apple / OAuth sign-in did not establish a creator session. Try again or use email."
            clearLocalSession()
        }
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

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        return scenes.first?.windows.first ?? ASPresentationAnchor()
    }
}

private struct CSRFResponse: Decodable {
    let csrfToken: String
}
