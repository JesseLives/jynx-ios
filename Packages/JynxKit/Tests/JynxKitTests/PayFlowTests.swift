import Foundation
import Testing
@testable import JynxKit

private let expires = Date(timeIntervalSince1970: 1_000_000)

@Test func countdownReadsLikeTheSite() {
    #expect(QRCountdown(expiresAt: expires).remaining(at: expires.addingTimeInterval(-899)) == "14:59")
    #expect(QRCountdown(expiresAt: expires).remaining(at: expires.addingTimeInterval(-5)) == "0:05")
    #expect(QRCountdown(expiresAt: expires).remaining(at: expires.addingTimeInterval(10)) == "0:00")
    #expect(QRCountdown(expiresAt: expires).expired(at: expires))
    #expect(!QRCountdown(expiresAt: expires).expired(at: expires.addingTimeInterval(-1)))
}

private func state(_ s: PaymentStatus, _ reason: String? = nil, ends: Date? = nil) -> PaymentState {
    PaymentState(status: s, rejectReason: reason, kind: "plan", amountCents: 100, endsAt: ends)
}

@Test func payPhases() {
    let before = expires.addingTimeInterval(-60), after = expires.addingTimeInterval(1)
    #expect(PayPhase.of(nil, expiresAt: expires, now: before) == .waiting)
    #expect(PayPhase.of(state(.pending), expiresAt: expires, now: before) == .waiting)
    #expect(PayPhase.of(state(.approved, ends: expires), expiresAt: expires, now: after) == .paid(endsAt: expires))
    #expect(PayPhase.of(state(.rejected, "The bank said the payment failed."), expiresAt: expires, now: before)
            == .rejected("The bank said the payment failed."))
}

@Test func expiryIsNotAFailure() {
    let after = expires.addingTimeInterval(1)
    #expect(PayPhase.of(state(.pending), expiresAt: expires, now: after) == .checking)
    #expect(PayPhase.of(state(.pending), expiresAt: expires, now: expires.addingTimeInterval(179)) == .checking)
    #expect(PayPhase.of(state(.pending), expiresAt: expires, now: expires.addingTimeInterval(181)) == .expired)
    #expect(PayPhase.of(nil, expiresAt: expires, now: expires.addingTimeInterval(181)) == .expired)
    #expect(PayPhase.of(state(.approved, ends: expires), expiresAt: expires, now: expires.addingTimeInterval(120)) == .paid(endsAt: expires))
    #expect(PayPhase.checking.keepsPolling && PayPhase.waiting.keepsPolling && !PayPhase.expired.keepsPolling)
    #expect(PayPhase.of(state(.rejected, "Not paid before the QR expired."), expiresAt: expires, now: after) == .expired)
}

@Test func multipartBodyIsExact() {
    let body = Multipart.body(fields: [("productId", "p1"), ("months", "3")],
                              file: Multipart.File(name: "receipt", filename: "receipt.jpg", mime: "image/jpeg", data: Data([0xff, 0xd8, 0xff])),
                              boundary: "XyZ")
    var want = Data("--XyZ\r\nContent-Disposition: form-data; name=\"productId\"\r\n\r\np1\r\n".utf8)
    want += Data("--XyZ\r\nContent-Disposition: form-data; name=\"months\"\r\n\r\n3\r\n".utf8)
    want += Data("--XyZ\r\nContent-Disposition: form-data; name=\"receipt\"; filename=\"receipt.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
    want += Data([0xff, 0xd8, 0xff]) + Data("\r\n--XyZ--\r\n".utf8)
    #expect(body == want)
}

@Test func receiptCheckMatchesTheServer() {
    let png = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0])
    let jpeg = Data([0xff, 0xd8, 0xff, 0xe0])
    let webp = Data("RIFF".utf8) + Data([1, 2, 3, 4]) + Data("WEBP".utf8)
    let heic = Data([0, 0, 0, 0x18]) + Data("ftypheic".utf8)
    #expect(Receipt.mime(of: png) == "image/png" && Receipt.mime(of: jpeg) == "image/jpeg" && Receipt.mime(of: webp) == "image/webp")
    #expect(Receipt.mime(of: heic) == nil)
    #expect(Receipt.problem(jpeg) == nil)
    #expect(Receipt.problem(heic) == "The receipt must be a PNG, JPEG or WebP image under 5 MB.")
    #expect(Receipt.problem(jpeg + Data(count: 5 * 1024 * 1024)) != nil)
}

@Test func manualPaymentGoesAsMultipart() async throws {
    let t = StubTransport(); t.body = try fixture("payment-created")
    let id = try await api(t).payManually(fields: [("productId", "p1"), ("months", "1"), ("method", "usdt"), ("reference", "tx")],
                                          receipt: Data([0xff, 0xd8, 0xff]))
    let r = t.seen[0]
    let want = try #require((try JSONSerialization.jsonObject(with: fixture("payment-created")) as? [String: Any])?["payment"] as? [String: Any])["id"] as? String
    #expect(id == want && r.httpMethod == "POST" && r.url?.path == "/api/payments")
    t.body = try fixture("deposit-created")
    #expect(try await api(t).payManually(fields: [("kind", "deposit")], receipt: nil).isEmpty == false)
    #expect(r.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
    #expect(String(decoding: r.httpBody!, as: UTF8.self).contains("name=\"receipt\"; filename=\"receipt.jpg\""))
}
