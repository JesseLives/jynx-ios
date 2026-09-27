import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import JynxKit

final class StubTransport: Transport, @unchecked Sendable {
    var status = 200, body = Data("{\"ok\":true}".utf8), fails: URLError? = nil
    private(set) var seen: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        seen.append(request)
        if let fails { throw fails }
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}
func api(_ t: StubTransport) -> API { API(base: URL(string: "https://signals.justsal.xyz")!, transport: t) }

@Test func signedOutIsItsOwnError() async throws {
    let t = StubTransport(); t.status = 401; t.body = try fixture("error-signed-out")
    await #expect(throws: APIError.signedOut) { try await api(t).me() }
}

@Test func wrongPasswordIsNotSignedOut() async throws {
    let t = StubTransport(); t.status = 401; t.body = try fixture("error-bad-credentials")
    await #expect(throws: APIError.server(status: 401, code: "bad_credentials", field: nil, message: nil)) {
        try await api(t).signIn(login: "x", password: "y")
    }
    #expect(Copy.error(APIError.server(status: 401, code: "bad_credentials", field: nil, message: nil)) == "Wrong username, email or password.")
}

@Test func a401WithoutJSONIsSignedOut() async {
    let t = StubTransport(); t.status = 401; t.body = Data("<html>".utf8)
    await #expect(throws: APIError.signedOut) { try await api(t).rooms() }
}

@Test func signupFieldErrorKeepsTheField() async throws {
    let t = StubTransport(); t.status = 400; t.body = try fixture("error-signup-field")
    do { try await api(t).signUp(username: "a", email: "x@y.z", password: "longenough1", confirm: "longenough1"); Issue.record("no throw") }
    catch let APIError.server(_, code, field, message) { #expect(code == "invalid_username" && field == "username" && message != nil) }
}

@Test func noNetworkIsOffline() async {
    let t = StubTransport(); t.fails = URLError(.notConnectedToInternet)
    await #expect(throws: APIError.offline) { try await api(t).rooms() }
    #expect(Copy.error(APIError.offline) == "Network error. Check your connection and try again.")
}

@Test func requestsAreShapedLikeTheSite() async throws {
    let t = StubTransport()
    try await api(t).send(room: "r1", body: "hello")
    try await api(t).markRead(room: "r1", messageId: "42")
    t.body = try fixture("messages-channel")
    _ = try await api(t).messages(room: "r1", before: "40")
    let (post, read, list) = (t.seen[0], t.seen[1], t.seen[2])
    #expect(post.httpMethod == "POST" && post.url?.path == "/api/rooms/r1/messages")
    #expect(post.value(forHTTPHeaderField: "Origin") == nil)
    #expect(try JSONSerialization.jsonObject(with: post.httpBody!) as? [String: String] == ["body": "hello"])
    #expect(try JSONSerialization.jsonObject(with: read.httpBody!) as? [String: String] == ["messageId": "42"])
    #expect(list.url?.absoluteString == "https://signals.justsal.xyz/api/rooms/r1/messages?before=40")
}

@Test func verdictCopy() {
    #expect(Copy.verdict(.ok) == nil)
    #expect(Copy.verdict(.readOnly) == "Only the team posts here.")
    #expect(Copy.verdict(.muted) == "You are muted in this group for now.")
    #expect(Copy.verdict(.banned) == "You are banned from this group.")
    #expect(Copy.verdict(.other) == "You can't post here.")
}

@Test func aCancelledRequestIsCancellationNotOffline() async {
    let t = StubTransport(); t.fails = URLError(.cancelled)
    await #expect(throws: CancellationError.self) { try await api(t).rooms() }
}
