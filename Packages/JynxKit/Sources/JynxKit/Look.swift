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
}
