import SafariServices
import SwiftUI
import WebKit

// MARK: - SFSafariViewController (password reset)

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

enum WebBrowserMode: Equatable {
    /// Signed-in studio pages — inject app session cookies.
    case account
    /// Fresh creator signup: terms → register → plan / PayFast → native session handoff.
    case signUp
    /// Already signed in; finish license/plan in web and return to the native shell.
    case planSetup
    /// Pay-per-film (or other) checkout with existing session cookies.
    case checkout

    var monitorsSessionHandoff: Bool {
        switch self {
        case .signUp, .planSetup, .checkout: return true
        case .account: return false
        }
    }

    var injectsSharedCookies: Bool {
        switch self {
        case .signUp: return false
        case .account, .planSetup, .checkout: return true
        }
    }

    var usesIsolatedCookieStore: Bool {
        self == .signUp
    }

    var showsStatusHint: Bool {
        switch self {
        case .signUp, .planSetup, .checkout: return true
        case .account: return false
        }
    }

    var blocksInteractiveDismissUntilReady: Bool {
        self == .signUp
    }
}

/// Secure in-app browser with host indicator and cookie sync.
///
/// **Sign-up / plan handoff:** Next.js often uses client-side `router.push` after plan selection,
/// so we cannot rely on a single `didFinish` alone. We continuously export WKWebView cookies
/// into `HTTPCookieStorage`, probe `/api/me` + `/api/auth/entry-redirect`, then establish a
/// native session and dismiss into the app dashboard.
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
    @State private var sessionReady = false

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

                if mode.showsStatusHint, !statusHint.isEmpty {
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
                    sessionReady: $sessionReady,
                    onSessionEstablished: {
                        sessionReady = true
                        onSessionEstablished?()
                        // Give AuthService a beat to publish, then dismiss the sheet.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            dismiss()
                        }
                    },
                    onFinished: {
                        onFinished?()
                        dismiss()
                    }
                )

                if (mode == .signUp || mode == .planSetup), sessionReady {
                    Button {
                        onSessionEstablished?()
                        dismiss()
                    } label: {
                        Text(mode == .planSetup ? "Continue" : "Continue to app")
                            .font(STFont.body(15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(STColor.brandGradient))
                    }
                    .padding(16)
                }
            }
            .background(STColor.background)
            .navigationTitle(pageTitle.isEmpty ? title : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(dismissLabel) {
                        if (mode == .signUp || mode == .planSetup), AuthService.shared.isAuthenticated {
                            onSessionEstablished?()
                        } else {
                            onFinished?()
                        }
                        dismiss()
                    }
                    .foregroundStyle(STColor.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(mode.blocksInteractiveDismissUntilReady && !sessionReady)
        .onAppear {
            switch mode {
            case .signUp:
                if statusHint.isEmpty {
                    statusHint = "Complete terms, account, and plan here. The app signs you in automatically when ready."
                }
            case .planSetup:
                if statusHint.isEmpty {
                    statusHint = "Activate your creator plan here. You’ll return to the app when it’s done."
                }
            case .checkout:
                if statusHint.isEmpty {
                    statusHint = "Complete payment securely — you’ll return when finished."
                }
            case .account:
                break
            }
        }
    }

    private var dismissLabel: String {
        if mode == .signUp { return sessionReady ? "Done" : "Cancel" }
        return "Done"
    }
}

// MARK: - WKWebView

private struct AuthWebView: UIViewRepresentable {
    let url: URL
    let mode: WebBrowserMode
    @Binding var pageTitle: String
    @Binding var currentHost: String
    @Binding var statusHint: String
    @Binding var sessionReady: Bool
    var onSessionEstablished: (() -> Void)?
    var onFinished: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Isolated cookie jar for signup so we don't inherit a prior stale session;
        // always export into HTTPCookieStorage when the native session is ready.
        config.websiteDataStore = mode.usesIsolatedCookieStore ? .nonPersistent() : .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.applicationNameForUserAgent = "StoryTimeCreatorsiOS"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = DeviceIdentity.userAgent
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = mode != .signUp
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .black
        context.coordinator.webView = webView

