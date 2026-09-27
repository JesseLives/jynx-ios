import Foundation

public enum ChartStyle: String, Sendable, Lenient {
    case candles, hollow, heikin, bars, line, area
    public static let fallback = ChartStyle.candles
}

public struct ChartConfig: Decodable, Sendable, Equatable {
    public let interval: String, style: ChartStyle, upColor: String, downColor: String
    public let background: String?, grid: String?, toolbar: Bool
    public var timeframe: Timeframe { Timeframe(interval: interval) ?? .h1 }
    public static let standard = ChartConfig(interval: "60", style: .candles, upColor: "#00b87a", downColor: "#f4212e",
                                             background: nil, grid: nil, toolbar: true)
}
public struct ChartConfigBody: Decodable, Sendable { public let chart: ChartConfig }
public struct CandlesBody: Decodable, Sendable { public let candles: [Bar] }

public struct SniperPanel: Decodable, Sendable, Equatable {
    public let state: String, stars: Int
    public let entry: Double?, stop: Double?, target: Double?
    public let trades: Int, wins: Int, losses: Int, winRate: Double?, profitFactor: Double?

    public static func say(_ state: String) -> String {
        let swaps: [(String, String)] = [("In long", "Long"), ("Buy", "Long"), ("In short", "Short"), ("Sell", "Short"),
                                         ("Arming long", "Setting up a long"), ("Arming short", "Setting up a short")]
        if state == "Trend up" || state == "Trend down" { return "Waiting" }
        for (from, to) in swaps where state.hasPrefix(from) { return to + state.dropFirst(from.count) }
        return state
    }
    public var direction: Side? {
        state.hasPrefix("Buy") || state.hasPrefix("In long") ? .buy : state.hasPrefix("Sell") || state.hasPrefix("In short") ? .sell : nil
    }
}

public struct SniperLive: Decodable, Sendable, Equatable {
    public let since: String?, calls: Int, closed: Int, wins: Int, netR: Double
}

public struct SniperWorking: Decodable, Sendable, Equatable {
    public let profile: String, panel: SniperPanel, record: Bool, live: SniperLive?
    public let buys: [Double], sells: [Double], wins: [Double], losses: [Double]
}

public enum Sniper: Decodable, Sendable, Equatable {
    case locked, off, working(SniperWorking)
    enum Keys: String, CodingKey { case locked, profile }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        if try c.decode(Bool.self, forKey: .locked) { self = .locked; return }
        if try c.decodeIfPresent(String.self, forKey: .profile) == "off" { self = .off; return }
        self = .working(try SniperWorking(from: decoder))
    }
}

public struct ChartSignal: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, side: Side, entry: Double, sl: Double, slMoved: Bool
    public let tps: [Double], tpHits: [Int], createdAt: Double, room: String
}
public struct ChartSignalsBody: Decodable, Sendable { public let signals: [ChartSignal] }

public struct PriceTick: Decodable, Sendable, Equatable {
    public let t: Double, p: Double
    public init(t: Double, p: Double) { self.t = t; self.p = p }
}

extension PriceTick {
    public init?(event: SSEEvent) {
        guard event.event == "price", let tick = try? JSONDecoder().decode(PriceTick.self, from: Data(event.data.utf8)) else { return nil }
        self = tick
    }
    public func isNewer(than last: PriceTick?) -> Bool { last.map { t >= $0.t } ?? true }
}

public enum TargetProgress {
    public static func fills(side: Side, entry: Double, tps: [Double], hits: [Int], price: Double?) -> [Double] {
        let levels = [entry] + tps, dir: Double = side == .buy ? 1 : -1
        return tps.indices.map { i in
            if hits.contains(i + 1) { return 1 }
            guard let price else { return 0 }
            let span = (levels[i + 1] - levels[i]) * dir
            guard span > 0 else { return 0 }
            return min(1, max(0, (price - levels[i]) * dir / span))
        }
    }
}
