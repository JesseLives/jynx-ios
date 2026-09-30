import Foundation

public struct Product: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var priceCents: Int

    public init(id: UUID = UUID(), name: String, priceCents: Int) {
        self.id = id
        self.name = name
        self.priceCents = priceCents
    }

    public var shownName: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Item" : n
    }
}

public struct NotificationText: Codable, Hashable, Sendable {
    public var title: String
    public var body: String
    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public let presets: [NotificationText] = [
    NotificationText(title: "New order", body: "[{store}] You have a new order for {items} totaling {amount} from Online Store."),
    NotificationText(title: "Order #{order} from Shopify", body: "{amount}, {items} from Online Store - {store}"),
    NotificationText(title: "Order #{order}", body: "{amount}, {items} from {store}"),
    NotificationText(title: "Order #{order} from Shopify", body: "{amount}, {product} from Online Store - {store}"),
    NotificationText(title: "You have a new order", body: "{amount} from Online Store - {store}"),
]

public enum TextMode: String, Codable, Sendable { case preset, custom }

public enum SoundChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case shopify, chime, coin, system
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .shopify: "Shopify"
        case .chime: "Chime"
        case .coin: "Coin"
        case .system: "iPhone default"
        }
    }
    public var file: String? {
        switch self {
        case .shopify: "shopify.caf"
        case .chime: "chime.wav"
        case .coin: "coin.wav"
        case .system: nil
        }
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var textMode: TextMode = .preset
    public var presetIndex = 0
    public var custom = NotificationText(title: "New order", body: "[{store}] You have a new order for {items} totaling {amount} from Online Store.")
    public var products: [Product] = [Product(name: "My Product", priceCents: 3_899)]
    public var maxItems = 1
    public var varyTotals = true
    public var store = "My Store"
    public var length: SessionLength = .tenMinutes
    public var perTenSeconds = 100
    public var pacing: Pacing = .variable
    public var perHalfHourLow = 5
    public var perHalfHourHigh = 10
    public var sound: SoundChoice = .shopify
    public var badge = true
    public var liveActivity = true
    public var startLater = false
    public var startAt = Date(timeIntervalSince1970: 0)

    public init() {}

    public var text: NotificationText {
        textMode == .custom ? custom : presets[min(max(0, presetIndex), presets.count - 1)]
    }

    public var count: Int { sessionCount(length: length, perTenSeconds: perTenSeconds) }

    public var perHalfHour: ClosedRange<Int> {
        get {
            let a = max(0, min(500, perHalfHourLow)), b = max(0, min(500, perHalfHourHigh))
            return min(a, b)...max(a, b)
        }
        set {
            perHalfHourLow = newValue.lowerBound
            perHalfHourHigh = newValue.upperBound
        }
    }

    public var expectedCount: Int {
        guard length != .now else { return 1 }
        guard pacing == .realistic else { return count }
        let r = perHalfHour
        return max(1, min(Limits.maxPerSession, Int((Double(r.lowerBound + r.upperBound) / 2 * length.seconds / 1_800).rounded())))
    }

    public var sellable: [Product] {
        let p = products.filter { $0.priceCents > 0 }
        return p.isEmpty ? [Product(name: "My Product", priceCents: 3_899)] : p
    }

    enum CodingKeys: String, CodingKey {
        case textMode, presetIndex, custom, products, maxItems, varyTotals, store, length, perTenSeconds, pacing, perHalfHourLow, perHalfHourHigh
        case sound, badge, liveActivity, startLater, startAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        textMode = (try? c.decode(TextMode.self, forKey: .textMode)) ?? d.textMode
        presetIndex = (try? c.decode(Int.self, forKey: .presetIndex)) ?? d.presetIndex
        custom = (try? c.decode(NotificationText.self, forKey: .custom)) ?? d.custom
        products = (try? c.decode([Product].self, forKey: .products)) ?? d.products
        maxItems = (try? c.decode(Int.self, forKey: .maxItems)) ?? d.maxItems
        varyTotals = (try? c.decode(Bool.self, forKey: .varyTotals)) ?? d.varyTotals
        store = (try? c.decode(String.self, forKey: .store)) ?? d.store
        length = (try? c.decode(SessionLength.self, forKey: .length)) ?? d.length
        perTenSeconds = (try? c.decode(Int.self, forKey: .perTenSeconds)) ?? d.perTenSeconds
        pacing = (try? c.decode(Pacing.self, forKey: .pacing)) ?? d.pacing
        perHalfHourLow = (try? c.decode(Int.self, forKey: .perHalfHourLow)) ?? d.perHalfHourLow
        perHalfHourHigh = (try? c.decode(Int.self, forKey: .perHalfHourHigh)) ?? d.perHalfHourHigh
        sound = (try? c.decode(SoundChoice.self, forKey: .sound)) ?? d.sound
        badge = (try? c.decode(Bool.self, forKey: .badge)) ?? d.badge
        liveActivity = (try? c.decode(Bool.self, forKey: .liveActivity)) ?? d.liveActivity
        startLater = (try? c.decode(Bool.self, forKey: .startLater)) ?? d.startLater
        startAt = (try? c.decode(Date.self, forKey: .startAt)) ?? d.startAt
    }
}

public struct Setup: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var settings: Settings
    public init(id: UUID = UUID(), name: String, settings: Settings) {
        self.id = id
        self.name = name
        self.settings = settings
    }
}
