import XCTest
@testable import SalesKit

struct Seeded: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class ScheduleTests: XCTestCase {
    func testCounts() {
        XCTAssertEqual(sessionCount(length: .tenMinutes, perTenSeconds: 100), 5_000)   // 6,000 capped
        XCTAssertEqual(sessionCount(length: .tenMinutes, perTenSeconds: 10), 600)
        XCTAssertEqual(sessionCount(length: .oneMinute, perTenSeconds: 10), 60)
        XCTAssertEqual(sessionCount(length: .now, perTenSeconds: 400), 1)
        XCTAssertEqual(sessionCount(length: .allDay, perTenSeconds: 1), 4_320)
        XCTAssertEqual(sessionCount(length: .oneMinute, perTenSeconds: 0), 6)           // rate floors at 1
        XCTAssertEqual(sessionCount(length: .oneMinute, perTenSeconds: 99_999), 3_000)  // rate caps at 500
    }

    func testLinearIsEven() {
        var g = Seeded(s: 1)
        let t = fireTimes(count: 60, over: 60, pacing: .linear, rng: &g)
        XCTAssertEqual(t.count, 60)
        for (a, b) in zip(t, t.dropFirst()) { XCTAssertEqual(b - a, 1, accuracy: 1e-9) }
        XCTAssertGreaterThan(t.first!, 0)
        XCTAssertLessThan(t.last!, 60)
    }

    func testVariableHasBurstsAndSilencesInsideTheSession() {
        for seed: UInt64 in [1, 2, 3, 42, 99] {
            var g = Seeded(s: seed)
            let t = fireTimes(count: 600, over: 600, pacing: .variable, rng: &g)
            XCTAssertEqual(t.count, 600)
            XCTAssertEqual(t, t.sorted())
            XCTAssertGreaterThanOrEqual(t.first!, 0)
            XCTAssertLessThanOrEqual(t.last!, 600)
            let gaps = zip(t.dropFirst(), t).map { $0 - $1 }
            XCTAssertGreaterThan(gaps.filter { $0 < 0.5 }.count, 100, "bursts")
            XCTAssertTrue(gaps.contains { $0 > 4 }, "silences")
        }
        var g = Seeded(s: 5)
        XCTAssertEqual(fireTimes(count: 5_000, over: 43_200, pacing: .variable, rng: &g).count, 5_000)
        XCTAssertEqual(fireTimes(count: 1, over: 0, pacing: .variable, rng: &g), [0])
        XCTAssertEqual(fireTimes(count: 0, over: 60, pacing: .linear, rng: &g), [])
    }
}

final class RealisticTests: XCTestCase {
    func testFiveToTenInEveryHalfHourAtRandomTimes() {
        for seed: UInt64 in [1, 2, 3, 7, 11] {
            var g = Seeded(s: seed)
            let t = realisticTimes(over: 12 * 3_600, perHalfHour: 5...10, rng: &g)
            XCTAssertEqual(t, t.sorted())
            XCTAssertGreaterThanOrEqual(t.first!, 0)
            XCTAssertLessThan(t.last!, 12 * 3_600)
            XCTAssertTrue((24 * 5...24 * 10).contains(t.count), "\(t.count)")
            for block in 0..<24 {
                let inBlock = t.filter { $0 >= Double(block) * 1_800 && $0 < Double(block + 1) * 1_800 }.count
                XCTAssertTrue((5...10).contains(inBlock), "half hour \(block): \(inBlock)")
            }
            let gaps = zip(t.dropFirst(), t).map { $0 - $1 }
            XCTAssertTrue(gaps.contains { $0 < 60 } && gaps.contains { $0 > 400 })
        }
    }

    func testAShortSessionGetsItsShareAndNeverNothing() {
        var total = 0
        for seed: UInt64 in 1...200 {
            var g = Seeded(s: seed)
            let t = realisticTimes(over: 600, perHalfHour: 5...10, rng: &g)   // a third of a half hour
            XCTAssertTrue((1...4).contains(t.count), "\(t.count)")
            XCTAssertTrue(t.allSatisfy { $0 >= 0 && $0 < 600 })
            total += t.count
        }
        XCTAssertEqual(Double(total) / 200, 2.5, accuracy: 0.35, "on average a third of 7.5")
        var g = Seeded(s: 1)
        XCTAssertEqual(realisticTimes(over: 1_800, perHalfHour: 0...0, rng: &g).count, 1, "never an empty session")
        XCTAssertEqual(realisticTimes(over: 1_800, perHalfHour: 3...3, rng: &g).count, 3)
    }

