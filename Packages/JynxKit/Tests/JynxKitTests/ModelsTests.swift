import Foundation
import Testing
@testable import JynxKit

@Test func decodesMe() throws {
    let me = try JSON.decoder().decode(Me.self, from: fixture("me"))
    #expect(me.user.role == .member)
    #expect(me.subscriptions.count == 1)
    #expect(me.wallet.balance == 0)
}

@Test func decodesRoomsWithLockedAndUnread() throws {
    let rooms = try JSON.decoder().decode(RoomsBody.self, from: fixture("rooms")).rooms
    #expect(rooms.contains { $0.locked && $0.last == nil })
    #expect(rooms.contains { !$0.locked && $0.unread > 0 && $0.last != nil })
    #expect(rooms.contains { $0.kind == .group })
}

@Test func decodesEveryMessageKind() throws {
    let channel = try JSON.decoder().decode(MessagesPage.self, from: fixture("messages-channel"))
    #expect(channel.canPost == .readOnly)
    #expect(Set(channel.messages.map(\.kind)) == [.text, .signal, .signalUpdate])
    #expect(channel.messages.first { $0.kind == .signal }?.signalId != nil)
    let group = try JSON.decoder().decode(MessagesPage.self, from: fixture("messages-group"))
    #expect(group.canPost == .ok)
    #expect(group.messages.contains { $0.kind == .image && $0.hasMedia })
    #expect(group.messages.contains { $0.author?.staff == false })
}

@Test func decodesSignals() throws {
    let run = try JSON.decoder().decode(SignalBody.self, from: fixture("signal-running")).signal
    #expect(run.status == .running && run.side == .buy && run.tpHits == [1] && run.tps == ["2365", "2380"])
    #expect(run.updates.contains { $0.kind == "tp_hit" && $0.tp == 1 })
    let done = try JSON.decoder().decode(SignalBody.self, from: fixture("signal-closed")).signal
    #expect(done.status == .closed && done.resultPips != nil && done.closedAt != nil)
}

@Test func unknownKindsAndVerdictsStillDecode() throws {
    let json = """
    {"ok":true,"canPost":"slow_mode","messages":[{"id":"9","roomId":"r","kind":"poll","body":"?","hasMedia":false,
    "signalId":null,"author":null,"createdAt":"2026-09-27T03:07:17.123Z"}]}
    """
    let page = try JSON.decoder().decode(MessagesPage.self, from: Data(json.utf8))
    #expect(page.canPost == .other)
    #expect(page.messages.first?.kind == .other)
}
