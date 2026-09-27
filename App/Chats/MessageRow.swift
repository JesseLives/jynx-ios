import SwiftUI
import JynxKit

struct MessageRow: View {
    let message: Message
    let roomVersion: Int
    let mediaURL: URL
    let open: (URL) -> Void

    var body: some View {
        switch message.kind {
        case .signalUpdate:
            Text(message.body).font(.open(13, .semibold)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 2)
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.author?.displayName ?? "Jynx").font(.open(13, .bold)).foregroundStyle(Theme.fg)
                    if message.author?.staff ?? true { Text("Team").font(.open(11, .bold)).foregroundStyle(Theme.primary) }
                    Text(Format.chatTime(message.createdAt)).font(.open(12)).foregroundStyle(Theme.muted)
                }
                content
            }
        }
    }

    @ViewBuilder private var content: some View {
        if message.kind == .signal, let id = message.signalId {
            SignalCardView(id: id, version: roomVersion)
        } else if message.kind == .image || message.hasMedia {
            AsyncImage(url: mediaURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                case .failure: Text("Image unavailable.").font(.open(14)).foregroundStyle(Theme.muted)
                default: Theme.card.frame(height: 180)
                }
            }
            .frame(maxWidth: 280, alignment: .leading).clipShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture { open(mediaURL) }
            if !message.body.isEmpty { bubble }
        } else if message.kind == .other {
            Text("Update the app to see this message.").font(.open(14)).foregroundStyle(Theme.muted)
        } else { bubble }
    }

    private var bubble: some View {
        Text(message.body).font(.open(15)).foregroundStyle(Theme.fg).textSelection(.enabled)
            .padding(.horizontal, 12).padding(.vertical, 8).background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}
