import Foundation

public struct CopierAccount: Decodable, Sendable, Equatable {
    public enum Status: String, Sendable, Lenient { case pending, connecting, online, error; public static let fallback = Status.pending }
    public enum Mode: String, Sendable, Lenient { case fixed, risk; public static let fallback = Mode.fixed }
    public let login: String, server: String, status: Status, lastError: String?, mode: Mode
    public let fixedLot: Double, riskPct: Double, maxLot: Double, enabled: Bool
}

public enum CopyStatus: String, Sendable, Lenient {
    case pending, opened, closed, skipped, failed, other
    public static let fallback = CopyStatus.other
}

public struct CopyRow: Decodable, Sendable, Equatable, Identifiable {
    public let id: String, symbol: String, side: Side, status: CopyStatus, reason: String?, volume: Double?, createdAt: Date
}

public struct CopierState: Decodable, Sendable, Equatable {
    public let hasPass: Bool, account: CopierAccount?, copies: [CopyRow]
}

public struct CopierPower: Equatable, Sendable {
    public enum Ring: Sendable { case off, on, wait, error }
    public let ring: Ring, label: String, sub: String?, tappable: Bool

    public static func of(hasPass: Bool, account a: CopierAccount?) -> CopierPower {
        guard let a else { return CopierPower(ring: .off, label: hasPass ? "Not connected" : "Copier Pass needed", sub: nil, tappable: false) }
        let sub = "\(a.login), \(a.server)"
        switch a.status {
        case .error: return CopierPower(ring: .error, label: "Could not connect", sub: sub, tappable: false)
        case .pending, .connecting: return CopierPower(ring: .wait, label: "Connecting", sub: sub, tappable: false)
        case .online:
            guard hasPass else { return CopierPower(ring: .off, label: "Copier Pass ended", sub: sub, tappable: false) }
            return CopierPower(ring: a.enabled ? .on : .off, label: a.enabled ? "Copying" : "Tap to start", sub: sub, tappable: true)
        }
    }
}

public enum CopyText {
    static let reasons = [
        "late": "Signal was over 2 minutes old", "price_moved": "Price had moved too far", "symbol_unavailable": "Symbol not on your account",
        "below_min_lot": "Size below broker minimum", "closed_by_member": "Closed by you", "signal_closed": "Closed with the signal",
        "signal_finished": "Signal already closed", "remaining_below_min_lot": "Closed: remainder below minimum",
    ]
    public static func reason(_ r: String) -> String { reasons[r] ?? r.replacingOccurrences(of: "_", with: " ") }
    public static func status(_ s: CopyStatus) -> String {
        switch s {
        case .pending: "Sending"
        case .opened: "Open"
        case .closed: "Closed"
        case .skipped: "Skipped"
        case .failed: "Failed"
        case .other: ""
        }
    }
}

public enum CopierInput {
    public enum Field: Sendable { case lot, max, risk }

    public static func range(_ f: Field) -> String { f == .risk ? "0.1 to 10" : "0.01 to 100" }

    public static func value(_ text: String, separator: String, field: Field) -> Double? {
        guard let cents = AmountInput.parse(text, decimalSeparator: separator) else { return nil }
        let v = Double(cents) / 100
        let (lo, hi) = field == .risk ? (0.1, 10.0) : (0.01, 100.0)
        return v >= lo && v <= hi ? v : nil
    }
    public static func lot(_ text: String, separator: String) -> Double? { value(text, separator: separator, field: .lot) }
    public static func risk(_ text: String, separator: String) -> Double? { value(text, separator: separator, field: .risk) }
}

public enum Alarm {
    public enum Sound: String, CaseIterable, Sendable, Identifiable {
        case alarm, beep, off
        public var id: String { rawValue }
        public var label: String { switch self { case .alarm: "Emergency Alarm"; case .beep: "Beep"; case .off: "Off" } }
    }

    public static func wav(_ sound: Sound) -> Data {
        let rate = 44_100.0, length = sound == .beep ? 0.25 : 1.6
        let n = Int(length * rate)
        var samples = [Int16](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / rate
            let f = sound == .beep ? 880.0 : (Int(t / 0.2) % 2 == 1 ? 660.0 : 960.0)
            phase += 2 * .pi * f / rate
            let wave = sound == .beep ? sin(phase) : (sin(phase) >= 0 ? 1.0 : -1.0)
            let gain = t > length - 0.05 ? 0.18 * (length - t) / 0.05 : 0.18
            samples[i] = Int16(wave * gain * 32_767)
        }
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + n * 2)); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(44_100); u32(88_200); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(n * 2))
        samples.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }

    public static func shouldRing(shownNewest: String?, page: [Message]) -> Bool {
        guard let s = shownNewest.flatMap({ Int64($0) }) else { return false }
        return page.contains { $0.order > s && ($0.kind == .signal || $0.kind == .signalUpdate) }
    }
}
