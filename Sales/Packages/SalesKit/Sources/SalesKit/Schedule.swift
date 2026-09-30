import Foundation

public enum Pacing: String, Codable, CaseIterable, Sendable {
    case linear
    case variable
}

public enum SessionLength: String, Codable, CaseIterable, Sendable {
    case now, oneMinute, tenMinutes, thirtyMinutes, oneHour, allDay

    public var seconds: Double {
        switch self {
        case .now: 0
        case .oneMinute: 60
        case .tenMinutes: 600
        case .thirtyMinutes: 1_800
        case .oneHour: 3_600
        case .allDay: 12 * 3_600
        }
    }

    public var label: String {
        switch self {
        case .now: "Now"
        case .oneMinute: "1 min"
        case .tenMinutes: "10 min"
        case .thirtyMinutes: "30 min"
        case .oneHour: "1 hour"
        case .allDay: "All day"
        }
    }

    public var span: String {
        switch self {
        case .now: "right now"
        case .oneMinute: "over 1 minute"
        case .tenMinutes: "over 10 minutes"
        case .thirtyMinutes: "over 30 minutes"
        case .oneHour: "over 1 hour"
        case .allDay: "over 12 hours"
        }
    }
}

public enum Limits {
    public static let maxPerTenSeconds = 500
    public static let maxPerSession = 5_000
}

public func sessionCount(length: SessionLength, perTenSeconds: Int) -> Int {
    guard length != .now else { return 1 }
    let rate = max(1, min(perTenSeconds, Limits.maxPerTenSeconds))
    return max(1, min(Limits.maxPerSession, Int((Double(rate) * length.seconds / 10).rounded())))
}

public func fireTimes<G: RandomNumberGenerator>(count n: Int, over duration: Double, pacing: Pacing, rng: inout G) -> [Double] {
    guard n > 0 else { return [] }
    guard duration > 0 else { return [Double](repeating: 0, count: n) }
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
