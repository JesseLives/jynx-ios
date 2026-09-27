import Foundation

public protocol Lenient: RawRepresentable<String>, Decodable { static var fallback: Self { get } }
extension Lenient {
    public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? Self.fallback
    }
}

public enum Role: String, Sendable, Lenient { case member, staff, admin; public static let fallback = Role.member }
public enum RoomKind: String, Sendable, Lenient { case channel, group, other; public static let fallback = RoomKind.other }
public enum MessageKind: String, Sendable, Lenient {
    case text, image, signal, signalUpdate = "signal_update", other
    public static let fallback = MessageKind.other
}
public enum PostVerdict: String, Sendable, Lenient {
    case ok, readOnly = "read_only", muted, banned, noAccess = "no_access", other
    public static let fallback = PostVerdict.other
}
public enum Side: String, Sendable, Lenient { case buy, sell; public static let fallback = Side.buy }
public enum SignalStatus: String, Sendable, Lenient {
    case running, closed, cancelled, other
    public static let fallback = SignalStatus.other
}

public struct User: Decodable, Sendable, Equatable {
    public let id: String, email: String, displayName: String, role: Role
    public var isStaff: Bool { role != .member }
}
public struct Subscription: Decodable, Sendable, Equatable {
    public let productId: String, productName: String, endsAt: Date, autoRenew: Bool
}
public struct WalletBalance: Decodable, Sendable, Equatable { public let balance: Int, withdrawable: Int }
public struct Me: Decodable, Sendable, Equatable {
    public let user: User, subscriptions: [Subscription], wallet: WalletBalance, copierEnabled: Bool
}

public struct LastMessage: Decodable, Sendable, Equatable { public let body: String, createdAt: Date }
public struct Room: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, kind: RoomKind, name: String, locked: Bool, unread: Int, last: LastMessage?
}
public struct RoomsBody: Decodable, Sendable { public let rooms: [Room] }

public struct Author: Decodable, Sendable, Equatable { public let id: String, displayName: String, staff: Bool }
public struct Message: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, roomId: String, kind: MessageKind, body: String, hasMedia: Bool
    public let signalId: String?, author: Author?, createdAt: Date
    public var order: Int64 { Int64(id) ?? 0 }
}
public struct MessagesPage: Decodable, Sendable, Equatable { public let messages: [Message], canPost: PostVerdict }

public struct SignalUpdate: Decodable, Sendable, Equatable {
    public let kind: String, price: String?, fraction: String?, tp: Int?, pips: Double?, createdAt: Date
}
public struct Signal: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, roomId: String, symbol: String, side: Side, market: Bool
    public let entry: String, sl: String, slMovedTo: String?, tps: [String], tpHits: [Int]
    public let note: String, hasChart: Bool, status: SignalStatus, openFraction: String
    public let realizedPips: Double, resultPips: Double?, createdAt: Date, closedAt: Date?, updates: [SignalUpdate]
}
public struct SignalBody: Decodable, Sendable { public let signal: Signal }
