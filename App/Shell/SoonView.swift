import SwiftUI

struct SoonView: View {
    let title: String
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Soon").font(.open(22, .bold)).foregroundStyle(Theme.fg)
                Text("\(title) is on the website for now.").font(.open(15)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        }
    }
}
