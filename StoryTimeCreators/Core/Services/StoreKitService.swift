import Foundation
import StoreKit

/// Maps App Store products to backend package keys used by distribution-license + iOS purchase API.
enum CreatorStoreProduct: String, CaseIterable, Identifiable {
    case uploadYearly
    case pipelineMonthly
    case pipelineYearly
    case perFilmUpload

    var id: String { productId }

    var productId: String {
        switch self {
        case .uploadYearly: return AppConfig.IAP.uploadYearly
        case .pipelineMonthly: return AppConfig.IAP.pipelineMonthly
        case .pipelineYearly: return AppConfig.IAP.pipelineYearly
        case .perFilmUpload: return AppConfig.IAP.perFilmUpload
        }
    }

    /// Server POST package / billing for license selection.
    var licensePackage: String? {
        switch self {
        case .uploadYearly: return "UPLOAD_YEARLY"
        case .pipelineMonthly, .pipelineYearly: return "PIPELINE"
        case .perFilmUpload: return nil
        }
    }

    var licenseBilling: String? {
        switch self {
        case .uploadYearly: return "YEARLY"
        case .pipelineMonthly: return "MONTHLY"
        case .pipelineYearly: return "YEARLY"
        case .perFilmUpload: return nil
        }
    }

    var title: String {
        switch self {
        case .uploadYearly: return "Catalogue unlimited"
        case .pipelineMonthly: return "Full pipeline · monthly"
        case .pipelineYearly: return "Full pipeline · yearly"
        case .perFilmUpload: return "Per-film upload fee"
        }
    }

    var detail: String {
        switch self {
        case .uploadYearly:
            return "Unlimited catalogue uploads for one year. Charged through In-App Purchase."
        case .pipelineMonthly:
            return "Pre-production, production & post tools. Billed monthly via In-App Purchase."
        case .pipelineYearly:
            return "Same pipeline access with annual billing via In-App Purchase."
        case .perFilmUpload:
            return "Required before a pay-per-film title is submitted for admin review."
        }
    }

    var isUploadFee: Bool { self == .perFilmUpload }

    static func from(productId: String) -> CreatorStoreProduct? {
        allCases.first { $0.productId == productId }
    }
}

/// Free plan choice — no App Store product; activates pay-per-film with zero signup fee.
struct CreatorFreePlanOption {
    static let title = "Pay per film"
    static let detail = "No yearly fee. Pay a per-title upload fee with In-App Purchase when you submit each film for review."
    static let package = "PER_FILM"
}

/// Result of a StoreKit purchase including optional JWS (from `VerificationResult`, not `Transaction`).
struct StorePurchaseResult {
    let transaction: Transaction
    /// Signed payload for server verification — from `VerificationResult.jwsRepresentation`.
    let signedTransaction: String?
}

