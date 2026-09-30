import Foundation

let presets: [Preset] = [
    Preset(title: "Order #{order} from Shopify", body: "{amount}, {items} from Online Store - {store}"),
    Preset(title: "Order #{order}", body: "{amount}, {items} from {store}"),
    Preset(title: "You have a new order", body: "{amount} from Online Store - {store}"),
]

struct Preset: Codable, Hashable {
    var title: String
    var body: String
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

    var preset: Preset { presets[min(max(0, presetIndex), presets.count - 1)] }
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