    func testSessionUsesRealisticPacingAndItsOwnCount() {
        var s = Settings()
        s.length = .oneHour
        s.pacing = .realistic
        s.perHalfHour = 5...10
        XCTAssertEqual(s.expectedCount, 15)
        var g = Seeded(s: 5)
        let session = Session(settings: s, start: Date(), firstOrder: 100, badgeBase: 0, rng: &g)
        XCTAssertTrue((10...20).contains(session.total))
        XCTAssertEqual(session.sales.count, session.total)
        XCTAssertEqual(session.sales.last?.order, 100 + session.total - 1)
    }
}

final class TextTests: XCTestCase {
    func testTheRealShopifyNotificationIsTheDefault() {
        let s = Settings()
        XCTAssertEqual(s.text.title, "New order")
        let one = Sale(order: 7481, product: "Tee", items: 1, cents: 5_154)
        XCTAssertEqual(fill(s.text.body, sale: one, store: "BYMAR"), "[BYMAR] You have a new order for 1 item totaling $51.54 from Online Store.")
        let seven = Sale(order: 7482, product: "Tee", items: 7, cents: 28_592)
        XCTAssertEqual(fill(s.text.body, sale: seven, store: "BYMAR"), "[BYMAR] You have a new order for 7 items totaling $285.92 from Online Store.")
    }

    func testTheLarpStyleNotificationIsStillThere() {
        let sale = Sale(order: 7481, product: "My Product", items: 1, cents: 3_899)
        XCTAssertEqual(fill(presets[1].title, sale: sale, store: "My Store"), "Order #7481 from Shopify")
        XCTAssertEqual(fill(presets[1].body, sale: sale, store: "My Store"), "$38.99, 1 item from Online Store - My Store")
    }

    func testPluralsAndProducts() {
        let sale = Sale(order: 1, product: "Hoodie", items: 3, cents: 14_997)
        XCTAssertEqual(fill("{amount}, {items}", sale: sale, store: ""), "$149.97, 3 items")
        XCTAssertEqual(fill("{product}", sale: sale, store: ""), "Hoodie × 3")
    }

    func testMoney() {
        XCTAssertEqual(money(116_970), "$1,169.70")
        XCTAssertEqual(money(5), "$0.05")
        XCTAssertEqual(money(0), "$0.00")
        XCTAssertEqual(money(123_456_789), "$1,234,567.89")
        XCTAssertEqual(shortMoney(99_900), "$999")
        XCTAssertEqual(shortMoney(420_837), "$4.2K")
        XCTAssertEqual(shortMoney(1_000_000), "$10K")
        XCTAssertEqual(shortMoney(123_456_789), "$1.2M")
    }
}

final class SessionTests: XCTestCase {
    func settings(_ edit: (inout Settings) -> Void = { _ in }) -> Settings {
        var s = Settings()
        s.length = .oneMinute
        s.perTenSeconds = 10
        s.pacing = .linear
        edit(&s)
        return s
    }

