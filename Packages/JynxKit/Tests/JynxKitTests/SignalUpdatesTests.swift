import Foundation
import Testing
@testable import JynxKit

@Test func everyKindOfUpdateDecodes() throws {
    let s = try JSON.decoder().decode(SignalBody.self, from: fixture("signal-every-update")).signal
    #expect(s.updates.map(\.kind) == ["move_sl", "tp_hit", "breakeven", "sl_hit"])
    #expect(s.status == .closed)
}

@Test func aCancelledSignalDecodes() throws {
    let s = try JSON.decoder().decode(SignalBody.self, from: fixture("signal-cancelled")).signal
    #expect(s.status == .cancelled)
}
