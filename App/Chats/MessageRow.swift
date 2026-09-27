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
        if mine && message.kind != .signal && message.kind != .signalUpdate {
            bubble
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 48).padding(.vertical, 4)
        } else {
            stop
        }
    }

    // MARK: A stop on the line

    private var stop: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(dotColor).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Theme.bg, lineWidth: 2))
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                meta
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 10)
        .background(alignment: .topLeading) {
            Rectangle().fill(Theme.borderSoft).frame(width: 2)
                .padding(.leading, 5).padding(.top, 18).padding(.bottom, -12)
        }
        .accessibilityElement(children: .combine)
    }

    private var tone: Look.Tone { message.kind == .signalUpdate ? Look.updateTone(message.body) : .neutral }

    private var dotColor: Color {
        switch message.kind {
        case .signalUpdate, .signal: Theme.primary
        default: message.author?.staff ?? true ? Theme.primary : Theme.muted
        }
    }

    @ViewBuilder private var meta: some View {
        let time = Text(" · \(Format.clock(message.createdAt))").foregroundColor(Theme.muted)
        switch message.kind {
        case .signalUpdate:
            (Text(message.body).fontWeight(.bold).foregroundColor(tone == .gain ? Theme.up : tone == .loss ? Theme.down : Theme.fg) + time)
                .font(.open(13.5))
        case .signal:
            (Text("Signal").fontWeight(.bold).foregroundColor(Theme.fg) + time).font(.open(13.5))
        default:
            HStack(spacing: 5) {
                Text(message.author?.displayName ?? "Jynx").font(.open(13.5, .bold)).foregroundStyle(Theme.fg)
                if message.author?.staff ?? true {
                    Text("Team").font(.open(11, .bold)).foregroundStyle(Theme.primary)
                        .padding(.horizontal, 5).padding(.vertical, 1).background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 5))
                }
                Text(Format.clock(message.createdAt)).font(.open(12.5)).foregroundStyle(Theme.muted)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch message.kind {
        case .signalUpdate: EmptyView()
        case .signal:
            SignalCardView(signal: signal, chartURL: message.signalId.map { api.base.appending(path: "api/signals/\($0)/chart") })
        case .other:
            Text("Update the app to see this message.").font(.open(14)).foregroundStyle(Theme.muted)
        default:
            if message.kind == .image || message.hasMedia { picture }
            if !message.body.isEmpty {
                Text(message.body).font(.open(15)).foregroundStyle(Theme.fg).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var picture: some View {
        let url = api.mediaURL(messageId: message.id)
        return AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { Theme.raised }
            .frame(width: 240, height: 200).clipped().clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle()).onTapGesture { open(url) }
            .accessibilityLabel("Picture").accessibilityAddTraits(.isButton)
    }

    // MARK: The member's own message

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
