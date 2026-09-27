import Foundation
import Testing
@testable import JynxKit

@Test func decodesCopierStates() throws {
    let none = try JSON.decoder().decode(CopierState.self, from: fixture("copier-none"))
    #expect(none.hasPass && none.account == nil && none.copies.isEmpty)
    let on = try JSON.decoder().decode(CopierState.self, from: fixture("copier-online"))
    #expect(on.account?.status == .online && on.account?.mode == .risk && on.account?.riskPct == 1.5 && on.account?.enabled == true)
    #expect(on.copies.map(\.status).sorted { $0.rawValue < $1.rawValue } == [.opened, .skipped])
    let bad = try JSON.decoder().decode(CopierState.self, from: fixture("copier-error"))
    #expect(bad.account?.status == .error && bad.account?.lastError == "Invalid account credentials")
}

private func account(_ status: CopierAccount.Status, enabled: Bool = true) -> CopierAccount {
    CopierAccount(login: "5012345", server: "Exness-MT5Trial8", status: status, lastError: nil, mode: .fixed,
                  fixedLot: 0.1, riskPct: 1, maxLot: 1, enabled: enabled)
}

@Test func powerButtonStates() {
    let sub = "5012345, Exness-MT5Trial8"
    #expect(CopierPower.of(hasPass: true, account: nil) == CopierPower(ring: .off, label: "Not connected", sub: nil, tappable: false))
    #expect(CopierPower.of(hasPass: false, account: nil).label == "Copier Pass needed")
    #expect(CopierPower.of(hasPass: true, account: account(.error)) == CopierPower(ring: .error, label: "Could not connect", sub: sub, tappable: false))
    #expect(CopierPower.of(hasPass: true, account: account(.pending)).ring == .wait)
    #expect(CopierPower.of(hasPass: true, account: account(.connecting)).label == "Connecting")
    #expect(CopierPower.of(hasPass: false, account: account(.online)) == CopierPower(ring: .off, label: "Copier Pass ended", sub: sub, tappable: false))
    #expect(CopierPower.of(hasPass: true, account: account(.online)) == CopierPower(ring: .on, label: "Copying", sub: sub, tappable: true))
    #expect(CopierPower.of(hasPass: true, account: account(.online, enabled: false)) == CopierPower(ring: .off, label: "Tap to start", sub: sub, tappable: true))
}

@Test func copyTextLikeTheSite() {
    #expect(CopyText.reason("price_moved") == "Price had moved too far")
    #expect(CopyText.reason("some_new_reason") == "some new reason")
    #expect(CopyText.status(.opened) == "Open" && CopyText.status(.pending) == "Sending" && CopyText.status(.skipped) == "Skipped")
}

@Test func copierInputsAreNumbersInRange() {
    #expect(CopierInput.lot("0,05", separator: ",") == 0.05)
    #expect(CopierInput.lot("0.05", separator: ".") == 0.05)
    #expect(CopierInput.lot("0", separator: ".") == nil)
    #expect(CopierInput.lot("150", separator: ".") == nil)
    #expect(CopierInput.lot("0.005", separator: ".") == nil)
    #expect(CopierInput.risk("1,5", separator: ",") == 1.5)
    #expect(CopierInput.risk("11", separator: ".") == nil)
    #expect(CopierInput.risk("0.05", separator: ".") == nil)
    #expect(CopierInput.range(.risk) == "0.1 to 10")
}

@Test func settingsGoAsNumbers() async throws {
    let t = StubTransport()
    try await api(t).copierSettings(mode: .risk, fixedLot: 0.1, riskPct: 1.5, maxLot: 2, enabled: true)
    let b = try #require(JSONSerialization.jsonObject(with: t.seen[0].httpBody!) as? [String: Any])
    #expect(b["action"] as? String == "settings" && b["mode"] as? String == "risk")
    #expect(b["riskPct"] as? Double == 1.5 && b["maxLot"] as? Double == 2 && b["enabled"] as? Bool == true)
    try await api(t).disconnectMT5()
    #expect(t.seen[1].httpMethod == "DELETE" && t.seen[1].url?.path == "/api/copier")
}

@Test func alarmSoundsLikeTheSite() throws {
    let beep = Alarm.wav(.beep)
    #expect(beep.prefix(4) == Data("RIFF".utf8) && beep[8..<12] == Data("WAVE".utf8))
    #expect(beep.count == 44 + Int(0.25 * 44_100) * 2)
    let siren = Alarm.wav(.alarm)
    #expect(siren.count == 44 + Int(1.6 * 44_100) * 2)
    func crossings(_ d: Data, from s: Double) -> Int {
        let samples = d.dropFirst(44).withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        let a = Int(s * 44_100), w = Array(samples[a..<(a + 4_410)])
        return zip(w, w.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
    }
    #expect(abs(crossings(siren, from: 0.05) - 192) <= 4)
    #expect(abs(crossings(siren, from: 0.25) - 132) <= 4)   // 660 Hz
}

@Test func alarmRingsOnlyForNewSignals() {
    func m(_ id: Int, _ kind: MessageKind) -> Message {
        Message(id: String(id), roomId: "r", kind: kind, body: "", hasMedia: false, signalId: nil, author: nil, createdAt: .now)
    }
    #expect(!Alarm.shouldRing(shownNewest: nil, page: [m(5, .signal)]))
    #expect(!Alarm.shouldRing(shownNewest: "5", page: [m(6, .text), m(5, .signal)]))
    #expect(Alarm.shouldRing(shownNewest: "5", page: [m(6, .signal), m(5, .signal)]))
    #expect(Alarm.shouldRing(shownNewest: "5", page: [m(7, .text), m(6, .signalUpdate)]))
    #expect(!Alarm.shouldRing(shownNewest: "9", page: [m(6, .signal)]))
}
