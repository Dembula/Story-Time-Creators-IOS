import Foundation

enum AppConfig {
    /// Production Story Time API origin (same backend as the creator web portal).
    static let apiBaseURL = URL(string: "https://story-time.online")!

    static let appName = "Story Time Creators"
    /// Only content creator accounts are supported in this app.
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
