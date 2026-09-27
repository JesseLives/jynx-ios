import Foundation
import Testing
@testable import JynxKit

func msg(_ id: Int) -> Message {
    Message(id: String(id), roomId: "r", kind: .text, body: "m\(id)", hasMedia: false, signalId: nil, author: nil,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)))
}
func page(_ ids: ClosedRange<Int>) -> [Message] { ids.reversed().map(msg) }   // the server sends newest first

@Test func latestThenOlderIsOneOrderedList() {
    var t = Timeline()
    t.applyLatest(page(51...100))
    t.applyOlder(page(1...50))
    #expect(t.messages.map(\.order) == Array(1...100).map(Int64.init))
    #expect(!t.reachedStart)
    t.applyOlder([])
    #expect(t.reachedStart)
}

@Test func idsSortAsNumbersNotText() {
    var t = Timeline(); t.applyLatest([msg(10), msg(9)])
    #expect(t.messages.map(\.id) == ["9", "10"])
}

@Test func latestReplacesTheRangeItCovers() {
    var t = Timeline(); t.applyLatest(page(1...5))
    t.applyLatest([msg(6), msg(5), msg(3), msg(2), msg(1)])   // 4 was deleted, 6 is new
    #expect(t.messages.map(\.order) == [1, 2, 3, 5, 6])
}

@Test func aFullPageBeyondWhatWeHoldResets() {
    var t = Timeline(); t.applyLatest(page(1...10))
    t.applyLatest(page(200...249))
    #expect(t.messages.first?.order == 200 && t.messages.count == 50 && !t.reachedStart)
}

@Test func aShortFirstPageMeansTheStart() {
    var t = Timeline(); t.applyLatest(page(1...3))
    #expect(t.reachedStart)
}
