import Foundation

enum AppConfig {
    /// Production Story Time origin (API + creator web portal).
    static let webBaseURL = URL(string: "https://story-time.online")!
    static let apiBaseURL = webBaseURL

    static let appName = "Story Time Creators"
    /// Primary role for the native Creators app (film / catalogue portal).
    static let creatorRole = "CONTENT_CREATOR"

    // MARK: - Auth (native signup; Safari only for legal + password reset)

    /// Legacy web signup (not used for account creation in the app; native + StoreKit only).
    static let creatorSignUpURLForApp = URL(
        string: "https://story-time.online/auth/creator/signup/terms?source=ios_app&platform=ios&billing=storekit"
    )!
    static let creatorSignUpURL = creatorSignUpURLForApp
    static let creatorSignInWebURL = URL(string: "https://story-time.online/auth/creator/signin")!
    static let forgotPasswordURL = URL(string: "https://story-time.online/auth/forgot-password")!
    /// Live legal pages (production returns 200; bare `/terms` and `/privacy` 404).
    static let termsOfUseURL = URL(string: "https://story-time.online/legal/terms")!
    static let privacyPolicyURL = URL(string: "https://story-time.online/legal/privacy")!

    // MARK: - Creator studio web (cookie-synced WKWebView)

    static let creatorCommandCenterURL = webBaseURL.appendingPathComponent("creator/command-center")
    static let creatorDashboardURL = webBaseURL.appendingPathComponent("creator/dashboard")
    static let creatorLicenseOnboardingURL = webBaseURL.appendingPathComponent("creator/onboarding/license")
    static let creatorAccountURL = webBaseURL.appendingPathComponent("creator/account")
    static let creatorUploadURL = webBaseURL.appendingPathComponent("creator/upload")
    static let creatorCatalogueURL = webBaseURL.appendingPathComponent("creator/catalogue")
    static let creatorOriginalsURL = webBaseURL.appendingPathComponent("creator/originals")
    static let creatorRevenueURL = webBaseURL.appendingPathComponent("creator/command-center")
    /// Web fallback page for account deletion (always prefer in-app delete first).
    static let accountDeleteHelpURL = webBaseURL.appendingPathComponent("auth/delete-account")

    static func webURL(path: String) -> URL {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return webBaseURL.appendingPathComponent(trimmed)
    }

    // MARK: - App Store In-App Purchase product IDs
    // Create matching non-consumable / auto-renewable / consumable products in App Store Connect.

    enum IAP {
        /// Pay-per-film plan activation (free at selection; per-title fee is separate consumable).
        /// Not sold — activated without charge via the API after user selects the plan.
        static let planPerFilmPackage = "PER_FILM"

        /// Catalogue unlimited — 1 year access.
        static let uploadYearly = "online.storytime.creators.sub.upload.yearly"
        /// Full production pipeline — monthly.
        static let pipelineMonthly = "online.storytime.creators.sub.pipeline.monthly"
        /// Full production pipeline — yearly.
        static let pipelineYearly = "online.storytime.creators.sub.pipeline.yearly"
        /// One catalogue film submission fee (pay-per-film license).
        static let perFilmUpload = "online.storytime.creators.upload.perfilm"

        static var subscriptionProductIds: [String] {
            [uploadYearly, pipelineMonthly, pipelineYearly]
        }

        static var consumableProductIds: [String] {
            [perFilmUpload]
        }

        static var allProductIds: [String] {
            subscriptionProductIds + consumableProductIds
        }
    }

    /// Feature flags for App Review / monetization.
    enum Features {
        /// Digital creator plans and upload fees use StoreKit In-App Purchase (Guideline 3.1.1).
        static let storeKitBillingEnabled = true
        /// Do not open PayFast / web checkouts for digital catalogue services on iOS.
        static let webDigitalCheckoutEnabled = false

        static let marketplacePaymentsEnabled = false
        static let auditionListingPaymentsEnabled = false
        static let executiveScriptReviewPaymentsEnabled = false
        /// Per-film upload fee via StoreKit when storeKitBillingEnabled.
        static let catalogueUploadCheckoutEnabled = true
        static let licensePurchaseEnabled = true
        static let ipMarketplacePurchaseEnabled = false
        static let walletPayoutUIEnabled = false
    }
}
