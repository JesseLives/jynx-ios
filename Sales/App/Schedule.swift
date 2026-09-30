import Foundation

enum Pacing: String, Codable, CaseIterable {
    case linear
    case variable
}

enum Limits {
    static let sessionSeconds: Double = 600   // "Over 10 minutes"
    static let maxPerTenSeconds = 500
    static let maxPerSession = 5_000
}

func sessionCount(perTenSeconds: Int) -> Int {
    min(Limits.maxPerSession, max(1, min(perTenSeconds, Limits.maxPerTenSeconds)) * 60)
}

func fireTimes<G: RandomNumberGenerator>(count n: Int, over duration: Double, pacing: Pacing, rng: inout G) -> [Double] {
    guard n > 0, duration > 0 else { return [] }
    switch pacing {
    case .linear:
        return (0..<n).map { (Double($0) + 0.5) * duration / Double(n) }
    case .variable:
        var times: [Double] = []
        times.reserveCapacity(n)
        var t = 0.0
        let meanBurst = 3.0
        let meanGap = duration / (Double(n) / meanBurst)
        while times.count < n {
            t += -log(1 - Double.random(in: 0..<1, using: &rng)) * meanGap
            var burst = 1
            while burst < 8 && Double.random(in: 0..<1, using: &rng) < 1 - 1 / meanBurst { burst += 1 }
            var at = t
            for _ in 0..<min(burst, n - times.count) {
                times.append(at)
                at += Double.random(in: 0.08...0.4, using: &rng)
            }
        }
        let last = times.max() ?? duration
        let scale = last > 0 ? (duration * 0.98) / last : 1
        return times.map { $0 * scale }.sorted()
    }
}

struct Sale: Equatable {
    let order: Int
    let items: Int
    let cents: Int
}

func money(_ cents: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.locale = Locale(identifier: "en_US")
    return "$" + (f.string(from: NSNumber(value: Double(cents) / 100)) ?? String(format: "%.2f", Double(cents) / 100))
}

func fill(_ text: String, sale: Sale, store: String, product: String) -> String {
    text.replacingOccurrences(of: "{order}", with: String(sale.order))
        .replacingOccurrences(of: "{amount}", with: money(sale.cents))
        .replacingOccurrences(of: "{items}", with: sale.items == 1 ? "1 item" : "\(sale.items) items")
        .replacingOccurrences(of: "{store}", with: store)
        .replacingOccurrences(of: "{product}", with: product)
}
