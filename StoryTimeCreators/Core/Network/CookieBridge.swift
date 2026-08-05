import Foundation
import WebKit

/// Bidirectional cookie bridge between `WKWebView` and the app `URLSession` jar.
/// Critical for in-app web signup → native session handoff (NextAuth).
///
/// Matches the proven Story Time Universe iOS pattern: export WK cookies with host variants
/// and force a `Cookie:` header on API calls, because URLSession domain matching is picky
/// with `__Secure-next-auth.*` tokens exported from WebKit.
enum CookieBridge {
    static func injectSharedCookies(into store: WKWebsiteDataStore) async {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        let jar = store.httpCookieStore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for cookie in cookies where isStoryTimeCookie(cookie) {
                group.enter()
                jar.setCookie(cookie) { group.leave() }
            }
            group.notify(queue: .main) { continuation.resume() }
        }
    }

    /// Push WK cookies into `HTTPCookieStorage.shared` used by `APIClient`.
    static func exportCookies(from store: WKWebsiteDataStore) async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            store.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
        applyToSharedStorage(cookies)
    }

    /// Collect every Story Time cookie currently visible in shared storage.
    static func sharedStoryTimeCookies() -> [HTTPCookie] {
        (HTTPCookieStorage.shared.cookies ?? []).filter(isStoryTimeCookie)
    }

    /// Whether the shared jar currently holds a NextAuth-style session token.
    static func hasSessionCookie() -> Bool {
        sharedStoryTimeCookies().contains { cookie in
            let name = cookie.name.lowercased()
            return name.contains("session-token")
                || name.contains("session_token")
                || name.contains("next-auth.session")
                || (name.contains("next-auth") && name.contains("session"))
                || name == "next-auth.session-token"
                || name.hasPrefix("__secure-next-auth.session-token")
                || name.hasPrefix("__host-next-auth.session-token")
        }
    }

    /// Build a `Cookie:` header value for an API request to the production origin.
    static func cookieHeader(for url: URL) -> String? {
        let storage = HTTPCookieStorage.shared
        let matching = storage.cookies(for: url) ?? []
        var cookies = matching

        // Fallback: include session-related cookies for story-time even if domain match is picky.
        if matching.isEmpty
            || !matching.contains(where: {
                $0.name.lowercased().contains("session") || $0.name.contains("next-auth")
            })
        {
            for cookie in sharedStoryTimeCookies() {
                if !cookies.contains(where: { $0.name == cookie.name && $0.domain == cookie.domain }) {
                    cookies.append(cookie)
                }
            }
        }
        guard !cookies.isEmpty else { return nil }
        let header = HTTPCookie.requestHeaderFields(with: cookies)
        return header["Cookie"]
    }

    // MARK: - Internals

    private static func applyToSharedStorage(_ cookies: [HTTPCookie]) {
        let storage = HTTPCookieStorage.shared
        for cookie in cookies {
            guard isStoryTimeCookie(cookie) else { continue }

            // Always store the original cookie as WebKit produced it.
            storage.setCookie(cookie)

            // Also plant domain/path variants so URLSession matches api/web host reliably.
            for variant in domainVariants(of: cookie) {
                storage.setCookie(variant)
            }
        }
    }

    static func isStoryTimeCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.lowercased()
        let name = cookie.name.lowercased()
        if domain.contains("story-time.online") || domain.contains("story-time") { return true }
        if name.contains("next-auth")
            || name.hasPrefix("__secure-next-auth")
            || name.hasPrefix("__host-next-auth")
        {
            return true
        }
        if name.hasPrefix("st_") { return true }
        return false
    }

    /// Produce safe host-matching copies; never invent broken `__Host-` cookies with Domain.
    private static func domainVariants(of cookie: HTTPCookie) -> [HTTPCookie] {
        // `__Host-` cookies MUST NOT have a Domain attribute — skip variants.
        if cookie.name.hasPrefix("__Host-") {
            return []
        }

        let hosts = ["story-time.online", ".story-time.online", "www.story-time.online"]
        var result: [HTTPCookie] = []
        for host in hosts {
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: cookie.name,
                .value: cookie.value,
                .path: cookie.path.isEmpty ? "/" : cookie.path,
                .domain: host,
            ]
            if cookie.isSecure || cookie.name.hasPrefix("__Secure-") {
                props[.secure] = "TRUE"
            }
            if let exp = cookie.expiresDate {
                props[.expires] = exp
            }
            // Do NOT force SameSite — some NextAuth builds reject rewritten policies.
            if let rebuilt = HTTPCookie(properties: props) {
                result.append(rebuilt)
            }
        }
        return result
    }
}
