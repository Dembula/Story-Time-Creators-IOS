import Foundation

enum AppConfig {
    /// Production Story Time origin (API + creator web portal).
    static let webBaseURL = URL(string: "https://story-time.online")!
    static let apiBaseURL = webBaseURL

    static let appName = "Story Time Creators"
    /// Primary role for the native Creators app (film / catalogue portal).
    static let creatorRole = "CONTENT_CREATOR"

    // MARK: - Auth (opened in-app via secure browser)

    /// Create account — terms gate → signup form → plan selection / PayFast on web.
    static let creatorSignUpURLForApp = URL(
        string: "https://story-time.online/auth/creator/signup/terms?source=ios_app&platform=ios"
    )!
    static let creatorSignUpURL = creatorSignUpURLForApp
    static let creatorSignInWebURL = URL(string: "https://story-time.online/auth/creator/signin")!
    static let forgotPasswordURL = URL(string: "https://story-time.online/auth/forgot-password")!

    // MARK: - Creator studio web (cookie-synced WKWebView)

    static let creatorCommandCenterURL = webBaseURL.appendingPathComponent("creator/command-center")
    static let creatorDashboardURL = webBaseURL.appendingPathComponent("creator/dashboard")
    static let creatorLicenseOnboardingURL = webBaseURL.appendingPathComponent("creator/onboarding/license")
    static let creatorAccountURL = webBaseURL.appendingPathComponent("creator/account")
    static let creatorUploadURL = webBaseURL.appendingPathComponent("creator/upload")
    static let creatorCatalogueURL = webBaseURL.appendingPathComponent("creator/catalogue")
    static let creatorOriginalsURL = webBaseURL.appendingPathComponent("creator/originals")
    static let creatorRevenueURL = webBaseURL.appendingPathComponent("creator/command-center")

    static func webURL(path: String) -> URL {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return webBaseURL.appendingPathComponent(trimmed)
    }

    /// Feature flags — digital goods / SaaS checkout stays on the multi-platform web studio (Apple 3.1.3 / reader-tools companion pattern).
    enum Features {
        /// Marketplace browse / roster / inquire tools stay available; payment checkouts stay on web studio.
        static let marketplacePaymentsEnabled = false
        static let auditionListingPaymentsEnabled = false
        static let executiveScriptReviewPaymentsEnabled = false
        /// Catalogue per-film fee is paid via web checkout (PayFast), not StoreKit.
        static let catalogueUploadCheckoutEnabled = true
        /// License / plan change opens web onboarding or billing.
        static let licensePurchaseEnabled = true
        static let ipMarketplacePurchaseEnabled = false
        static let walletPayoutUIEnabled = false
    }
}
