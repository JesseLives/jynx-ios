import Foundation
import Testing
@testable import JynxKit

@Test func moneyLikeTheSite() {
    #expect(Format.money("2350") == "2,350.00")
    #expect(Format.money("1.08500") == "1.085")
    #expect(Format.money("1.085123") == "1.08512")
}

@Test func pipsSigned() {
    #expect(Format.pips(15) == "+15 pips")
    #expect(Format.pips(-7.5) == "-7.5 pips")
    #expect(Format.pips(0) == "0 pips")
}

@Test func chatTimes() {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
    let now = JSON.parseDate("2026-09-27T10:00:00Z")!               // 17:00 in Phnom Penh
    #expect(Format.chatTime(JSON.parseDate("2026-09-27T02:05:00Z")!, now: now, calendar: cal) == "09:05")
    #expect(Format.chatTime(JSON.parseDate("2026-09-25T02:05:00Z")!, now: now, calendar: cal) == "Fri")
    #expect(Format.chatTime(JSON.parseDate("2026-08-01T02:05:00Z")!, now: now, calendar: cal) == "1 Aug")
}