    func testSalesComeFromTheProductsAndTheTotalsAgree() {
        let s = settings {
            $0.products = [Product(name: "Hoodie", priceCents: 4_999), Product(name: "Cap", priceCents: 2_400), Product(name: "Free", priceCents: 0)]
            $0.maxItems = 3
            $0.varyTotals = false
        }
        var g = Seeded(s: 9)
        let start = Date(timeIntervalSince1970: 1_000_000)
        var session = Session(settings: s, start: start, firstOrder: 7_481, badgeBase: 0, rng: &g)
        XCTAssertEqual(session.total, 60)
        XCTAssertEqual(session.sales.map(\.order), Array(7_481..<7_541))
        XCTAssertTrue(session.sales.allSatisfy { ["Hoodie", "Cap"].contains($0.product) }, "a free product is never sold")
        XCTAssertTrue(session.sales.allSatisfy { (1...3).contains($0.items) })
        XCTAssertEqual(Set(session.sales.map(\.product)), ["Hoodie", "Cap"], "both products turn up")
        for sale in session.sales { XCTAssertEqual(sale.cents, (sale.product == "Hoodie" ? 4_999 : 2_400) * sale.items) }

        XCTAssertTrue(session.advance(to: start).isEmpty)
        let first = session.advance(to: start.addingTimeInterval(10))
        XCTAssertEqual(first.count, 10)
        XCTAssertEqual(session.counted, 10)
        XCTAssertTrue(session.advance(to: start.addingTimeInterval(10)).isEmpty, "never counted twice")
        _ = session.advance(to: start.addingTimeInterval(3_600))
        XCTAssertTrue(session.finished)
        XCTAssertEqual(session.deliveredCents, session.sales.reduce(0) { $0 + $1.cents })
        XCTAssertEqual(session.delivered, 60)
    }

    func testAfterARelaunchOnlyWhatWasHandedToIOSCounts() {
        var g = Seeded(s: 4)
        let start = Date(timeIntervalSince1970: 0)
        var session = Session(settings: settings(), start: start, firstOrder: 1, badgeBase: 0, rng: &g)
        _ = session.advance(to: start.addingTimeInterval(5))                   // 5 counted while open
        let back = session.advance(to: start.addingTimeInterval(30), sentBelow: 12)
        XCTAssertEqual(back.map(\.sale.order), Array(6...12))
        XCTAssertEqual(session.counted, 30)
        XCTAssertEqual(session.delivered, 12)
        XCTAssertEqual(session.deliveredCents, session.sales.prefix(12).reduce(0) { $0 + $1.cents })
    }

    func testNotificationTextMatchesTheSale() {
        var g = Seeded(s: 3)
        let session = Session(settings: settings { $0.store = "Drip Co" }, start: Date(), firstOrder: 1_000, badgeBase: 0, rng: &g)
        let sale = session.sales[4]
        XCTAssertEqual(session.title(4), "New order")
        XCTAssertEqual(session.body(4), "[Drip Co] You have a new order for \(sale.items == 1 ? "1 item" : "\(sale.items) items") totaling \(money(sale.cents)) from Online Store.")
    }

    func testTotalsVaryLikeTaxAndShippingOrStayExact() {
        var g = Seeded(s: 8)
        let varied = Session(settings: settings { $0.products = [Product(name: "Tee", priceCents: 5_000)]; $0.varyTotals = true },
                             start: Date(), firstOrder: 1, badgeBase: 0, rng: &g)
        XCTAssertTrue(varied.sales.allSatisfy { (4_600...5_750).contains($0.cents) }, "within -8% and +15% of $50.00")
        XCTAssertGreaterThan(Set(varied.sales.map { $0.cents }).count, 30, "uneven cents, not one repeated price")
        XCTAssertTrue(varied.sales.contains { $0.cents % 100 != 0 })
        let exact = Session(settings: settings { $0.products = [Product(name: "Tee", priceCents: 5_000)]; $0.varyTotals = false },
                            start: Date(), firstOrder: 1, badgeBase: 0, rng: &g)
        XCTAssertTrue(exact.sales.allSatisfy { $0.cents == 5_000 * $0.items })
        XCTAssertTrue(Settings().varyTotals, "on by default")
    }

    func testBadgeCountsUpAndRestartsAfterAClear() {
        var g = Seeded(s: 1)
        var session = Session(settings: settings(), start: Date(), firstOrder: 1, badgeBase: 5, rng: &g)
        XCTAssertEqual(session.badge(0), 6)
        XCTAssertEqual(session.badge(9), 15)
        _ = session.advance(to: session.fireDate(19))   // 20 counted
        session.badgeBase = -session.counted            // what clearing the badge does
        XCTAssertEqual(session.badge(20), 1)
        XCTAssertEqual(session.badge(21), 2)
    }

