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

    /// Server POST package / billing for license selection (legacy distribution-license shape).
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

    var isSubscription: Bool {
        switch self {
        case .uploadYearly, .pipelineMonthly, .pipelineYearly: return true
        case .perFilmUpload: return false
        }
    }

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

/// Result of a StoreKit purchase including JWS from `VerificationResult` (not Transaction JSON).
struct StorePurchaseResult {
    let transaction: Transaction
    /// Signed JWS for server verification — from `VerificationResult.jwsRepresentation`.
    let signedTransaction: String
    let environment: String
}

@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseInFlight = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private var started = false
    private let client = APIClient.shared

    private init() {}

    /// Call once at app launch so `Transaction.updates` activate licenses (Universe pattern).
    func start() {
        guard !started else { return }
        started = true
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(update)
            }
        }
        Task { await loadProducts() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let ids = AppConfig.IAP.allProductIds
        var loaded: [Product] = []
        var lastErrorMessage: String?

        // Pass 1: bulk request with retries (matches Universe StoreService).
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(350_000_000 * attempt))
            }
            do {
                loaded = try await Product.products(for: ids)
                if !loaded.isEmpty { break }
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }

        // Pass 2: per-id — helps incomplete ASC catalogs / StoreKit Config edge cases.
        if loaded.isEmpty {
            var byId: [String: Product] = [:]
            for id in ids {
                do {
                    let found = try await Product.products(for: [id])
                    for p in found { byId[p.id] = p }
                } catch {
                    lastErrorMessage = error.localizedDescription
                }
            }
            loaded = Array(byId.values)
        }

        products = loaded.sorted { $0.displayName < $1.displayName }

        if loaded.isEmpty {
            lastError = Self.emptyCatalogMessage(storeError: lastErrorMessage)
        } else {
            lastError = nil
        }
    }

    private static func emptyCatalogMessage(storeError: String?) -> String {
        let err = storeError.map { " (\($0))" } ?? ""
        return "Subscriptions are not available from the App Store yet\(err). Confirm In-App Purchases are complete in App Store Connect, then try again."
    }

    func product(for kind: CreatorStoreProduct) -> Product? {
        products.first { $0.id == kind.productId }
    }

    /// Purchase a subscription / license product, activate on the server, then finish.
    func purchaseLicense(_ kind: CreatorStoreProduct) async throws {
        guard kind.isSubscription else { throw StoreError.unknown }
        purchaseInFlight = true
        lastError = nil
        defer { purchaseInFlight = false }

        let storeProduct = try await requireProduct(kind)
        let purchase = try await performStoreKitPurchase(storeProduct)
        try await reportPurchaseToServer(
            purchase: purchase,
            kind: .creatorLicense,
            package: kind.licensePackage,
            billing: kind.licenseBilling,
            finish: true
        )
    }

    /// Purchase the per-film consumable (caller must report with `contentId`).
    func purchaseUploadFee() async throws -> StorePurchaseResult {
        purchaseInFlight = true
        lastError = nil
        defer { purchaseInFlight = false }
        let storeProduct = try await requireProduct(.perFilmUpload)
        return try await performStoreKitPurchase(storeProduct)
    }

    func restore() async throws {
        purchaseInFlight = true
        lastError = nil
        defer { purchaseInFlight = false }

        try await AppStore.sync()

        var restoredLicense = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard let kind = CreatorStoreProduct.from(productId: transaction.productID),
                  kind.isSubscription
            else { continue }

            let signed = try Self.requireJws(from: result)
            let purchase = StorePurchaseResult(
                transaction: transaction,
                signedTransaction: signed,
                environment: Self.environmentLabel(transaction.environment)
            )
            try await reportPurchaseToServer(
                purchase: purchase,
                kind: .creatorLicense,
                package: kind.licensePackage,
                billing: kind.licenseBilling,
                finish: true
            )
            restoredLicense = true
        }

        if !restoredLicense {
            throw StoreError.server("No active subscription found for this Apple ID.")
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
        contentId: String? = nil,
        finish: Bool = true
    ) async throws {
        let transaction = purchase.transaction
        let jws = purchase.signedTransaction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidJws(jws) else {
            throw StoreError.verificationFailed
        }

        struct Body: Encodable {
            var productId: String
            var transactionId: String
            var originalTransactionId: String
            var signedTransaction: String
            var signedTransactionInfo: String
            var jwsRepresentation: String
            var kind: String
            var package: String?
            var billing: String?
            var contentId: String?
            var source: String
            var environment: String
            var platform: String
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
            signedTransaction: jws,
            signedTransactionInfo: jws,
            jwsRepresentation: jws,
            kind: kind.rawValue,
            package: package,
            billing: billing,
            contentId: contentId,
            source: "ios_app",
            environment: purchase.environment,
            platform: "ios"
        )

        do {
            let res: Response = try await client.post("/api/creator/ios/purchase", body: body)
            if let err = res.error, !err.isEmpty {
                throw StoreError.server(err)
            }
        } catch let api as APIError {
            if case .http(404, _) = api, kind == .creatorLicense, let package {
                try await legacyActivateLicenseAfterPurchase(
                    package: package,
                    billing: billing,
                    transaction: transaction
                )
            } else if case .http(404, _) = api, kind == .contentUpload {
                throw StoreError.server(
                    "Upload fee was charged, but the title could not be marked paid yet. Try again shortly, or contact support with transaction \(transaction.id)."
                )
            } else {
                throw Self.mapAPIError(api)
            }
        }

        if finish {
            await transaction.finish()
        }
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
            case .pending: return "Purchase is pending approval. Try again after it completes."
            case .productUnavailable:
                return "This subscription is not available from the App Store yet. Tap Retry, then try again."
            case .verificationFailed:
                return "Could not verify the App Store transaction. Use Restore Purchases, or try again."
            case .server(let m): return m
            case .unknown: return "Purchase could not be completed. Please try again."
            }
        }
    }

    // MARK: - Private

    private func requireProduct(_ kind: CreatorStoreProduct) async throws -> Product {
        if let existing = product(for: kind) { return existing }
        await loadProducts()
        guard let loaded = product(for: kind) else {
            throw StoreError.productUnavailable
        }
        return loaded
    }

    private func performStoreKitPurchase(_ product: Product) async throws -> StorePurchaseResult {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            let signed = try Self.requireJws(from: verification)
            return StorePurchaseResult(
                transaction: transaction,
                signedTransaction: signed,
                environment: Self.environmentLabel(transaction.environment)
            )
        case .userCancelled:
            throw StoreError.userCancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        guard transaction.revocationDate == nil else {
            await transaction.finish()
            return
        }
        guard let kind = CreatorStoreProduct.from(productId: transaction.productID) else {
            await transaction.finish()
            return
        }
        // Consumables need contentId from the UI — leave unfinished until the pay sheet reports.
        guard kind.isSubscription else { return }

        do {
            let signed = try Self.requireJws(from: result)
            let purchase = StorePurchaseResult(
                transaction: transaction,
                signedTransaction: signed,
                environment: Self.environmentLabel(transaction.environment)
            )
            try await reportPurchaseToServer(
                purchase: purchase,
                kind: .creatorLicense,
                package: kind.licensePackage,
                billing: kind.licenseBilling,
                finish: true
            )
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            // Do not finish — keep for restore / next Transaction.updates retry.
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw StoreError.server("Could not verify purchase with Apple. \(error.localizedDescription)")
        case .verified(let safe):
            return safe
        }
    }

    /// Require a real StoreKit 2 JWS (three base64url segments). Never send Transaction JSON.
    private static func requireJws(from verification: VerificationResult<Transaction>) throws -> String {
        let raw = verification.jwsRepresentation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidJws(raw) else {
            throw StoreError.verificationFailed
        }
        return raw
    }

    private static func isValidJws(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 3 && parts.allSatisfy { !$0.isEmpty }
    }

    private static func environmentLabel(_ environment: AppStore.Environment) -> String {
        switch environment {
        case .sandbox: return "Sandbox"
        case .production: return "Production"
        case .xcode: return "Xcode"
        default: return "Production"
        }
    }

    private static func mapAPIError(_ api: APIError) -> Error {
        switch api {
        case .unauthorized:
            return StoreError.server("Please sign in again, then tap Restore Purchases to unlock your plan.")
        case .forbidden:
            return StoreError.server("This account cannot activate creator plans. Sign in with a film or music creator account.")
        case .http(_, let message):
            let cleaned = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                return StoreError.server("Purchase could not be linked to your studio account. Try Restore Purchases.")
            }
            if cleaned.localizedCaseInsensitiveContains("deploy")
                || cleaned.localizedCaseInsensitiveContains("/api/creator/ios/purchase")
            {
                return StoreError.server("Purchase could not be linked to your studio account. Try Restore Purchases.")
            }
            return StoreError.server(cleaned)
        default:
            return api
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
                "Purchase could not be linked to your studio account. Try Restore Purchases, or contact support with transaction \(transaction.id)."
            )
        }
    }
}
