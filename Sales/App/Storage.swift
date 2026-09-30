import Foundation
import SalesKit

enum Storage {
    private static let d = UserDefaults.standard

    static var settings: Settings {
        get { load(Settings.self, "settings") ?? Settings() }
        set { save(newValue, "settings") }
    }
    static var setups: [Setup] {
        get { load([Setup].self, "setups") ?? [] }
        set { save(newValue, "setups") }
    }
    static var today: Today {
        get { load(Today.self, "today") ?? Today() }
        set { save(newValue, "today") }
    }
    static var badge: Int {
        get { d.integer(forKey: "badge") }
        set { d.set(max(0, newValue), forKey: "badge") }
    }
    static var scheduledUpTo: Int {
        get { d.integer(forKey: "scheduledUpTo") }
        set { d.set(newValue, forKey: "scheduledUpTo") }
    }
    static func takeOrders(_ n: Int) -> Int {
        var next = d.integer(forKey: "nextOrder")
        if next == 0 { next = Int.random(in: 1_001...7_000) }
        d.set(next + n, forKey: "nextOrder")
        return next
    }

    private static var sessionURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }
    static var session: Session? {
        get { (try? Data(contentsOf: sessionURL)).flatMap { try? JSONDecoder().decode(Session.self, from: $0) } }
        set {
            if let s = newValue, let data = try? JSONEncoder().encode(s) {
                try? data.write(to: sessionURL, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: sessionURL)
            }
        }
    }

    static func wipe() {
        if let id = Bundle.main.bundleIdentifier { d.removePersistentDomain(forName: id) }
        session = nil
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        d.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
    private static func save<T: Encodable>(_ value: T, _ key: String) {
        d.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
