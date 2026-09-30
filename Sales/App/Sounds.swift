import AVFoundation
import Foundation
import SalesKit

enum Sounds {
    static let rate = 44_100.0

    static func install() {
        let dir = librarySounds
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, samples) in [("chime.wav", chime()), ("coin.wav", coin())] {
            let url = dir.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) { try? wav(samples).write(to: url, options: .atomic) }
        }
    }

    static func url(_ s: SoundChoice) -> URL? {
        switch s {
        case .shopify: Bundle.main.url(forResource: "shopify", withExtension: "caf")
        case .chime, .coin: s.file.map { librarySounds.appendingPathComponent($0) }
        case .system: nil
        }
    }

    private static var librarySounds: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds")
    }

    static var silence: Data { wav([Float](repeating: 0, count: Int(rate))) }

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

    private static func tone(_ out: inout [Float], at: Double, freq: Double, amp: Double, length: Double, decay: Double, square: Bool = false) {
        let start = Int(at * rate), n = min(Int(length * rate), out.count - start)
        guard n > 0 else { return }
        for i in 0..<n {
            let t = Double(i) / rate
            var v = sin(2 * .pi * freq * t)
            if square { v = v >= 0 ? 0.6 : -0.6 }
            out[start + i] += Float(v * amp * min(1, t / 0.002) * exp(-t / decay))
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
