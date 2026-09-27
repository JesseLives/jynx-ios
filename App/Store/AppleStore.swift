import Foundation
import JynxKit
import StoreKit

@MainActor
enum AppleStore {
    enum Outcome: Equatable { case active(Date?), cancelled, pending }
    struct Unavailable: LocalizedError { var errorDescription: String? { "This plan is not in the App Store yet." } }

    static func prices(for ids: [String]) async -> [String: String] {
        guard let products = try? await StoreKit.Product.products(for: ids) else { return [:] }
        return Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0.displayPrice) })
    }

    static func buy(_ appleId: String, userId: String, api: API) async throws -> Outcome {
        guard let product = try await StoreKit.Product.products(for: [appleId]).first else { throw Unavailable() }
        var options: Set<StoreKit.Product.PurchaseOption> = []
        if let token = UUID(uuidString: userId) { options.insert(.appAccountToken(token)) }
        switch try await product.purchase(options: options) {
        case .success(let verification):
            let end = try await api.reportApplePurchase(signedTransaction: verification.jwsRepresentation)
            if case .verified(let tx) = verification { await tx.finish() }
            return .active(end)
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: return .cancelled
        }
    }

    static func listen(api: API, refreshed: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        Task {
            for await result in Transaction.unfinished { await settle(result, api: api, refreshed: refreshed) }
            for await result in Transaction.updates { await settle(result, api: api, refreshed: refreshed) }
        }
    }

    private static func settle(_ result: VerificationResult<Transaction>, api: API, refreshed: @MainActor () async -> Void) async {
        guard case .verified(let tx) = result else { return }
        do {
            _ = try await api.reportApplePurchase(signedTransaction: result.jwsRepresentation)
            await tx.finish()
            await refreshed()
        } catch {
        }
    }
}