    func testASingleNotificationIsOneSale() {
        var g = Seeded(s: 1)
        let start = Date()
        var session = Session(settings: settings { $0.length = .now }, start: start, firstOrder: 1, badgeBase: 0, rng: &g)
        XCTAssertEqual(session.total, 1)
        XCTAssertEqual(session.fireDate(0), start)
        XCTAssertEqual(session.advance(to: start).count, 1)
        XCTAssertTrue(session.finished)
    }

    func testSurvivesSavingAndLoading() throws {
        var g = Seeded(s: 1)
        var session = Session(settings: settings(), start: Date(timeIntervalSince1970: 5_000), firstOrder: 1, badgeBase: 0, rng: &g)
        _ = session.advance(to: session.fireDate(29))
        let back = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(back, session)
        XCTAssertEqual(back.counted, 30)
    }
}

final class TodayTests: XCTestCase {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    func testAddsUpAndStartsOverOnANewDay() {
        var t = Today()
        let noon = Date(timeIntervalSince1970: 1_790_000_000)   // a day in 2026
        t.add(Sale(order: 1, product: "A", items: 1, cents: 1_000), at: noon, calendar: utc)
        t.add(Sale(order: 2, product: "A", items: 2, cents: 2_000), at: noon, calendar: utc)
        XCTAssertEqual(t.cents, 3_000)
        XCTAssertEqual(t.orders, 2)
        XCTAssertEqual(t.shown(at: noon, calendar: utc).cents, 3_000)
        let tomorrow = noon.addingTimeInterval(86_400)
        XCTAssertEqual(t.shown(at: tomorrow, calendar: utc).cents, 0)
        t.add(Sale(order: 3, product: "A", items: 1, cents: 500), at: tomorrow, calendar: utc)
        XCTAssertEqual(t.cents, 500)
        XCTAssertEqual(t.orders, 1)
    }

    func testASaleFromAnEarlierDayNeverRewindsToday() {
        let noon = Date(timeIntervalSince1970: 1_790_000_000)
        let tomorrow = noon.addingTimeInterval(86_400)
        var t = Today(day: Today.key(tomorrow, calendar: utc))
        t.add(Sale(order: 1, product: "A", items: 1, cents: 1_000), at: noon, calendar: utc)
        XCTAssertEqual(t, Today(day: Today.key(tomorrow, calendar: utc)), "yesterday's sale is not today's")
        t.add(Sale(order: 2, product: "A", items: 1, cents: 700), at: tomorrow, calendar: utc)
        XCTAssertEqual(t.cents, 700)
    }
}

final class SettingsTests: XCTestCase {
    func testOlderSavedSettingsStillLoad() throws {
        let old = #"{"textMode":"custom","custom":{"title":"Hi","body":"There"},"perTenSeconds":50,"platform":"shopify","when":"tenMinutes"}"#
        let s = try JSONDecoder().decode(Settings.self, from: Data(old.utf8))
        XCTAssertEqual(s.textMode, .custom)
        XCTAssertEqual(s.text, NotificationText(title: "Hi", body: "There"))
        XCTAssertEqual(s.perTenSeconds, 50)
        XCTAssertEqual(s.products.map(\.name), ["My Product"])
        XCTAssertEqual(s.products.map(\.priceCents), [3_899])
        XCTAssertEqual(s.sound, .shopify)
        XCTAssertTrue(s.badge)
    }

    func testAPresetIndexOutOfRangeStillGivesText() {
        var s = Settings()
        s.presetIndex = 99
        XCTAssertEqual(s.text, presets.last)
        s.presetIndex = -3
        XCTAssertEqual(s.text, presets.first)
    }

    func testNothingSellableFallsBackToOneProduct() {
        var s = Settings()
        s.products = []
        XCTAssertEqual(s.sellable.count, 1)
        s.products = [Product(name: " ", priceCents: 500)]
        XCTAssertEqual(s.sellable.first?.shownName, "Item")
    }

    func testSetupsRoundTrip() throws {
        var s = Settings()
        s.store = "Drop Day"
        let setup = Setup(name: "Drop day", settings: s)
        XCTAssertEqual(try JSONDecoder().decode(Setup.self, from: JSONEncoder().encode(setup)), setup)
    }
}
