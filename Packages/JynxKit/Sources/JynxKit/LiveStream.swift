public enum LiveEvent: Equatable, Sendable { case connected, disconnected, room(String), everything, signedOut }

public struct LiveStream: Sendable {
    let connect: @Sendable () async throws -> AsyncThrowingStream<String, Error>
    let sleep: @Sendable (Duration) async throws -> Void
    public init(connect: @escaping @Sendable () async throws -> AsyncThrowingStream<String, Error>,
                sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.connect = connect; self.sleep = sleep
    }

    public func events() -> AsyncStream<LiveEvent> {
        let (connect, sleep) = (connect, sleep)
        return AsyncStream { out in
            let task = Task {
                var failures = 0, first = true, failedBefore = false
                while !Task.isCancelled {
                    do {
                        let lines = try await connect()
                        failures = 0
                        out.yield(.connected)
                        if !first || failedBefore { out.yield(.everything) }
                        first = false; failedBefore = false
                        var parser = SSEParser()
                        for try await line in lines {
                            guard let e = parser.feed(line), e.event == "room" else { continue }
                            out.yield(e.data == "*" ? .everything : .room(e.data))
                        }
                        out.yield(.disconnected)
                        try await sleep(.seconds(1))
                    } catch APIError.signedOut {
                        out.yield(.signedOut); break
                    } catch is CancellationError {
                        break
                    } catch {
                        out.yield(.disconnected)
                        failures += 1; failedBefore = true
                        do { try await sleep(.seconds([1, 2, 4, 8, 15][min(failures - 1, 4)])) } catch { break }
                    }
                }
                out.finish()
            }
            out.onTermination = { _ in task.cancel() }
        }
    }
}
