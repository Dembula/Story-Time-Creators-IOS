import SafariServices
import SwiftUI
import WebKit

// MARK: - SFSafariViewController (password reset, external-only pages)

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(STColor.primary)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - In-app browser modes

enum WebBrowserMode {
    /// Signed-in studio / billing pages — inject app session cookies.
    case account
    /// Fresh creator signup: terms → register → plan / PayFast — export cookies when session ready.
    case signUp
    /// Pay-per-film (or other) checkout with existing session cookies.
    case checkout
}

/// Secure in-app browser with host lock indicator and cookie sync (mirrors Universe viewer app).
struct AuthenticatedWebBrowser: View {
    let url: URL
    var title: String = "Story Time"
    var mode: WebBrowserMode = .account
    var onSessionEstablished: (() -> Void)? = nil
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var pageTitle: String = ""
    @State private var currentHost: String = ""
    @State private var statusHint: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(STColor.success)
                    Text(currentHost.isEmpty ? (url.host ?? "story-time.online") : currentHost)
                        .font(STFont.body(11, weight: .semibold))
                        .foregroundStyle(STColor.textMuted)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(STColor.surfaceElevated.opacity(0.6))

                if (mode == .signUp || mode == .checkout), !statusHint.isEmpty {
                    Text(statusHint)
                        .font(STFont.body(11, weight: .medium))
                        .foregroundStyle(STColor.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(STColor.primary.opacity(0.12))
                }

                AuthWebView(
                    url: url,
                    mode: mode,
                    pageTitle: $pageTitle,
                    currentHost: $currentHost,
                    statusHint: $statusHint,
                    onSessionEstablished: { onSessionEstablished?() },
                    onFinished: {
                        onFinished?()
                        dismiss()
                    }
                )
            }
            .background(STColor.background)
            .navigationTitle(pageTitle.isEmpty ? title : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .signUp ? "Cancel" : "Done") {
                        onFinished?()
                        dismiss()
                    }
                    .foregroundStyle(STColor.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(mode == .signUp)
    }
}

// MARK: - WKWebView

private struct AuthWebView: UIViewRepresentable {
    let url: URL
    let mode: WebBrowserMode
    @Binding var pageTitle: String
    @Binding var currentHost: String
    @Binding var statusHint: String
    var onSessionEstablished: (() -> Void)?
    var onFinished: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = mode == .signUp ? .nonPersistent() : .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.applicationNameForUserAgent = "StoryTimeCreatorsiOS"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = DeviceIdentity.userAgent
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = mode != .signUp
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .black

