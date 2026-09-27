import Foundation
import JynxKit
import Observation

@Observable @MainActor
final class PriceFeed {
    static let symbol = "XAUUSD"
    private(set) var last: PriceTick?
    private(set) var connected = true
    private(set) var reconnects = 0
    private var task: Task<Void, Never>?

    func start(session: Session) {
        guard task == nil else { return }
        let base = session.api.base
        let stream = LiveStream(connect: { try await streamLines(base: base, path: "api/chart/stream") })
        task = Task { [weak self] in
            for await e in stream.events() {
                guard let self else { return }
                switch e {
                case .connected: connected = true
                case .disconnected: connected = false
                case .everything: reconnects += 1
                case .message(let m):
                    if let tick = PriceTick(event: m), tick.isNewer(than: last) { last = tick }
                case .signedOut: session.handle(APIError.signedOut)
                case .room: break
                }
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
}
