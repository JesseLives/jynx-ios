import Foundation

public enum ProductKind: String, Sendable, Lenient { case channel, copier, other; public static let fallback = ProductKind.other }
public enum AutoQR: String, Sendable, Lenient { case khqr, aba, other; public static let fallback = AutoQR.other }
public enum PaymentStatus: String, Sendable, Lenient {
    case pending, approved, rejected, other
    public static let fallback = PaymentStatus.other
}

public struct Product: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, kind: ProductKind, name: String, description: String
    public let prices: [Int: Int]
    public let appleIds: [Int: String]
    public var lengths: [Int] { PlanMath.lengths.filter { prices[$0] != nil } }

    enum Keys: String, CodingKey { case id, kind, name, description, prices, appleIds }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id); kind = try c.decode(ProductKind.self, forKey: .kind)
        name = try c.decode(String.self, forKey: .name); description = try c.decode(String.self, forKey: .description)
        let raw = try c.decode([String: Int].self, forKey: .prices)
        prices = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
        let ids = try c.decodeIfPresent([String: String].self, forKey: .appleIds) ?? [:]
        appleIds = Dictionary(uniqueKeysWithValues: ids.compactMap { k, v in Int(k).map { ($0, v) } })
    }
}

public struct PaymentSettings: Decodable, Sendable, Equatable {
    public let abaName: String, abaQrPath: String?, usdtTrc20: String, autoQr: AutoQR?
}
public struct PlansBody: Decodable, Sendable { public let products: [Product], payment: PaymentSettings }

public enum ActivityKind: String, Sendable, Lenient {
    case commission, deposit, purchase, withdrawal, withdrawalReturn = "withdrawal_return", other
    public static let fallback = ActivityKind.other
}

public struct WalletActivity: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, kind: ActivityKind, cents: Int, at: Date
    public let level: Int?, from: String?, product: String?, withdrawalStatus: String?

    public var describe: (title: String, subtitle: String, symbol: String) {
        switch kind {
        case .commission: (from.map { "From \($0)" } ?? "Level \(level ?? 1) referral", "Referral, level \(level ?? 1)", "person.2")
        case .deposit: ("Deposit", "Added to your wallet", "arrow.down.to.line")
        case .purchase: (product ?? "Plan", "Paid from wallet", "square.stack.3d.up")
        case .withdrawal: ("Withdrawal", ["pending": "Waiting to be paid", "paid": "Paid", "rejected": "Rejected"][withdrawalStatus ?? "pending"] ?? "", "arrow.up.to.line")
        case .withdrawalReturn: ("Withdrawal returned", "Back in your wallet", "arrow.uturn.down")
        case .other: ("Wallet", "", "wallet.pass")
        }
    }
}

public struct Withdrawal: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, amountCents: Int, method: String, destination: String, status: String, rejectReason: String?, createdAt: Date
    enum CodingKeys: String, CodingKey {
        case id, method, destination, status
        case amountCents = "amount_cents", rejectReason = "reject_reason", createdAt = "created_at"
    }
}

public struct WalletOverview: Decodable, Sendable, Equatable {
    public let balance: Int, withdrawable: Int, earnedCents: Int, inviteCode: String, username: String
    public let referrals: Bool, rates: [Double], counts: [Int], minWithdrawCents: Int, minDepositCents: Int
    public let activity: [WalletActivity], withdrawals: [Withdrawal]
}
public struct WalletBody: Decodable, Sendable { public let wallet: WalletOverview }

public struct PaymentRecord: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, kind: String, productName: String?, months: Int?, amountCents: Int, method: String
    public let status: PaymentStatus, rejectReason: String?, createdAt: Date, auto: Bool
}
public struct PaymentsBody: Decodable, Sendable { public let payments: [PaymentRecord] }

public struct QRPayment: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, amountCents: Int, qrImage: String, deeplink: String?, expiresAt: Date, method: AutoQR
    public var pngData: Data? { qrImage.split(separator: ",", maxSplits: 1).last.flatMap { Data(base64Encoded: String($0)) } }
}
public struct QRPaymentBody: Decodable, Sendable { public let payment: QRPayment }

public struct PaymentState: Decodable, Sendable, Equatable {
    public let status: PaymentStatus, rejectReason: String?, kind: String, amountCents: Int, endsAt: Date?
}
public struct PaymentStatusBody: Decodable, Sendable { public let payment: PaymentState }