        Task {
            if mode.injectsSharedCookies {
                await CookieBridge.injectSharedCookies(into: webView.configuration.websiteDataStore)
            }
            await MainActor.run {
                var request = URLRequest(url: url)
                request.setValue(DeviceIdentity.userAgent, forHTTPHeaderField: "User-Agent")
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                webView.load(request)
                context.coordinator.startMonitoringIfNeeded()
            }
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Keep coordinator callbacks/bindings current (UIViewRepresentable only captures make time otherwise).
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: AuthWebView
        weak var webView: WKWebView?
        private var didNotifySession = false
        private var didFinishCheckout = false
        private var handoffInFlight = false
        private var pollTask: Task<Void, Never>?
        private var lastPolledPath: String = ""

        init(_ parent: AuthWebView) {
            self.parent = parent
        }

        deinit {
            pollTask?.cancel()
        }

        func startMonitoringIfNeeded() {
            guard parent.mode.monitorsSessionHandoff else { return }
            pollTask?.cancel()
            // ~4 minutes of 1.2s ticks — covers plan select + PayFast without depending on SPA didFinish.
            pollTask = Task { [weak self] in
                for _ in 0..<200 {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    guard !Task.isCancelled else { return }
                    guard let self else { return }
                    await self.tick()
                    if self.didNotifySession || self.didFinishCheckout { return }
                }
            }
        }

        func stopMonitoring() {
            pollTask?.cancel()
            pollTask = nil
        }

        @MainActor
        private func tick() async {
            guard let webView else { return }
            switch parent.mode {
            case .signUp, .planSetup:
                await tryCompleteCreatorHandoff(webView)
            case .checkout:
                await tryCompleteCheckout(webView)
            case .account:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.pageTitle = webView.title ?? ""
            parent.currentHost = webView.url?.host ?? ""

            switch parent.mode {
            case .signUp:
                injectSignupUICleanup(webView)
                updateSignupHint(for: webView.url)
            case .planSetup:
                updateSignupHint(for: webView.url)
            case .checkout:
                updateCheckoutHint(for: webView.url)
            case .account:
                break
            }

            Task {
                await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)
                await tick()
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

            // Catch SPA + full navigations early (client-side router.push may skip didFinish).
            if parent.mode.monitorsSessionHandoff {
                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)
                    await tick()
                }
            }

            if parent.mode == .signUp, shouldBlockSignupNavigation(url) {
                decisionHandler(.cancel)
                webView.load(URLRequest(url: AppConfig.creatorSignUpURLForApp))
                return
            }
            decisionHandler(.allow)
        }

