public struct SSEEvent: Equatable, Sendable {
    public let event: String, data: String
    public init(event: String, data: String) { self.event = event; self.data = data }
}

public struct SSEParser: Sendable {
    var event = "", data: [String] = []
    public init() {}
    public mutating func feed(_ line: String) -> SSEEvent? {
        if line.isEmpty {
            defer { event = ""; data = [] }
            return data.isEmpty ? nil : SSEEvent(event: event.isEmpty ? "message" : event, data: data.joined(separator: "\n"))
        }
        if line.hasPrefix(":") { return nil }
        let (field, value) = line.firstIndex(of: ":").map {
            (String(line[..<$0]), String(line[line.index(after: $0)...]).droppingOneSpace)
        } ?? (line, "")
        if field == "event" { event = value } else if field == "data" { data.append(value) }
        return nil
    }
}
private extension String { var droppingOneSpace: String { hasPrefix(" ") ? String(dropFirst()) : self } }
