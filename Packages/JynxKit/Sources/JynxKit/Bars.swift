public struct Bar: Codable, Sendable, Equatable {
    public var t: Double, o: Double, h: Double, l: Double, c: Double
    public init(t: Double, o: Double, h: Double, l: Double, c: Double) { self.t = t; self.o = o; self.h = h; self.l = l; self.c = c }
}

public enum Timeframe: String, CaseIterable, Sendable, Identifiable {
    case m1 = "1m", m5 = "5m", m15 = "15m", m30 = "30m", h1 = "1h", h4 = "4h", d1 = "1d", w1 = "1w"
    public var id: String { rawValue }
    public var seconds: Double {
        switch self {
        case .m1: 60
        case .m5: 300
        case .m15: 900
        case .m30: 1800
        case .h1: 3600
        case .h4: 14_400
        case .d1: 86_400
        case .w1: 604_800
        }
    }
    public var label: String { self == .d1 ? "1D" : self == .w1 ? "1W" : rawValue }
    public init?(interval: String) {
        let map: [String: Timeframe] = ["1": .m1, "5": .m5, "15": .m15, "30": .m30, "60": .h1, "240": .h4, "D": .d1, "W": .w1]
        guard let tf = map[interval] else { return nil }
        self = tf
    }
}

public func fold(_ last: Bar?, _ tf: Timeframe, t: Double, price: Double) -> (bar: Bar, fresh: Bool) {
    let size = tf.seconds
    if let last, t < last.t { return (last, false) }
    if let last, t < last.t + size {
        return (Bar(t: last.t, o: last.o, h: max(last.h, price), l: min(last.l, price), c: price), false)
    }
    let start = last.map { $0.t + ((t - $0.t) / size).rounded(.down) * size } ?? (t / size).rounded(.down) * size
    return (Bar(t: start, o: price, h: price, l: price, c: price), true)
}

public func heikinAshi(_ bars: [Bar]) -> [Bar] {
    var out: [Bar] = []
    out.reserveCapacity(bars.count)
    for b in bars { out.append(heikinAshiNext(out.last, b)) }
    return out
}

public func heikinAshiNext(_ prev: Bar?, _ b: Bar) -> Bar {
    let c = (b.o + b.h + b.l + b.c) / 4
    let o = prev.map { ($0.o + $0.c) / 2 } ?? (b.o + b.c) / 2
    return Bar(t: b.t, o: o, h: max(b.h, o, c), l: min(b.l, o, c), c: c)
}

public enum Pips {
    static let size: [String: Double] = [
        "XAUUSD": 0.1, "XAGUSD": 0.01, "US30": 1, "NAS100": 1, "SPX500": 0.1, "GER40": 1,
        "EURUSD": 0.0001, "GBPUSD": 0.0001, "AUDUSD": 0.0001, "NZDUSD": 0.0001, "USDCAD": 0.0001, "USDCHF": 0.0001,
        "EURGBP": 0.0001, "EURAUD": 0.0001, "GBPAUD": 0.0001,
        "USDJPY": 0.01, "EURJPY": 0.01, "GBPJPY": 0.01, "AUDJPY": 0.01,
    ]
    public static func value(symbol: String, side: Side, entry: Double, exit: Double) -> Double? {
        guard let pip = size[symbol] else { return nil }
        let raw = (exit - entry) / pip
        let v = ((side == .buy ? raw : -raw) * 10).rounded() / 10
        return v == 0 ? 0 : v
    }
}
