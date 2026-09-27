import Foundation
import Testing
@testable import JynxKit

@Test func parsesRoomEventsAndSkipsPings() {
    var p = SSEParser(); var got: [SSEEvent] = []
    for line in [": ping", "", "event: room", "data: abc", "", "data:no-space", ""] { if let e = p.feed(line) { got.append(e) } }
    #expect(got == [SSEEvent(event: "room", data: "abc"), SSEEvent(event: "message", data: "no-space")])
}

actor Script {
    var connections: [[String]?]; var errors: [Error]
    init(_ c: [[String]?], errors: [Error] = []) { connections = c; self.errors = errors }
    func next() throws -> [String] {
        guard !connections.isEmpty else { throw CancellationError() }
        guard let lines = connections.removeFirst() else { throw errors.removeFirst() }
        return lines
    }
}
actor Sleeps { var all: [Duration] = []; func add(_ d: Duration) { all.append(d) } }
func stream(_ s: Script, slept: Sleeps? = nil) -> LiveStream {
    LiveStream(connect: {
        let lines = try await s.next()
        return AsyncThrowingStream { c in for l in lines { c.yield(l) }; c.finish() }
    }, sleep: { d in await slept?.add(d) })
}

@Test func roomEventsThenCatchUpAfterReconnect() async {
    let s = Script([["event: room", "data: r1", ""], ["event: room", "data: *", ""]])
    var got: [LiveEvent] = []
    for await e in stream(s).events() { got.append(e); if got.count == 6 { break } }
    #expect(got == [.connected, .room("r1"), .disconnected, .connected, .everything, .everything])
}

@Test func signedOutStopsTheStream() async {
    let s = Script([nil], errors: [APIError.signedOut])
    var got: [LiveEvent] = []
    for await e in stream(s).events() { got.append(e) }
    #expect(got == [.signedOut])
}

@Test func backsOffWhileTheServerIsDown() async {
    let sleeps = Sleeps()
    let s = Script([nil, nil, nil, nil, nil, nil, ["event: room", "data: r", ""]],
                   errors: Array(repeating: APIError.offline, count: 6))
    for await e in stream(s, slept: sleeps).events() { if e == .room("r") { break } }
    #expect(Array(await sleeps.all.prefix(6)) == [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(15), .seconds(15)])
}

@Test func pausesAfterACleanDisconnect() async {
    let sleeps = Sleeps()
    let s = Script([["event: room", "data: a", ""], ["event: room", "data: b", ""]])
    for await e in stream(s, slept: sleeps).events() { if e == .room("b") { break } }
    #expect(await sleeps.all.first == .seconds(1))
}
