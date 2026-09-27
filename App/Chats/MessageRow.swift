import SwiftUI
import JynxKit

struct MessageRow: View {
    let message: Message
    let mine: Bool
    let showAuthor: Bool
    let signal: Signal?
    let api: API
    let open: (URL) -> Void

    var body: some View {
        switch message.kind {
        case .signalUpdate:
            Text(message.body).font(.open(12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Theme.mutedBg, in: Capsule()).overlay(Capsule().stroke(Theme.borderSoft))
                .frame(maxWidth: .infinity).padding(.vertical, 2)
        case .signal:
            VStack(alignment: .leading, spacing: 3) {
                SignalCardView(signal: signal, chartURL: message.signalId.map { api.base.appending(path: "api/signals/\($0)/chart") })
                Text(Format.clock(message.createdAt)).font(.open(11.5)).foregroundStyle(Theme.muted).padding(.leading, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                if showAuthor, let name = message.author?.displayName {
                    HStack(spacing: 5) {
                        Text(name).font(.open(11.5, .semibold))
                        if message.author?.staff == true { Text("Team").font(.open(11, .bold)).foregroundStyle(Theme.primary) }
                    }.foregroundStyle(Theme.muted).padding(.horizontal, 6)
                }
                bubble
            }
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
            .padding(mine ? .leading : .trailing, 48)
        }
    }

    private var shape: UnevenRoundedRectangle {
        mine ? UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 6, topTrailingRadius: 18)
             : UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18)
    }

    private var bubble: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if message.kind == .image || message.hasMedia {
                let url = api.mediaURL(messageId: message.id)
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { Theme.raised }
                    .frame(width: 240, height: 200).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle()).onTapGesture { open(url) }
            }
            if message.kind == .other {
                Text("Update the app to see this message.").font(.open(14)).foregroundStyle(Theme.muted)
            } else if !message.body.isEmpty {
                Text(message.body).font(.open(15)).foregroundStyle(mine ? .white : Theme.fg).textSelection(.enabled)
            }
            Text(Format.clock(message.createdAt)).font(.open(11)).monospacedDigit()
                .foregroundStyle(mine ? Color.white.opacity(0.78) : Theme.muted)
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6)
        .background(mine ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.card), in: shape)
        .overlay(shape.stroke(mine ? Color.clear : Theme.borderSoft))
        .frame(maxWidth: 320, alignment: mine ? .trailing : .leading)
    }
}

struct DayChip: View {
    let text: String
    var body: some View {
        Text(text).font(.open(11, .bold)).foregroundStyle(Theme.muted)
            .padding(.horizontal, 12).padding(.vertical, 4).background(Theme.card, in: Capsule())
            .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 4)
    }
}
