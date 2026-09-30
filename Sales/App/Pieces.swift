import SwiftUI

enum Palette {
    static let card = Color(white: 0.11)
    static let field = Color(white: 0.16)
    static let line = Color.white.opacity(0.07)
    static let muted = Color(white: 0.62)
    static let blue = Color(red: 0.36, green: 0.66, blue: 1.0)
    static let start = Color(red: 0.45, green: 0.72, blue: 1.0)
    static let stop = Color(red: 1.0, green: 0.3, blue: 0.33)
    static let green = Color(red: 0.36, green: 0.75, blue: 0.29)
}

struct Card<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased()).font(.system(size: 15, weight: .bold)).kerning(1.2).foregroundStyle(Palette.muted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }
}

struct Segments<T: Hashable>: View {
    let items: [T]
    var columns = 0          // 0: all in one row
    let label: (T) -> String
    var id: (T) -> String = { _ in "" }
    let selected: T
    let pick: (T) -> Void

    var body: some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 4), count: columns == 0 ? items.count : columns)
        LazyVGrid(columns: grid, spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button { pick(item) } label: {
                    Text(label(item))
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(item == selected ? Color(white: 0.3) : .clear))
                        .foregroundStyle(item == selected ? .white : Color(white: 0.75))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(id(item))
                .accessibilityAddTraits(item == selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Palette.field))
    }
}

struct Choice: View {
    let title: String
    let note: String
    let on: Bool
    let pick: () -> Void
    var body: some View {
        Button(action: pick) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 18, weight: .semibold))
                    Text(note).font(.system(size: 15)).foregroundStyle(Palette.muted)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                if on { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.white, Palette.blue) }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct Field: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var body: some View {
        HStack {
            Text(label).foregroundStyle(Palette.muted)
            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 17, weight: .semibold))
                .submitLabel(.done)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.field))
    }
}

struct WholeNumberRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var focus: FocusState<Bool>.Binding
    var id = ""
    @State private var text = ""

    var body: some View {
        HStack {
            Text(label).font(.system(size: 18)).foregroundStyle(Palette.muted)
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 22, weight: .bold))
                .focused(focus)
                .accessibilityIdentifier(id)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.field))
        .onAppear { text = String(value) }
        .onChange(of: text) { _, typed in
            let digits = String(typed.filter { ("0"..."9").contains($0) }.prefix(6))
            if digits != typed { text = digits; return }
            if let n = Int(digits) { value = min(range.upperBound, max(range.lowerBound, n)) }
        }
        .onChange(of: focus.wrappedValue) { _, on in if !on { text = String(value) } }
        .onChange(of: value) { _, v in if !focus.wrappedValue { text = String(v) } }   // a loaded setup
    }
}

struct PriceField: View {
    @Binding var cents: Int
    var focus: FocusState<Bool>.Binding
    @State private var text = ""

    var body: some View {
        HStack(spacing: 2) {
            Text("$").foregroundStyle(Palette.muted)
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 90)
                .focused(focus)
                .accessibilityIdentifier("productPrice")
        }
        .onAppear { text = shown(cents) }
        .onChange(of: text) { _, typed in
            let clean = typed.replacingOccurrences(of: ",", with: ".").filter { ("0"..."9").contains($0) || $0 == "." }
            if clean != typed { text = clean; return }
            if let d = Double(clean), d.isFinite { cents = min(10_000_000, max(0, Int((d * 100).rounded()))) }
            else if clean.isEmpty { cents = 0 }
        }
        .onChange(of: focus.wrappedValue) { _, on in if !on { text = shown(cents) } }
        .onChange(of: cents) { _, c in if !focus.wrappedValue { text = shown(c) } }
    }

    private func shown(_ c: Int) -> String { String(format: "%.2f", Double(c) / 100) }
}

struct BigButton: View {
    let title: String
    let color: Color
    var id = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Capsule().fill(color))
                .foregroundStyle(.white)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
