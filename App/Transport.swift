import Foundation
import JynxKit

struct URLSessionTransport: Transport {
    let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpCookieStorage = .shared; c.httpShouldSetCookies = true; c.timeoutIntervalForRequest = 20
        return URLSession(configuration: c)
    }()
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, res) = try await session.data(for: request)
        guard let http = res as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

private struct Bytes: @unchecked Sendable { let bytes: URLSession.AsyncBytes }

func streamLines(base: URL) async throws -> AsyncThrowingStream<String, Error> {
    let c = URLSessionConfiguration.default
    c.timeoutIntervalForRequest = 60   // the server pings every 25 s
    c.timeoutIntervalForResource = .infinity
    var req = URLRequest(url: base.appending(path: "api/stream"))
    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    let (bytes, res) = try await URLSession(configuration: c).bytes(for: req)
    let status = (res as? HTTPURLResponse)?.statusCode ?? 0
    if status == 401 { throw APIError.signedOut }
    guard status == 200 else { throw URLError(.badServerResponse) }
    let source = Bytes(bytes: bytes)
    return AsyncThrowingStream { cont in
        let t = Task {
            do {
                var buf = [UInt8]()
                for try await b in source.bytes {
                    if b == 10 { cont.yield(String(decoding: buf, as: UTF8.self).trimmingCharacters(in: ["\r"])); buf.removeAll() }
                    else { buf.append(b) }
                }
                cont.finish()
            } catch { cont.finish(throwing: error) }
        }
        cont.onTermination = { _ in t.cancel() }
    }
}