        Task {
            if mode == .account || mode == .checkout {
                await CookieBridge.injectSharedCookies(into: webView.configuration.websiteDataStore)
            }
            await MainActor.run {
                var request = URLRequest(url: url)
                request.setValue(DeviceIdentity.userAgent, forHTTPHeaderField: "User-Agent")
                webView.load(request)
            }
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: AuthWebView
        private var didNotifySession = false
        private var didFinishCheckout = false

        init(_ parent: AuthWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.pageTitle = webView.title ?? ""
            parent.currentHost = webView.url?.host ?? ""

            if parent.mode == .signUp {
                injectSignupUICleanup(webView)
                updateSignupHint(for: webView.url)
            } else if parent.mode == .checkout {
                updateCheckoutHint(for: webView.url)
            }

            Task {
                if parent.mode == .account || parent.mode == .signUp || parent.mode == .checkout {
                    await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)
                }
                await checkProgress(webView)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            parent.currentHost = url.host ?? parent.currentHost

            if parent.mode == .signUp, shouldBlockSignupNavigation(url) {
                decisionHandler(.cancel)
                webView.load(URLRequest(url: AppConfig.creatorSignUpURLForApp))
                return
            }
            decisionHandler(.allow)
        }

        private func shouldBlockSignupNavigation(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased(), host.contains("story-time.online") else {
                // External payment hosts (PayFast, banks) must be allowed.
                return false
            }
            let path = url.path.lowercased()
            if path == "/" || path.isEmpty || path == "/about" || path == "/home" {
                return true
            }
            // Keep creators out of the viewer marketing funnel during signup.
            if path.hasPrefix("/browse") || path.hasPrefix("/profiles") {
                // Allow only if they already finished as multi-role; usually block
                return true
            }
            if path.hasPrefix("/auth/signup") && !path.contains("creator") {
                return true
            }
            return false
        }

        private func injectSignupUICleanup(_ webView: WKWebView) {
            let js = """
            (function() {
              try {
                document.documentElement.setAttribute('data-st-ios-creators', '1');
                var hide = function(el) {
                  if (!el) return;
                  el.style.setProperty('display','none','important');
                  el.setAttribute('aria-hidden','true');
                };
                var nodes = document.querySelectorAll('a, button, [role="link"]');
                for (var i = 0; i < nodes.length; i++) {
                  var el = nodes[i];
                  var t = (el.textContent || '').replace(/\\s+/g,' ').trim().toLowerCase();
                  var href = ((el.getAttribute && el.getAttribute('href')) || '').trim();
                  if (t.indexOf('back to home') !== -1 || t === 'home' || href === '/' || href === 'https://story-time.online/' || href === 'https://story-time.online') {
                    hide(el);
                  }
                }
              } catch (e) {}
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func updateSignupHint(for url: URL?) {
            guard let path = url?.path.lowercased() else { return }
            if path.contains("terms") {
                parent.statusHint = "Accept the creator terms, then continue"
            } else if path.contains("signup") {
                parent.statusHint = "Create your account — choose your creator type carefully"
            } else if path.contains("onboarding") || path.contains("license") {
                parent.statusHint = "Choose a plan. Pay-per-film is free now; yearly plans open PayFast here."
            } else if path.contains("payfast") || path.contains("payment") {
                parent.statusHint = "Complete payment securely — stay in this window until finished"
            } else if path.contains("command-center") || path.contains("dashboard") {
                parent.statusHint = "Account ready — opening the app…"
            } else {
                parent.statusHint = "Stay in this window until your creator account is ready"
            }
        }

        private func updateCheckoutHint(for url: URL?) {
            guard let path = url?.path.lowercased() else { return }
            if path.contains("payfast") || path.contains("demo-checkout") || path.contains("payments/") {
                parent.statusHint = "Complete payment, then return — we’ll refresh your catalogue"
            } else if path.contains("dashboard") || path.contains("command-center") || path.contains("catalogue") {
                parent.statusHint = "Payment processed — tap Done if this screen doesn’t close"
            } else {
                parent.statusHint = "Secure Story Time checkout"
            }
        }

        @MainActor
        private func checkProgress(_ webView: WKWebView) async {
            guard let path = webView.url?.path.lowercased() else { return }

            if parent.mode == .signUp {
                guard !didNotifySession else { return }
                let finishHints = [
                    "/creator/command-center",
                    "/creator/dashboard",
                    "/music-creator/dashboard",
                    "/creator/upload",
                    "/creator/catalogue",
                ]
                let onFinish = finishHints.contains(where: { path == $0 || path.hasPrefix($0 + "/") })
                    && !path.contains("onboarding")
                    && !path.contains("auth/")
                guard onFinish else { return }

                await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)
                if (try? await AuthService.shared.establishSessionFromCookies()) == true {
                    didNotifySession = true
                    parent.onSessionEstablished?()
                }
                return
            }

            if parent.mode == .checkout {
                guard !didFinishCheckout else { return }
                let done =
                    (path.contains("payments/return") && !path.contains("payfast-checkout"))
                    || path.hasPrefix("/creator/dashboard")
                    || path.hasPrefix("/creator/command-center")
                    || path.hasPrefix("/creator/catalogue")
                    || path.hasPrefix("/creator/upload")
                // Wait until after payment return settlement — avoid closing on intermediate checkout page.
                if done, path.contains("payments/return") || !path.contains("payfast") {
                    // Brief dwell if on return so status poll can finish on web.
                    if path.contains("payments/return") {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                    }
                    await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)
                    didFinishCheckout = true
                    parent.onFinished?()
                }
            }
        }
    }
}

// MARK: - Cookie bridge (shared HTTPCookieStorage ↔ WKWebView)

enum CookieBridge {
    static func injectSharedCookies(into store: WKWebsiteDataStore) async {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        let jar = store.httpCookieStore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for cookie in cookies {
                group.enter()
                jar.setCookie(cookie) { group.leave() }
            }
            group.notify(queue: .main) { continuation.resume() }
        }
    }

    static func exportCookies(from store: WKWebsiteDataStore) async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            store.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
        let storage = HTTPCookieStorage.shared
        for cookie in cookies {
            let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard host.contains("story-time.online") || cookie.domain.contains("story-time") else { continue }
            storage.setCookie(cookie)
        }
    }
}
