import Foundation

public struct QRCountdown: Equatable, Sendable {
    public let expiresAt: Date
    public init(expiresAt: Date) { self.expiresAt = expiresAt }
    public func expired(at now: Date) -> Bool { now >= expiresAt }
    public func remaining(at now: Date) -> String {
        let s = max(0, Int(expiresAt.timeIntervalSince(now).rounded(.up)))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
}

public enum PayPhase: Equatable, Sendable {
    case waiting, paid(endsAt: Date?), rejected(String), expired

    public static let expiredReason = "Not paid before the QR expired."

    public static func of(_ state: PaymentState?, expiresAt: Date, now: Date) -> PayPhase {
        switch state?.status {
        case .approved?: return .paid(endsAt: state?.endsAt)
        case .rejected?:
            let reason = state?.rejectReason ?? ""
            return reason == expiredReason ? .expired : .rejected(reason)
        default: return now >= expiresAt ? .expired : .waiting
        }
    }
}

public enum Receipt {
    public static let maxBytes = 5 * 1024 * 1024

    public static func mime(of d: Data) -> String? {
        let b = [UInt8](d.prefix(12))
        if b.count >= 8, b[0..<8] == [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] { return "image/png" }
        if b.count >= 3, b[0] == 0xff, b[1] == 0xd8, b[2] == 0xff { return "image/jpeg" }
        if b.count >= 12, b[0..<4].elementsEqual("RIFF".utf8), b[8..<12].elementsEqual("WEBP".utf8) { return "image/webp" }
        return nil
    }

    public static func problem(_ d: Data) -> String? {
        mime(of: d) == nil || d.count > maxBytes ? Copy.codes["bad_receipt"] : nil
    }
}

public enum Multipart {
    public struct File: Sendable {
        public let name: String, filename: String, mime: String, data: Data
        public init(name: String, filename: String, mime: String, data: Data) {
            self.name = name; self.filename = filename; self.mime = mime; self.data = data
        }
    }

    public static func body(fields: [(String, String)], file: File?, boundary: String) -> Data {
        var d = Data()
        for (k, v) in fields {
            d += Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n".utf8)
        }
        if let f = file {
            d += Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(f.name)\"; filename=\"\(f.filename)\"\r\nContent-Type: \(f.mime)\r\n\r\n".utf8)
            d += f.data + Data("\r\n".utf8)
        }
        d += Data("--\(boundary)--\r\n".utf8)
        return d
    }
}
