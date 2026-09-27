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
