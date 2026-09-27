import Foundation
import JynxKit
import Observation

@Observable @MainActor
final class Live {
    var connected = true
    private(set) var versions: [String: Int] = [:]
    private(set) var everything = 0
    private var task: Task<Void, Never>?

    func version(of room: String) -> Int { versions[room, default: 0] + everything }
    var any: Int { versions.values.reduce(everything, +) }

    func start(session: Session) {
        guard task == nil else { return }
        let base = session.api.base
        let stream = LiveStream(connect: { try await streamLines(base: base) })
        task = Task { [weak self] in
            for await e in stream.events() {
                guard let self else { return }
                switch e {
                case .connected: connected = true
                case .disconnected: connected = false
                case .room(let id): versions[id, default: 0] += 1
                case .everything: everything += 1
                case .signedOut: session.handle(APIError.signedOut)
                }
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
}
