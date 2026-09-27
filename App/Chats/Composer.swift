import SwiftUI
import JynxKit

struct Composer: View {
    let send: (String) async throws -> Void
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var empty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            if let error { Text(error).font(.open(12.5)).foregroundStyle(Theme.down) }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $text, axis: .vertical).lineLimit(1...6).font(.open(16)).focused($focused)
                    .padding(.horizontal, 16).padding(.vertical, 9).frame(minHeight: 40)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(focused ? Theme.primary : Theme.border))
                    .onChange(of: text) { if text.count > 1000 { text = String(text.prefix(1000)) } }
                Button { Task { await submit() } } label: {
                    Image(systemName: "paperplane.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(Theme.primary, in: Circle())
                }
                .disabled(busy || empty).opacity(busy || empty ? 0.4 : 1)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.bg).overlay(alignment: .top) { Divider() }
    }

    private func submit() async {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true; error = nil
        do { try await send(body); text = "" } catch { self.error = Copy.error(error) }
        busy = false
    }
}