@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let client = APIClient.shared

    private init() {
        updatesTask = Task { await listenForTransactions() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let ids = AppConfig.IAP.allProductIds
            let loaded = try await Product.products(for: ids)
            products = loaded.sorted { $0.displayName < $1.displayName }
            if loaded.isEmpty {
                lastError = "Store products unavailable. Ensure In-App Purchases are configured for this build."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func product(for kind: CreatorStoreProduct) -> Product? {
        products.first { $0.id == kind.productId }
    }

    /// Purchase a StoreKit product. Caller must `reportPurchaseToServer` then finish is done there.
    @discardableResult
    func purchase(_ product: Product) async throws -> StorePurchaseResult {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            // JWS lives on VerificationResult (not Transaction) across current StoreKit SDKs.
            return StorePurchaseResult(
                transaction: transaction,
                signedTransaction: verification.jwsRepresentation
            )
        case .userCancelled:
            throw StoreError.userCancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    func purchase(_ kind: CreatorStoreProduct) async throws -> StorePurchaseResult {
        if products.isEmpty {
            await loadProducts()
        }
        guard let product = product(for: kind) else {
            throw StoreError.productUnavailable
        }
        return try await purchase(product)
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Activate pay-per-film plan on the server (no App Store charge).
    func activateFreePerFilmPlan() async throws {
        struct Body: Encodable {
            let package = CreatorFreePlanOption.package
            let source = "ios_storekit"
        }
        struct Response: Decodable {
            var requiresPayment: Bool?
            var error: String?
            var checkoutUrl: String?
        }
        let res: Response = try await client.post("/api/creator/distribution-license", body: Body())
        if let err = res.error, !err.isEmpty {
            throw StoreError.server(err)
        }
        // Free plan must not require web checkout.
        if res.requiresPayment == true, AppConfig.Features.storeKitBillingEnabled {
            throw StoreError.server("Pay-per-film should not require an upfront fee. Contact support.")
        }
    }

    /// Report a verified App Store transaction so the backend unlocks the plan or upload.
    func reportPurchaseToServer(
        purchase: StorePurchaseResult,
        kind: PurchaseKind,
        package: String? = nil,
        billing: String? = nil,
        contentId: String? = nil
    ) async throws {
        let transaction = purchase.transaction

        struct Body: Encodable {
            var productId: String
            var transactionId: String
            var originalTransactionId: String
            var signedTransaction: String?
            var kind: String
            var package: String?
            var billing: String?
            var contentId: String?
            var source: String
        }
        struct Response: Decodable {
            var ok: Bool?
            var error: String?
            var packageComplete: Bool?
            var reviewStatus: String?
        }

        let body = Body(
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            signedTransaction: purchase.signedTransaction,
            kind: kind.rawValue,
            package: package,
            billing: billing,
            contentId: contentId,
            source: "ios_app"
        )

        do {
            let res: Response = try await client.post("/api/creator/ios/purchase", body: body)
            if let err = res.error, !err.isEmpty {
                throw StoreError.server(err)
            }
        } catch let api as APIError {
            // Fallback when the verification endpoint is not deployed yet.
            if case .http(404, _) = api, kind == .creatorLicense, let package {
                try await legacyActivateLicenseAfterPurchase(package: package, billing: billing, transaction: transaction)
            } else if case .http(404, _) = api, kind == .contentUpload, let contentId {
                try await legacyMarkContentAfterPurchase(contentId: contentId, transaction: transaction)
            } else {
                throw api
            }
        }

        await transaction.finish()
    }

    enum PurchaseKind: String {
        case creatorLicense = "creator_license"
        case contentUpload = "content_upload"
    }

    enum StoreError: LocalizedError {
        case userCancelled
        case pending
        case productUnavailable
        case verificationFailed
        case server(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .userCancelled: return "Purchase cancelled."
            case .pending: return "Purchase is pending approval."
            case .productUnavailable: return "This product is not available in the store yet."
            case .verificationFailed: return "Could not verify the App Store transaction."
            case .server(let m): return m
            case .unknown: return "Purchase failed."
            }
        }
    }

    // MARK: - Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard let transaction = try? checkVerified(update) else { continue }
            // Entitlements are applied when user intentionally purchases; finish orphaned transactions.
            await transaction.finish()
        }
    }

    private func legacyActivateLicenseAfterPurchase(
        package: String,
        billing: String?,
        transaction: Transaction
    ) async throws {
        struct Body: Encodable {
            var package: String
            var billing: String?
            var source: String
            var appleTransactionId: String
            var appleProductId: String
        }
        struct Response: Decodable {
            var requiresPayment: Bool?
            var error: String?
        }
        let res: Response = try await client.post(
            "/api/creator/distribution-license",
            body: Body(
                package: package,
                billing: billing,
                source: "ios_storekit",
                appleTransactionId: String(transaction.id),
                appleProductId: transaction.productID
            )
        )
        if let err = res.error, !err.isEmpty { throw StoreError.server(err) }
        if res.requiresPayment == true {
            throw StoreError.server(
                "App Store purchase succeeded, but the studio still requires web payment. Deploy /api/creator/ios/purchase on production, then Restore Purchases."
            )
        }
        await transaction.finish()
    }

    private func legacyMarkContentAfterPurchase(contentId: String, transaction: Transaction) async throws {
        // Without the ios/purchase endpoint, re-submit content for review after client payment is not verified.
        // Leave title in AWAITING_PAYMENT and surface guidance.
        await transaction.finish()
        throw StoreError.server(
            "Upload fee was charged, but the server could not mark the title paid. Please ensure /api/creator/ios/purchase is live, then contact support with transaction \(transaction.id)."
        )
    }
}
