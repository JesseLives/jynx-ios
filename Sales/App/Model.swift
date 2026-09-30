import Foundation

enum Platform: String, Codable, CaseIterable, Identifiable {
    case shopify, stripe, stan, custom
    var id: String { rawValue }
    var label: String {
        switch self { case .shopify: "Shopify"; case .stripe: "Stripe"; case .stan: "Stan"; case .custom: "Custom" }
    }
    var presets: [Preset] {
        switch self {
        case .shopify: [
            Preset(title: "Order #{order} from Shopify", body: "{amount}, {items} from Online Store - {store}"),
            Preset(title: "Order #{order}", body: "{amount}, {items} from {store}"),
            Preset(title: "You have a new order", body: "{amount} from Online Store - {store}"),
        ]
        case .stripe: [
            Preset(title: "Payment received", body: "{amount} from a customer of {store}"),
            Preset(title: "Stripe", body: "Payment of {amount} succeeded"),
            Preset(title: "New payment", body: "You received {amount}"),
        ]
        case .stan: [
            Preset(title: "You made a sale!", body: "{amount} for {product}"),
            Preset(title: "New Stan order", body: "Someone bought {product} for {amount}"),
        ]
        case .custom: [Preset(title: "New sale", body: "{amount} from {store}")]
        }
    }
}

struct Preset: Codable, Hashable {
    var title: String
    var body: String
}

enum Logo: String, Codable, CaseIterable, Identifiable {
    case main, shopify, stripe, stan
    var id: String { rawValue }
    var label: String {
        switch self { case .main: "Sales"; case .shopify: "Shopify"; case .stripe: "Stripe"; case .stan: "Stan" }
    }
    var alternate: String? {
        switch self { case .main: nil; case .shopify: "AppIcon-Shopify"; case .stripe: "AppIcon-Stripe"; case .stan: "AppIcon-Stan" }
    }
    var thumbnail: String { "logo-\(rawValue)" }
}

enum NotificationSound: String, Codable, CaseIterable, Identifiable {
    case kaching, chime, coin, system
    var id: String { rawValue }
    var label: String {
        switch self { case .kaching: "Ka-ching"; case .chime: "Chime"; case .coin: "Coin"; case .system: "iPhone default" }
    }
    var file: String? { self == .system ? nil : "\(rawValue).wav" }
}

enum TextMode: String, Codable { case preset, custom }
enum When: String, Codable { case single, tenMinutes }

struct Settings: Codable, Equatable {
    var platform: Platform = .shopify
    var textMode: TextMode = .preset
    var presetIndex = 0
    var customTitle = "New sale"
    var customBody = "{amount} from {store}"
    var when: When = .tenMinutes
    var perTenSeconds = 100
    var pacing: Pacing = .variable
    var sound: NotificationSound = .kaching
    var price = 38.99
    var maxItems = 1
    var store = "My Store"
    var product = "My Course"

    var preset: Preset {
        let list = platform.presets
        return list[min(max(0, presetIndex), list.count - 1)]
    }
    var text: Preset { textMode == .custom ? Preset(title: customTitle, body: customBody) : preset }

    func sale(order: Int) -> Sale {
        let items = Int.random(in: 1...max(1, maxItems))
        return Sale(order: order, items: items, cents: Int((price * 100).rounded()) * items)
    }

    static let key = "settings"
    static func load() -> Settings {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Settings.self, from: d) else { return Settings() }
        return s
    }
    func save() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}