        private func shouldBlockSignupNavigation(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased(), host.contains("story-time.online") else {
                return false // Allow PayFast / banks.
            }
            let path = url.path.lowercased()
            if path == "/" || path.isEmpty || path == "/about" || path == "/home" {
                return true
            }
            // Viewer funnel only.
            if path.hasPrefix("/browse") || path == "/profiles" || path.hasPrefix("/profiles/") {
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
                  if (t.indexOf('back to home') !== -1 || t === 'home'
                      || href === '/' || href === 'https://story-time.online/'
                      || href === 'https://story-time.online') {
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
                parent.statusHint = "Create your account — stay in this window"
            } else if path.contains("onboarding") || path.contains("license") || path.contains("subscription") {
                parent.statusHint = "Choose and activate your plan. When ready, the app signs you in automatically."
            } else if path.contains("payfast") || path.contains("payment") {
                parent.statusHint = "Complete payment securely — you’ll return to the app when done"
            } else if path.contains("command-center") || path.contains("dashboard") || path.hasPrefix("/creator") {
                parent.statusHint = "Almost done — opening your creator dashboard in the app…"
            } else {
                parent.statusHint = "Stay in this window until your creator account is ready"
            }
        }

        private func updateCheckoutHint(for url: URL?) {
            guard let path = url?.path.lowercased() else { return }
            if path.contains("payfast") || path.contains("demo-checkout") || path.contains("payments/") {
                parent.statusHint = "Complete payment, then return — we’ll refresh your catalogue"
            } else if path.contains("dashboard") || path.contains("command-center") || path.contains("catalogue") {
                parent.statusHint = "Payment processed — returning…"
            } else {
                parent.statusHint = "Secure Story Time checkout"
            }
        }

        @MainActor
        private func tryCompleteCreatorHandoff(_ webView: WKWebView) async {
            guard !didNotifySession, !handoffInFlight else { return }

            await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)

            let path = (webView.url?.path ?? "").lowercased()
            let full = (webView.url?.absoluteString ?? "").lowercased()
            if path != lastPolledPath {
                lastPolledPath = path
                updateSignupHint(for: webView.url)
            }

            // Fresh signup only: wait until past bare auth forms.
            if parent.mode == .signUp, isPureAuthForm(path) {
                return
            }

            // Quick pre-check: no NextAuth cookie in the jar yet → nothing to adopt.
            // Still try probe after export (covers __Host-tokens that may not match hasSessionCookie).
            // Probe only — do not set isAuthenticated until handoff.
            let hasSession = await AuthService.shared.probeCreatorCookieSession()
            guard hasSession else { return }

            let packageIncomplete = await AuthService.shared.probePackageNeedsSetup()
            let onOnboarding =
                path.contains("onboarding")
                || path.contains("/license")
                || path.contains("subscription")
            let onPayPath =
                path.contains("payfast")
                || full.contains("payfast")
                || (path.contains("payments/") && !path.contains("payments/return") && !path.contains("payment/return"))
            let studioDestination = isStudioDestination(path)
            let paymentSettled =
                path.contains("payments/return")
                || path.contains("payment/return")
                || path.contains("payments/success")
                || path.contains("payment/success")
                || full.contains("payment_status=complete")
                || full.contains("payment_status=success")

            // Keep the webview open while they pick a plan / finish payment.
            if packageIncomplete && (onOnboarding || onPayPath) && !paymentSettled && !studioDestination {
                parent.sessionReady = false
                parent.statusHint =
                    "Plan still needs activation. Finish selection or payment — the app signs you in automatically when ready."
                return
            }

            if packageIncomplete && !studioDestination && !paymentSettled {
                if parent.mode == .planSetup {
                    parent.statusHint = "Almost there — finish activating your plan in this window."
                }
                return
            }

            handoffInFlight = true
            parent.sessionReady = true
            parent.statusHint = parent.mode == .planSetup
                ? "Plan active — returning to your dashboard…"
                : "Account ready — opening the app…"
            // Final cookie settle (NextAuth session token can land a beat after SPA redirect).
            try? await Task.sleep(nanoseconds: 400_000_000)
            await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)

            // Two attempts — first export can race the last Set-Cookie after payment return.
            var opened = await AuthService.shared.establishSessionFromCookies()
            if !opened {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)
                opened = await AuthService.shared.establishSessionFromCookies()
            }
            guard opened else {
                handoffInFlight = false
                parent.sessionReady = false
                parent.statusHint = "Almost ready — activate your plan, then stay on this screen a moment."
                return
            }

            didNotifySession = true
            stopMonitoring()
            parent.onSessionEstablished?()
        }

        @MainActor
        private func tryCompleteCheckout(_ webView: WKWebView) async {
            guard !didFinishCheckout else { return }
            guard let path = webView.url?.path.lowercased() else { return }

            let done =
                path.contains("payments/return")
                || path.contains("payment/return")
                || path.hasPrefix("/creator/dashboard")
                || path.hasPrefix("/creator/command-center")
                || path.hasPrefix("/creator/catalogue")
                || path.hasPrefix("/creator/upload")

            if done, !path.contains("payfast-checkout") {
                if path.contains("payments/") {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                }
                await CookieBridge.exportCookies(from: webView.configuration.websiteDataStore)
                didFinishCheckout = true
                stopMonitoring()
                parent.onFinished?()
            }
        }

        private func isPureAuthForm(_ path: String) -> Bool {
            if path.isEmpty { return true }
            // Terms + bare register form — session may not exist yet (or leftover junk).
            if path.contains("/auth/creator/signup/terms") { return true }
            if path.contains("/auth/creator/signup") && !path.contains("onboarding") { return true }
            if path.contains("/auth/creator/signin") { return true }
            if path.contains("/auth/signin") { return true }
            if path.contains("/auth/signup") && !path.contains("creator") { return true }
            return false
        }

        private func isStudioDestination(_ path: String) -> Bool {
            let prefixes = [
                "/creator/command-center",
                "/creator/dashboard",
                "/creator/catalogue",
                "/creator/upload",
                "/creator/account",
                "/creator/projects",
                "/creator/network",
                "/music-creator/dashboard",
                "/company/",
                "/funders",
            ]
            return prefixes.contains { path == $0 || path.hasPrefix($0) }
                && !path.contains("onboarding")
                && !path.contains("/auth/")
        }
    }
}
