import Foundation
import Testing
@testable import JynxKit

@Test func readsServerDatesWithAndWithoutMilliseconds() throws {
    let a = try #require(JSON.parseDate("2026-09-27T03:07:17.123Z"))
    let b = try #require(JSON.parseDate("2026-09-27T03:07:17Z"))
    #expect(abs(a.timeIntervalSince(b) - 0.123) < 0.001)
    #expect(JSON.parseDate("yesterday") == nil)
}
