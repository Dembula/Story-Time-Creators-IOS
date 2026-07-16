import Foundation

enum AppConfig {
    /// Production Story Time API origin (same backend as the creator web portal).
    static let apiBaseURL = URL(string: "https://story-time.online")!

    /// Custom URL scheme used to complete OAuth (Apple / Google / GitHub) via ASWebAuthenticationSession.
    static let oauthCallbackScheme = "storytimecreators"
    static let oauthCallbackURL = URL(string: "\(oauthCallbackScheme)://auth/callback")!

    static let appName = "Story Time Creators"
    static let creatorRole = "CONTENT_CREATOR"

    /// Feature flags for this native client.
    enum Features {
        /// Marketplace browse / roster / inquire tools stay available; payment checkouts are disabled.
        static let marketplacePaymentsEnabled = false
        static let auditionListingPaymentsEnabled = false
        static let executiveScriptReviewPaymentsEnabled = false
        static let catalogueUploadCheckoutEnabled = false
        static let licensePurchaseEnabled = false
        static let ipMarketplacePurchaseEnabled = false
        static let walletPayoutUIEnabled = false
    }
}
