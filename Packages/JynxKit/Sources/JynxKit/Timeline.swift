public struct Timeline: Equatable, Sendable {
    public static let pageSize = 50
    public private(set) var messages: [Message] = []
    public private(set) var reachedStart = false
    public init() {}

    public var oldestId: String? { messages.first?.id }
    public var newestId: String? { messages.last?.id }

    public mutating func applyLatest(_ newestFirst: [Message]) {
        let page = newestFirst.sorted { $0.order < $1.order }
        guard let floor = page.first?.order else { messages = []; reachedStart = true; return }
        let full = page.count >= Self.pageSize
        if full, let newest = messages.last?.order, floor > newest {
            messages = page; reachedStart = false; return            // a gap we cannot see into
        }
        messages = messages.filter { $0.order < floor } + page
        if messages.count == page.count { reachedStart = !full }
    }

    public mutating func applyOlder(_ newestFirst: [Message]) {
        let have = Set(messages.map(\.id))
        let older = newestFirst.filter { !have.contains($0.id) }.sorted { $0.order < $1.order }
        messages = older + messages
        if newestFirst.count < Self.pageSize { reachedStart = true }
    }
}
