import Foundation
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: CreatorUser?
    /// Relative path on story-time.online when license/plan is incomplete (e.g. /creator/onboarding/license).
    @Published private(set) var pendingOnboardingPath: String?
    @Published var lastError: String?
    @Published var isBusy = false

    private let client = APIClient.shared

    var needsPlanSetup: Bool {
        guard let path = pendingOnboardingPath, !path.isEmpty else { return false }
        return path.contains("onboarding") || path.contains("license") || path.contains("subscription")
    }

    func applyProfile(_ user: CreatorUser) {
        currentUser = user
    }

    /// Quiet check: WK-exported cookies authenticate a creator eligible for this app.
    /// Does **not** publish `isAuthenticated` — used while the signup webview is still open
    /// so we don’t tear down the sign-in UI before plan activation finishes.
    func probeCreatorCookieSession() async -> Bool {
        // Primary: full /api/me with force-Cookie header (see CookieBridge).
        do {
            let me: CreatorUser = try await client.get("/api/me")
            if me.isCreatorPortalEligible { return true }
        } catch {
            // fall through to session probe
        }

        // Fallback: NextAuth session JSON (same cookie jar; useful if /api/me hiccups).
        struct SessionProbe: Decodable {
            struct User: Decodable {
                var id: String?
                var email: String?
                var role: String?
            }
            var user: User?
        }
        do {
            let session: SessionProbe = try await client.get("/api/auth/session")
            guard let user = session.user else { return false }
            let role = (user.role ?? "").uppercased()
            return role == AppConfig.creatorRole || role == "MUSIC_CREATOR"
        } catch {
            return false
        }
    }

    /// Whether entry-redirect still points at license / package onboarding.
    func probePackageNeedsSetup() async -> Bool {
        struct EntryRedirect: Decodable { var path: String? }
        do {
            let entry: EntryRedirect = try await client.get("/api/auth/entry-redirect")
            let path = entry.path ?? ""
            if path.isEmpty { return false }
            return path.contains("onboarding") || path.contains("license") || path.contains("subscription")
        } catch {
            // If cookies work for /me but entry-redirect fails, don't trap the user forever —
            // treat as unknown incomplete only when we have no alternative finish path.
            return true
        }
    }

    /// After web signup/checkout, re-read `/api/me` using exported cookies and open the app session.
    @discardableResult
    func establishSessionFromCookies() async -> Bool {
        do {
            let me: CreatorUser = try await client.get("/api/me")
            guard me.isCreatorPortalEligible else {
                return false
            }
            currentUser = me
            isAuthenticated = true
            await refreshPackageGate()
            return true
        } catch {
            return false
        }
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
            await refreshPackageGate()
        } catch {
            clearLocalSession()
        }
    }

    func signIn(email: String, password: String) async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            // Try film creator first, then music creator (same credentials provider; role selects session).
            if try await attemptCredentialsSignIn(email: trimmed, password: password, role: AppConfig.creatorRole) {
                return
            }
            if try await attemptCredentialsSignIn(email: trimmed, password: password, role: "MUSIC_CREATOR") {
                return
            }
            clearSessionCookies()
            throw APIError.http(
                403,
                "This app is for film and music creator accounts. Company marketplaces use the web studio."
            )
        } catch let api as APIError {
            lastError = api.errorDescription
            clearLocalSession()
        } catch {
            lastError = error.localizedDescription
            clearLocalSession()
        }
    }

    /// Returns true if session established; false if credentials ok but role ineligible; throws on auth failure.
    private func attemptCredentialsSignIn(email: String, password: String, role: String) async throws -> Bool {
        let csrf: CSRFResponse = try await client.get("/api/auth/csrf")
        let fields: [String: String] = [
            "csrfToken": csrf.csrfToken,
            "email": email,
            "password": password,
            "selectedRole": role,
            "json": "true",
            "redirect": "false",
            "callbackUrl": role == "MUSIC_CREATOR" ? "/music-creator/dashboard" : "/creator/command-center",
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
            return false
        }
        currentUser = me
        isAuthenticated = true
        await refreshPackageGate()
        return true
    }

    /// Mirrors web entry-redirect: unfinished license → onboarding path.
    func refreshPackageGate() async {
        struct EntryRedirect: Decodable { var path: String? }
        do {
            let entry: EntryRedirect = try await client.get("/api/auth/entry-redirect")
            let path = entry.path ?? ""
            if path.contains("onboarding") || path.contains("license") || path.contains("subscription") {
                pendingOnboardingPath = path
            } else {
                pendingOnboardingPath = nil
            }
        } catch {
            // Keep current gate — non-fatal (endpoint may 401 after partial session).
        }
    }

    func clearOnboardingGate() {
        pendingOnboardingPath = nil
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

    /// App Store 5.1.1(v) — permanently delete account via production API.
    func deleteAccount(password: String, confirmation: String = "DELETE") async throws {
        struct Body: Encodable {
            var confirmation: String
            var password: String
        }
        struct Response: Decodable {
            var ok: Bool?
            var error: String?
        }
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        do {
            let res: Response = try await client.post(
                "/api/account/delete",
                body: Body(confirmation: confirmation, password: password)
            )
            if let err = res.error, !err.isEmpty {
                lastError = err
                throw APIError.http(400, err)
            }
            clearSessionCookies()
            clearLocalSession()
        } catch let api as APIError {
            lastError = api.errorDescription
            throw api
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func clearLocalSession() {
        currentUser = nil
        isAuthenticated = false
        pendingOnboardingPath = nil
    }

    private func clearSessionCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: AppConfig.apiBaseURL) else { return }
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        // Also purge any leftover Story Time cookies that URLSession domain match may miss.
        for cookie in CookieBridge.sharedStoryTimeCookies() {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

private struct CSRFResponse: Decodable {
    let csrfToken: String
}
