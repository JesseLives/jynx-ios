import SwiftUI
import JynxKit

enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
    var label: String { rawValue.capitalized }
}

enum Theme {
    static let fg = pair(0x0f1419, 0xe7e9ea), muted = pair(0x536471, 0x72767a)
    static let card = pair(0xf7f8f8, 0x17181c), raised = pair(0xf7f9fa, 0x22303c)
    static let border = pair(0xe1eaef, 0x242628), bg = pair(0xffffff, 0x000000)
    static let primary = pair(0x1e9df1, 0x1c9cf0), up = pair(0x00a36d, 0x00b87a)
    static let down = pair(0xe0245e, 0xf4212e), wait = pair(0xb7791f, 0xf7b928)
    static let borderSoft = pair(0xe8eef2, 0x1d1f22), mutedBg = pair(0xeef1f3, 0x181818)
    static let primarySoft = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 28 / 255, green: 156 / 255, blue: 240 / 255, alpha: 0.15)
        : UIColor(red: 30 / 255, green: 157 / 255, blue: 241 / 255, alpha: 0.12) })
    static var gain: LinearGradient { LinearGradient(colors: [Color(hex: 0x0fae6e), Color(hex: 0x16c784)], startPoint: .leading, endPoint: .trailing) }

    static var tones: [(LinearGradient, Color)] { [
        (grad(0xf5c542, 0xc98b12), Color(hex: 0x221800)), (grad(0x8b6cff, 0x5b3fd9), .white), (grad(0x2dd4bf, 0x0f9488), .white),
        (grad(0x38bdf8, 0x1e7fd6), .white), (grad(0xfb7185, 0xd9364f), .white), (grad(0xfb923c, 0xd9620f), .white),
    ] }
    private static func grad(_ a: UInt32, _ b: UInt32) -> LinearGradient {
        LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func pair(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) })
    }
    private static func rgb(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

extension Font {
    static func open(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Open Sans", size: size).weight(weight)
    }
}

extension Color {
    init(hex v: UInt32) { self.init(red: Double(v >> 16 & 0xff) / 255, green: Double(v >> 8 & 0xff) / 255, blue: Double(v & 0xff) / 255) }
}

struct RoomAvatar: View {
    let name: String
    var small = false
    var body: some View {
        let (fill, ink) = Theme.tones[Look.tone(name)]
        let side: CGFloat = small ? 38 : 50
        RoundedRectangle(cornerRadius: small ? 12 : 16).fill(fill).frame(width: side, height: side)
            .overlay(Text(Look.initials(name)).font(.open(small ? 12 : 14, .heavy)).foregroundStyle(ink))
    }
}

struct VipBadge: View {
    var body: some View {
        Text("VIP").font(.open(9.5, .heavy)).tracking(0.3).foregroundStyle(Theme.primary)
            .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct CardGroup<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.borderSoft))
    }
}

struct IconTile: View {
    let symbol: String
    var body: some View {
        RoundedRectangle(cornerRadius: 12).fill(Theme.primarySoft).frame(width: 40, height: 40)
            .overlay(Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.primary))
    }
}
