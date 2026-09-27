public enum Look {
    public static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace).prefix(2)
        let s = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return s.isEmpty ? "?" : s
    }

    public static func tone(_ name: String) -> Int {
        var h: UInt32 = 0
        for scalar in name.unicodeScalars {
            let unit = String(scalar).utf16.first ?? 0
            h = h &* 31 &+ UInt32(unit)
        }
        return Int(h % 6)
    }

    public enum Tone: Sendable { case gain, loss, neutral }

    public static func updateTone(_ body: String) -> Tone {
        func pips(after prefix: String) -> Double? {
            guard let r = body.range(of: prefix) else { return nil }
            let rest = body[r.upperBound...]
            guard let m = rest.range(of: #"^[+-]?\d+(\.\d+)?(?= pips)"#, options: .regularExpression) else { return nil }
            return Double(rest[m])
        }
        let v: Double? = pips(after: "result ") ?? {
            guard let m = body.range(of: #"[+-]?\d+(\.\d+)?(?= pips)"#, options: .regularExpression) else { return nil }
            return Double(body[m])
        }()
        guard let v, v != 0 else { return .neutral }
        return v > 0 ? .gain : .loss
    }
}
