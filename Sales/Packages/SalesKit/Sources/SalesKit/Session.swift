import Foundation

public struct Sale: Codable, Equatable, Sendable {
    public let order: Int
    public let product: String
    public let items: Int
    public let cents: Int
    public init(order: Int, product: String, items: Int, cents: Int) {
        self.order = order
        self.product = product
        self.items = items
        self.cents = cents
    }
}

public func money(_ cents: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    let sign = cents < 0 ? "-" : ""
    return sign + "$" + (f.string(from: NSNumber(value: Double(abs(cents)) / 100)) ?? "0.00")
}

public func fill(_ text: String, sale: Sale, store: String) -> String {
    text.replacingOccurrences(of: "{order}", with: String(sale.order))
        .replacingOccurrences(of: "{amount}", with: money(sale.cents))
        .replacingOccurrences(of: "{items}", with: sale.items == 1 ? "1 item" : "\(sale.items) items")
        .replacingOccurrences(of: "{product}", with: sale.items == 1 ? sale.product : "\(sale.product) × \(sale.items)")
        .replacingOccurrences(of: "{store}", with: store)
}

public struct Session: Codable, Equatable, Sendable {
    public let id: UUID
    public let start: Date
    public let times: [Double]
    public let sales: [Sale]
    public let settings: Settings
    public private(set) var counted = 0
    public private(set) var delivered = 0
    public private(set) var deliveredCents = 0
    public var badgeBase: Int

    public init<G: RandomNumberGenerator>(settings: Settings, start: Date, firstOrder: Int, badgeBase: Int, rng: inout G) {
        id = UUID()
        self.start = start
        self.settings = settings
        self.badgeBase = badgeBase
        if settings.length == .now {
            times = [0]
        } else if settings.pacing == .realistic {
            times = realisticTimes(over: settings.length.seconds, perHalfHour: settings.perHalfHour, rng: &rng)
        } else {
            times = fireTimes(count: settings.count, over: settings.length.seconds, pacing: settings.pacing, rng: &rng)
        }
        let n = times.count
        let products = settings.sellable
        let most = max(1, min(10, settings.maxItems))
        sales = (0..<n).map { i in
            let p = products[Int.random(in: 0..<products.count, using: &rng)]
            let items = Int.random(in: 1...most, using: &rng)
            var cents = p.priceCents * items
            if settings.varyTotals { cents = max(1, Int((Double(cents) * Double.random(in: 0.92...1.15, using: &rng)).rounded())) }
            return Sale(order: firstOrder + i, product: p.shownName, items: items, cents: cents)
        }
    }

    public var total: Int { times.count }
    public var finished: Bool { counted >= total }
    public var end: Date { start.addingTimeInterval(times.last ?? 0) }

    public func fireDate(_ i: Int) -> Date { start.addingTimeInterval(times[i]) }
    public func badge(_ i: Int) -> Int { max(1, badgeBase + i + 1) }
    public func title(_ i: Int) -> String { fill(settings.text.title, sale: sales[i], store: settings.store) }
    public func body(_ i: Int) -> String { fill(settings.text.body, sale: sales[i], store: settings.store) }

    public mutating func advance(to now: Date, sentBelow: Int = .max) -> [(sale: Sale, at: Date)] {
        var fired: [(Sale, Date)] = []
        while counted < total && fireDate(counted) <= now {
            if counted < sentBelow {
                fired.append((sales[counted], fireDate(counted)))
                delivered += 1
                deliveredCents += sales[counted].cents
            }
            counted += 1
        }
        return fired
    }
}

public struct Today: Codable, Equatable, Sendable {
    public var day: String
    public var cents: Int
    public var orders: Int

    public init(day: String = "", cents: Int = 0, orders: Int = 0) {
        self.day = day
        self.cents = cents
        self.orders = orders
    }

    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public mutating func add(_ sale: Sale, at date: Date, calendar: Calendar = .current) {
        let k = Today.key(date, calendar: calendar)
        if k < day { return }                 // "yyyy-MM-dd" sorts by date
        if k != day { self = Today(day: k) }
        cents += sale.cents
        orders += 1
    }

    public func shown(at date: Date, calendar: Calendar = .current) -> Today {
        Today.key(date, calendar: calendar) == day ? self : Today(day: Today.key(date, calendar: calendar))
    }
}

public func shortMoney(_ cents: Int) -> String {
    let d = Double(cents) / 100
    switch d {
    case ..<1_000: return money(cents).replacingOccurrences(of: ".00", with: "")
    case ..<1_000_000: return String(format: "$%.1fK", d / 1_000).replacingOccurrences(of: ".0K", with: "K")
    default: return String(format: "$%.1fM", d / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
    }
}
