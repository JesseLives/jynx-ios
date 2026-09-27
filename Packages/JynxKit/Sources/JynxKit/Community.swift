import Foundation

public struct Community: Decodable, Sendable, Equatable {
    public struct Question: Decodable, Sendable, Equatable, Identifiable { public let q: String, a: String; public var id: String { q } }
    public enum Social: String, CaseIterable, Sendable { case youtube, instagram, facebook, x }

    public let email: String, telegram: String, channel: String, youtube: String, instagram: String, facebook: String, x: String
    public let faq: [Question]

    public static let website = URL(string: "https://signals.justsal.xyz/contact")!

    public var emailURL: URL? { email.isEmpty ? nil : URL(string: "mailto:\(email)") }
    public var telegramURL: URL? { Self.https(telegram) }
    public var channelURL: URL? { Self.https(channel) }
    public var socials: [(Social, URL)] {
        Social.allCases.compactMap { s in
            let raw = switch s { case .youtube: youtube; case .instagram: instagram; case .facebook: facebook; case .x: x }
            return Self.https(raw).map { (s, $0) }
        }
    }
    static func https(_ s: String) -> URL? { s.hasPrefix("https://") ? URL(string: s) : nil }
}

struct CommunityReply: Decodable { let community: Community }
