import SwiftUI
import StoreKit

/// Native plan picker using StoreKit (App Store Guideline 3.1.1).
struct CreatorPlanStoreView: View {
    var title: String = "Choose your creator plan"
    var onCompleted: (() -> Void)? = nil

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitService.shared
    @State private var busyKey: String?
    @State private var message: String?
    @State private var succeeded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Subscriptions and unlocks are purchased with In-App Purchase. Your App Store account is charged — not a web payment page.")
                        .font(STFont.body(13))
                        .foregroundStyle(STColor.textSecondary)

                    planCard(
                        key: "perfilm",
                        title: CreatorFreePlanOption.title,
                        detail: CreatorFreePlanOption.detail,
                        priceLabel: "Free to start",
                        badge: "Pay as you upload"
                    ) {
                        await selectPerFilm()
                    }

                    ForEach(planKinds, id: \.self) { kind in
                        let product = store.product(for: kind)
                        planCard(
                            key: kind.productId,
                            title: kind.title,
                            detail: kind.detail,
                            priceLabel: product?.displayPrice ?? "Loading…",
                            badge: product == nil ? "Store" : nil
                        ) {
                            await purchase(kind)
                        }
                    }

                    if store.isLoading {
                        ProgressView("Loading App Store products…")
                            .tint(STColor.primary)
                            .frame(maxWidth: .infinity)
                    }

                    if let message {
                        Text(message)
                            .font(STFont.body(13))
                            .foregroundStyle(succeeded ? STColor.success : STColor.danger)
                    }

                    Button {
                        Task {
                            await store.restore()
                            await auth.refreshPackageGate()
                            if !auth.needsPlanSetup {
                                succeeded = true
                                message = "Purchases restored."
                                onCompleted?()
                                dismiss()
                            } else {
                                message = store.lastError ?? "No active subscription found for this Apple ID."
                                succeeded = false
                            }
                        }
                    } label: {
                        Text("Restore purchases")
                            .font(STFont.body(14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(STColor.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(STColor.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(STColor.primary)
                }
            }
            .task { await store.loadProducts() }
            .preferredColorScheme(.dark)
        }
    }

    private var planKinds: [CreatorStoreProduct] {
        [.uploadYearly, .pipelineMonthly, .pipelineYearly]
    }

    private func planCard(
        key: String,
        title: String,
        detail: String,
        priceLabel: String,
        badge: String?,
        action: @escaping () async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(STFont.body(16, weight: .bold))
                    .foregroundStyle(STColor.textPrimary)
                Spacer()
                Text(priceLabel)
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.accent)
            }
            if let badge {
                Text(badge)
                    .font(STFont.body(11, weight: .semibold))
                    .foregroundStyle(STColor.primary)
            }
            Text(detail)
                .font(STFont.body(13))
                .foregroundStyle(STColor.textSecondary)

            Button {
                Task {
                    busyKey = key
                    defer { busyKey = nil }
                    await action()
                }
            } label: {
                HStack {
                    if busyKey == key { ProgressView().tint(.black) }
                    Text(busyKey == key ? "Working…" : "Continue")
                        .font(STFont.body(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.black)
                .background(RoundedRectangle(cornerRadius: 12).fill(STColor.brandGradient))
            }
            .disabled(busyKey != nil)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(STColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(STColor.border))
        )
    }

    private func selectPerFilm() async {
        message = nil
        succeeded = false
        do {
            try await store.activateFreePerFilmPlan()
            await auth.refreshPackageGate()
            succeeded = true
            message = "Pay-per-film plan activated. You’ll pay per title when submitting for review."
            onCompleted?()
            dismiss()
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func purchase(_ kind: CreatorStoreProduct) async {
        message = nil
        succeeded = false
        do {
            let purchase = try await store.purchase(kind)
            try await store.reportPurchaseToServer(
                purchase: purchase,
                kind: .creatorLicense,
                package: kind.licensePackage,
                billing: kind.licenseBilling
            )
            await auth.refreshPackageGate()
            succeeded = true
            message = "Plan active."
            onCompleted?()
            dismiss()
        } catch let err as StoreKitService.StoreError {
            if case .userCancelled = err { return }
            message = err.errorDescription
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - Upload fee

struct UploadFeeStoreView: View {
    let contentId: String
    let displayFee: String
    var onPaid: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitService.shared
    @State private var isBusy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Per-film upload fee")
                    .font(STFont.display(22, weight: .bold))
                    .foregroundStyle(STColor.textPrimary)
                Text("Your plan charges per catalogue submission. Complete In-App Purchase to send this title to admin review. Until paid, it stays awaiting payment and is not submitted.")
                    .font(STFont.body(14))
                    .foregroundStyle(STColor.textSecondary)

                let product = store.product(for: .perFilmUpload)
                HStack {
                    Text("Upload fee")
                        .font(STFont.body(15, weight: .semibold))
                        .foregroundStyle(STColor.textPrimary)
                    Spacer()
                    Text(product?.displayPrice ?? displayFee)
                        .font(STFont.body(16, weight: .bold))
                        .foregroundStyle(STColor.accent)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(STColor.surface))

                if let message {
                    Text(message)
                        .font(STFont.body(13))
                        .foregroundStyle(STColor.danger)
                }

                Button {
                    Task { await purchase() }
                } label: {
                    HStack {
                        if isBusy { ProgressView().tint(.black) }
                        Text(isBusy ? "Processing…" : "Pay with App Store")
                            .font(STFont.body(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.black)
                    .background(RoundedRectangle(cornerRadius: 14).fill(STColor.brandGradient))
                }
                .disabled(isBusy)
                .buttonStyle(.plain)

                Button("Not now") { dismiss() }
                    .font(STFont.body(14, weight: .semibold))
                    .foregroundStyle(STColor.textMuted)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(20)
            .background(STColor.background)
            .navigationTitle("Submit payment")
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.loadProducts() }
            .preferredColorScheme(.dark)
        }
    }

    private func purchase() async {
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let purchase = try await store.purchase(.perFilmUpload)
            try await store.reportPurchaseToServer(
                purchase: purchase,
                kind: .contentUpload,
                contentId: contentId
            )
            onPaid?()
            dismiss()
        } catch let err as StoreKitService.StoreError {
            if case .userCancelled = err { return }
            message = err.errorDescription
        } catch {
            message = error.localizedDescription
        }
    }
}
