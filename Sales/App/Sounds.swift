import Foundation

enum Sounds {
    static let rate = 44_100.0

    static func install() {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, samples) in [("kaching", kaching()), ("chime", chime()), ("coin", coin())] {
            try? wav(samples).write(to: dir.appendingPathComponent("\(name).wav"))
        }
    }

    static func url(_ s: NotificationSound) -> URL? {
        guard let f = s.file else { return nil }
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds/\(f)")
    }

    static var silence: Data { wav([Float](repeating: 0, count: Int(rate))) }

    static func kaching() -> [Float] {
        var out = [Float](repeating: 0, count: Int(rate * 1.1))
        var seed: UInt32 = 1
        for i in 0..<Int(rate * 0.035) {                        // "ka": a burst of noise
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Float(Int32(bitPattern: seed)) / Float(Int32.max)
            out[i] += noise * 0.35 * Float(exp(-Double(i) / (rate * 0.008)))
        }
        bell(&out, at: 0.05, freq: 2_093, amp: 0.32, decay: 0.35)  // "ching": C7
        bell(&out, at: 0.06, freq: 2_637, amp: 0.26, decay: 0.45)  // and E7
        return out
    }

    static func chime() -> [Float] {
        var out = [Float](repeating: 0, count: Int(rate * 0.9))
        tone(&out, at: 0, freq: 1_319, amp: 0.4, length: 0.35, decay: 0.12)
        tone(&out, at: 0.12, freq: 1_976, amp: 0.4, length: 0.75, decay: 0.25)
        return out
    }

    static func coin() -> [Float] {
        var out = [Float](repeating: 0, count: Int(rate * 0.5))
        tone(&out, at: 0, freq: 988, amp: 0.9, length: 0.08, decay: 1, square: true)
        tone(&out, at: 0.08, freq: 1_319, amp: 0.9, length: 0.4, decay: 0.15, square: true)
        return out
    }

    private static func bell(_ out: inout [Float], at: Double, freq: Double, amp: Double, decay: Double) {
        for (mult, share) in [(1.0, 1.0), (2.76, 0.4), (5.4, 0.2)] {
            tone(&out, at: at, freq: freq * mult, amp: amp * share, length: Double(out.count) / rate - at, decay: decay / mult.squareRoot())
        }
    }

    private static func tone(_ out: inout [Float], at: Double, freq: Double, amp: Double, length: Double, decay: Double, square: Bool = false) {
        let start = Int(at * rate), n = min(Int(length * rate), out.count - start)
        guard n > 0 else { return }
        for i in 0..<n {
            let t = Double(i) / rate
            var v = sin(2 * .pi * freq * t)
            if square { v = v >= 0 ? 0.6 : -0.6 }
            let attack = min(1, t / 0.002)                          // no click at the start
            out[start + i] += Float(v * amp * attack * exp(-t / decay))
        }
    }

    static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        for s in samples { u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32_767))) }
        return d
    }
}
