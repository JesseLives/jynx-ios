import Foundation

public enum Pacing: String, Codable, CaseIterable, Sendable {
    case linear
    case variable
    case realistic
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
        case .allDay: 24 * 3_600
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
        case .allDay: "over 24 hours"
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
    case .linear, .realistic:
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

public enum RealisticMode: String, Codable, CaseIterable, Sendable { case window, times, monthly }

public func realisticTimes<G: RandomNumberGenerator>(over duration: Double, per: ClosedRange<Int>, window: Double = 1_800, rng: inout G) -> [Double] {
    guard duration > 0 else { return [0] }
    let block = max(60, window)
    let lo = max(0, per.lowerBound), hi = max(lo, per.upperBound)
    var times: [Double] = []
    var t = 0.0
    while t < duration && times.count < Limits.maxPerSession {
        let len = min(block, duration - t)
        let share = Double(Int.random(in: lo...hi, using: &rng)) * len / block
        var n = Int(share)
        if Double.random(in: 0..<1, using: &rng) < share - Double(n) { n += 1 }
        for _ in 0..<n { times.append(t + Double.random(in: 0..<len, using: &rng)) }
        t += len
    }
    if times.isEmpty { times = [Double.random(in: 0..<duration, using: &rng)] }
    return Array(times.sorted().prefix(Limits.maxPerSession))
}

public func spreadTimes<G: RandomNumberGenerator>(count: ClosedRange<Int>, over duration: Double, rng: inout G) -> [Double] {
    guard duration > 0 else { return [0] }
    let n = min(Limits.maxPerSession, max(1, Int.random(in: max(0, count.lowerBound)...max(0, count.lowerBound, count.upperBound), using: &rng)))
    return (0..<n).map { _ in Double.random(in: 0..<duration, using: &rng) }.sorted()
}

public let dayCurve: [Double] = {
    let shape: [Double] = [0.6, 0.35, 0.22, 0.17, 0.15, 0.2, 0.35, 0.6, 0.85, 1.0, 1.1, 1.15,
                           1.2, 1.2, 1.15, 1.15, 1.2, 1.3, 1.45, 1.6, 1.7, 1.65, 1.35, 0.95]
    let mean = shape.reduce(0, +) / Double(shape.count)
    return shape.map { $0 / mean }
}()

public func storeTimes<G: RandomNumberGenerator>(from start: Date, over duration: Double, perDay: Double, calendar: Calendar = .current, rng: inout G) -> [Double] {
    guard duration > 0, perDay > 0 else { return [0] }
    let peak = dayCurve.max()!
    let most = perDay / 86_400 * peak
    var times: [Double] = []
    var t = 0.0
    while times.count < Limits.maxPerSession {
        t += -log(1 - Double.random(in: 0..<1, using: &rng)) / most
        if t >= duration { break }
        let hour = calendar.component(.hour, from: start.addingTimeInterval(t))
        if Double.random(in: 0..<1, using: &rng) < dayCurve[hour] / peak { times.append(t) }
    }
    return times.isEmpty ? [Double.random(in: 0..<duration, using: &rng)] : times
}

public func timesWindow(now: Date, from: Int, to: Int, calendar: Calendar = .current) -> (start: Date, end: Date, share: Double) {
    let day = calendar.startOfDay(for: now)
    let f = day.addingTimeInterval(Double(from) * 60)
    var t = day.addingTimeInterval(Double(to) * 60)
    if t <= f { t = t.addingTimeInterval(86_400) }
    let length = t.timeIntervalSince(f)
    for shift in [-86_400.0, 0, 86_400] {
        let (a, b) = (f.addingTimeInterval(shift), t.addingTimeInterval(shift))
        if now < a { return (a, b, 1) }
        if now < b { return (now, b, b.timeIntervalSince(now) / length) }
    }
    return (f.addingTimeInterval(86_400), t.addingTimeInterval(86_400), 1)
}
