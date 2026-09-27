import Foundation

public enum Money {
    public static func dollars(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }
    public static func signed(_ cents: Int) -> String { (cents > 0 ? "+" : "−") + dollars(abs(cents)) }
}

public enum PlanMath {
    public static let lengths = [1, 3, 6, 12]

    public static func perMonth(_ prices: [Int: Int], _ months: Int) -> Int {
        Int((Double(prices[months] ?? 0) / Double(months)).rounded())
    }

    public static func percentOff(_ prices: [Int: Int], _ months: Int) -> Int? {
        guard months != 1, let monthly = prices[1], monthly > 0, let price = prices[months] else { return nil }
        let saving = 1 - Double(price) / Double(monthly * months)
        return saving >= 0.01 ? Int((saving * 100).rounded()) : nil
    }

    public static func bestValue(_ prices: [Int: Int]) -> Int? {
        let ls = lengths.filter { prices[$0] != nil }
        let savings = ls.map { percentOff(prices, $0) ?? 0 }
        guard let top = savings.max(), top > 0, let i = savings.firstIndex(of: top) else { return nil }
        return ls[i]
    }

    public static func cheapestMonthly(_ prices: [Int: Int]) -> Int? {
        lengths.filter { prices[$0] != nil }.map { perMonth(prices, $0) }.min()
    }
}

public struct AmountInput: Equatable, Sendable {
    public static let maxCents = 1_000_000
    public private(set) var text = ""
    public init(cents: Int? = nil) { if let cents { set(cents) } }

    public var cents: Int? {
        guard !text.isEmpty else { return nil }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Int(parts[0]) ?? 0
        let frac = parts.count > 1 ? String(parts[1]) : ""
        let fracCents = Int((frac + "00").prefix(2)) ?? 0
        return whole * 100 + fracCents
    }

    public mutating func press(_ key: String) {
        switch key {
        case "⌫": if !text.isEmpty { text.removeLast() }
        case ".": if !text.contains(".") { text = text.isEmpty ? "0." : text + "." }
        default:
            guard key.count == 1, key.first?.isNumber == true else { return }
            if let dot = text.firstIndex(of: "."), text.distance(from: dot, to: text.endIndex) > 2 { return }
            text = text == "0" ? key : text + key
            if (cents ?? 0) > Self.maxCents { set(Self.maxCents) }
        }
    }

    public static func parse(_ text: String, decimalSeparator: String) -> Int? {
        let t = text.filter { !$0.isWhitespace }
        guard !t.isEmpty, t.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }) else { return nil }
        var whole = t, frac = ""
        if let last = t.lastIndex(where: { $0 == "," || $0 == "." }) {
            let after = String(t[t.index(after: last)...])
            let mark = String(t[last])
            if after.count <= 2 { whole = String(t[..<last]); frac = after }
            else if after.count == 3 && mark == decimalSeparator {
                if !t[..<last].contains(where: { $0 == "," || $0 == "." }) { return nil }
            }
        }
        let digits = whole.filter(\.isNumber)
        guard whole.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }), digits.count <= 12 else { return nil }
        let groups = whole.split(whereSeparator: { $0 == "," || $0 == "." }).map(String.init)
        if groups.count > 1, groups.dropFirst().contains(where: { $0.count != 3 }) { return nil }
        guard let w = Int(digits.isEmpty ? "0" : digits) else { return nil }
        return w * 100 + (Int((frac + "00").prefix(2)) ?? 0)
    }

    public mutating func add(cents more: Int) { set(min(Self.maxCents, (cents ?? 0) + more)) }

    private mutating func set(_ c: Int) {
        text = c % 100 == 0 ? String(c / 100) : String(format: "%d.%02d", c / 100, c % 100)
    }
}
