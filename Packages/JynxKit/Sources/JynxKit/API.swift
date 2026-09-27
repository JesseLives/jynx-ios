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

public enum JSONValue: Encodable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral {
    case string(String), int(Int), bool(Bool)
    public init(stringLiteral v: String) { self = .string(v) }
    public init(integerLiteral v: Int) { self = .int(v) }
    public init(booleanLiteral v: Bool) { self = .bool(v) }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .string(let v): try c.encode(v); case .int(let v): try c.encode(v); case .bool(let v): try c.encode(v) }
    }
}

private struct ErrorBody: Decodable { let error: String; let field: String?; let message: String? }
private struct EndsAt: Decodable { let endsAt: Date? }
private struct Nothing: Decodable {}

public struct API: Sendable {
    public let base: URL
    let transport: Transport
    public init(base: URL, transport: Transport) { self.base = base; self.transport = transport }

    public func me() async throws -> Me { try await call("GET", "/api/me") }
    public func signIn(login: String, password: String) async throws {
        let _: Nothing = try await call("POST", "/api/auth/login", ["login": .string(login), "password": .string(password)])
    }
    public func signUp(username: String, email: String, password: String, confirm: String) async throws {
        let _: Nothing = try await call("POST", "/api/auth/signup",
                                        ["username": .string(username), "email": .string(email), "password": .string(password), "confirm": .string(confirm)])
    }
    public func signOut() async throws { let _: Nothing = try await call("POST", "/api/auth/logout", [:]) }
    public func rooms() async throws -> [Room] { (try await call("GET", "/api/rooms") as RoomsBody).rooms }
    public func messages(room: String, before: String? = nil) async throws -> MessagesPage {
        try await call("GET", "/api/rooms/\(room)/messages", query: before.map { ["before": $0] } ?? [:])
    }
    public func send(room: String, body: String) async throws {
        let _: Nothing = try await call("POST", "/api/rooms/\(room)/messages", ["body": .string(body)])
    }
    public func markRead(room: String, messageId: String) async throws {
        let _: Nothing = try await call("POST", "/api/rooms/\(room)/read", ["messageId": .string(messageId)])
    }
    public func signal(id: String) async throws -> Signal { (try await call("GET", "/api/signals/\(id)") as SignalBody).signal }
    public func chartConfig() async throws -> ChartConfig { (try await call("GET", "/api/chart") as ChartConfigBody).chart }
    public func candles(_ tf: Timeframe, limit: Int? = nil) async throws -> [Bar] {
        var q = ["tf": tf.rawValue]
        if let limit { q["limit"] = String(limit) }
        return (try await call("GET", "/api/chart/candles", query: q) as CandlesBody).candles
    }
    public func indicator(_ tf: Timeframe) async throws -> Sniper { try await call("GET", "/api/chart/indicator", query: ["tf": tf.rawValue]) }
    public func chartSignals() async throws -> [ChartSignal] { (try await call("GET", "/api/chart/signals") as ChartSignalsBody).signals }
    // MARK: Plans, payments, wallet

    public func plans() async throws -> PlansBody { try await call("GET", "/api/plans") }
    public func payments() async throws -> [PaymentRecord] { (try await call("GET", "/api/payments") as PaymentsBody).payments }
    public func paymentState(_ id: String) async throws -> PaymentState { (try await call("GET", "/api/payments/\(id)") as PaymentStatusBody).payment }
    public func startQR(productId: String, months: Int) async throws -> QRPayment {
        (try await call("POST", "/api/payments/qr", ["kind": "plan", "productId": .string(productId), "months": .int(months)]) as QRPaymentBody).payment
    }
    public func startQR(depositCents: Int) async throws -> QRPayment {
        (try await call("POST", "/api/payments/qr", ["kind": "deposit", "amountCents": .int(depositCents)]) as QRPaymentBody).payment
    }
    public func wallet() async throws -> WalletOverview { (try await call("GET", "/api/wallet") as WalletBody).wallet }
    public func buyWithWallet(productId: String, months: Int) async throws -> Date? {
        (try await call("POST", "/api/wallet", ["action": "buy", "productId": .string(productId), "months": .int(months)]) as EndsAt).endsAt
    }
    public func withdraw(amountCents: Int, method: String, destination: String) async throws {
        let _: Nothing = try await call("POST", "/api/wallet", ["action": "withdraw", "amountCents": .int(amountCents),
                                                                "method": .string(method), "destination": .string(destination)])
    }
    public func setInviteCode(_ code: String) async throws {
        let _: Nothing = try await call("POST", "/api/wallet", ["action": "invite_code", "code": .string(code)])
    }
    public func setAutoRenew(productId: String, on: Bool) async throws {
        let _: Nothing = try await call("POST", "/api/wallet", ["action": "auto_renew", "productId": .string(productId), "on": .bool(on)])
    }

    public func mediaURL(messageId: String) -> URL { base.appending(path: "api/media/\(messageId)") }

    func request(_ method: String, _ path: String, _ body: [String: JSONValue]? = nil, query: [String: String] = [:]) -> URLRequest {
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

    func call<T: Decodable>(_ method: String, _ path: String, _ body: [String: JSONValue]? = nil,
                            query: [String: String] = [:]) async throws -> T {
        let data: Data, res: HTTPURLResponse
        do { (data, res) = try await transport.send(request(method, path, body, query: query)) }
        catch let e as URLError { throw e.code == .cancelled ? CancellationError() : APIError.offline }
        if (200..<300).contains(res.statusCode) {
            do { return try JSON.decoder().decode(T.self, from: data) } catch { throw APIError.unreadable }
        }
        let e = try? JSON.decoder().decode(ErrorBody.self, from: data)
        if res.statusCode == 401 && (e == nil || e?.error == "signed_out") { throw APIError.signedOut }
        throw APIError.server(status: res.statusCode, code: e?.error ?? "http_\(res.statusCode)", field: e?.field, message: e?.message)
    }
}
