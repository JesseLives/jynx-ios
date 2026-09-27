import SwiftUI
import JynxKit

struct Composer: View {
    let send: (String) async throws -> Void
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 4) {
            if let error { Text(error).font(.open(13)).foregroundStyle(Theme.down) }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $text, axis: .vertical).lineLimit(1...5).font(.open(16))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20))
                    .onChange(of: text) { if text.count > 1000 { text = String(text.prefix(1000)) } }
                Button { Task { await submit() } } label: {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(Theme.primary, in: Circle())
                }.disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(.horizontal, 12).padding(.vertical, 8).background(Theme.bg)
    }

    private func submit() async {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true; error = nil
        do { try await send(body); text = "" } catch { self.error = Copy.error(error) }
        busy = false
    }
}
