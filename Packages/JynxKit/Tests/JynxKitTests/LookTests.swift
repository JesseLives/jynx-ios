import Foundation
import Testing
@testable import JynxKit

@Test func avatarToneMatchesTheSite() {
    #expect(Look.tone("Gold Signal VVIP") == 3)
    #expect(Look.tone("Copy Trade Scalping") == 2)
    #expect(Look.tone("a") == 1)
    #expect(Look.tone("  ") == 4)
    #expect(Look.tone("Élan vital") == 2)
    #expect(Look.tone(String(repeating: "x", count: 40)) == 2)
}

@Test func initialsMatchTheSite() {
    #expect(Look.initials("Gold Signal VVIP") == "GS")
    #expect(Look.initials("Lounge muh9c1f0") == "LM")
    #expect(Look.initials("a") == "A")
    #expect(Look.initials("  ") == "?")
    #expect(Look.initials("Élan vital") == "ÉV")
}

@Test func dayLabels() {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
    let now = JSON.parseDate("2026-09-27T10:00:00Z")!
    #expect(Format.day(JSON.parseDate("2026-09-27T01:00:00Z")!, now: now, calendar: cal) == "Today")
    #expect(Format.day(JSON.parseDate("2026-09-26T01:00:00Z")!, now: now, calendar: cal) == "Yesterday")
    #expect(Format.day(JSON.parseDate("2026-09-20T01:00:00Z")!, now: now, calendar: cal) == "20 Sept 2026" ||
            Format.day(JSON.parseDate("2026-09-20T01:00:00Z")!, now: now, calendar: cal) == "20 Sep 2026")
}

@Test func clockTime() {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
    #expect(Format.clock(JSON.parseDate("2026-09-27T10:51:00Z")!, calendar: cal) == "17:51")
}

@Test func updateTones() {
    #expect(Look.updateTone("TP1 hit +150 pips, closed 50%") == .gain)
    #expect(Look.updateTone("Closed at 1.083 +20 pips, result +20 pips") == .gain)
    #expect(Look.updateTone("SL hit -100 pips, result -25 pips") == .loss)
    #expect(Look.updateTone("SL hit +30 pips, result +80 pips") == .gain)     // a trailed stop can still win
    #expect(Look.updateTone("Closed 50% at 2370 -12 pips") == .loss)
    #expect(Look.updateTone("SL moved to breakeven") == .neutral)
    #expect(Look.updateTone("Signal cancelled") == .neutral)
    #expect(Look.updateTone("Closed at 2350 0 pips, result 0 pips") == .neutral)
}
