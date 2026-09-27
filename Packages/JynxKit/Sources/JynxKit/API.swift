import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol Transport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public enum APIError: Error, Equatable, Sendable {
    case signedOut, offline, unreadable
    case server(status: Int, code: String, field: String?, message: String?)
}

private struct ErrorBody: Decodable { let error: String; let field: String?; let message: String? }
private struct Nothing: Decodable {}

public struct API: Sendable {
    public let base: URL
    let transport: Transport
    public init(base: URL, transport: Transport) { self.base = base; self.transport = transport }

    public func me() async throws -> Me { try await call("GET", "/api/me") }
    public func signIn(login: String, password: String) async throws {
        let _: Nothing = try await call("POST", "/api/auth/login", ["login": login, "password": password])
    }
    public func signUp(username: String, email: String, password: String, confirm: String) async throws {
        let _: Nothing = try await call("POST", "/api/auth/signup",
                                        ["username": username, "email": email, "password": password, "confirm": confirm])
    }
    public func signOut() async throws { let _: Nothing = try await call("POST", "/api/auth/logout", [:]) }
    public func rooms() async throws -> [Room] { (try await call("GET", "/api/rooms") as RoomsBody).rooms }
    public func messages(room: String, before: String? = nil) async throws -> MessagesPage {
        try await call("GET", "/api/rooms/\(room)/messages", query: before.map { ["before": $0] } ?? [:])
    }
    public func send(room: String, body: String) async throws {
        let _: Nothing = try await call("POST", "/api/rooms/\(room)/messages", ["body": body])
    }
    public func markRead(room: String, messageId: String) async throws {
        let _: Nothing = try await call("POST", "/api/rooms/\(room)/read", ["messageId": messageId])
    }
    public func signal(id: String) async throws -> Signal { (try await call("GET", "/api/signals/\(id)") as SignalBody).signal }
    public func mediaURL(messageId: String) -> URL { base.appending(path: "api/media/\(messageId)") }

    func request(_ method: String, _ path: String, _ body: [String: String]? = nil, query: [String: String] = [:]) -> URLRequest {
        var c = URLComponents(url: base.appending(path: String(path.dropFirst())), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var r = URLRequest(url: c.url!)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONEncoder().encode(body)
        }
        return r
    }

    func call<T: Decodable>(_ method: String, _ path: String, _ body: [String: String]? = nil,
                            query: [String: String] = [:]) async throws -> T {
        let data: Data, res: HTTPURLResponse
        do { (data, res) = try await transport.send(request(method, path, body, query: query)) }
        catch is URLError { throw APIError.offline }
        if (200..<300).contains(res.statusCode) {
            do { return try JSON.decoder().decode(T.self, from: data) } catch { throw APIError.unreadable }
        }
        let e = try? JSON.decoder().decode(ErrorBody.self, from: data)
        if res.statusCode == 401 && (e == nil || e?.error == "signed_out") { throw APIError.signedOut }
        throw APIError.server(status: res.statusCode, code: e?.error ?? "http_\(res.statusCode)", field: e?.field, message: e?.message)
    }
}
