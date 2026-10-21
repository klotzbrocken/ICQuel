import SwiftUI
import AppKit

// Mac OS 8/9 ("platinum") and Mac OS X Aqua variants of the classic layout: surfaces, bevels, buttons, check boxes, window chrome.

// MARK: bevels
extension Bevel {
    /// Mac OS 8/9: black outline, white highlight top-left, grey shade bottom-right.
    var platinum: some View {
        Canvas { c, s in
            func line(_ a: CGPoint, _ b: CGPoint, _ col: Color) { var p = Path(); p.move(to: a); p.addLine(to: b); c.stroke(p, with: .color(col), lineWidth: 1) }
            let w = s.width, h = s.height
            if raised {
                let r = win ? 0 : 3.0
                c.stroke(Path(roundedRect: CGRect(x: 0.5, y: 0.5, width: w - 1, height: h - 1), cornerRadius: r), with: .color(.black), lineWidth: 1)
                line(.init(x: 1.5 + r / 2, y: 1.5), .init(x: w - 2 - r / 2, y: 1.5), .white); line(.init(x: 1.5, y: 1.5 + r / 2), .init(x: 1.5, y: h - 2 - r / 2), .white)
                line(.init(x: 2 + r / 2, y: h - 1.5), .init(x: w - 1.5, y: h - 1.5), Color(white: 0.55)); line(.init(x: w - 1.5, y: 2 + r / 2), .init(x: w - 1.5, y: h - 1.5), Color(white: 0.55))
            } else {
                c.stroke(Path(CGRect(x: 0.5, y: 0.5, width: w - 1, height: h - 1)), with: .color(Color(white: 0.35)), lineWidth: 1)
                line(.init(x: 1, y: 1.5), .init(x: w - 1, y: 1.5), Color(white: 0.7)); line(.init(x: 1.5, y: 1), .init(x: 1.5, y: h - 1), Color(white: 0.7))
                line(.init(x: 1, y: h - 0.5), .init(x: w, y: h - 0.5), .white)
            }
        }.allowsHitTesting(false)
    }
    /// Aqua: gel buttons (pill shaped when small), rounded panels and fields.
    var aqua: some View {
        Canvas { c, s in
            let w = s.width, h = s.height
            let rect = CGRect(x: 0.5, y: 0.5, width: w - 1, height: h - 1)
            if win {
                c.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(Color(white: 0.42)), lineWidth: 1); return
            }
            if raised {
                let big = h > 40, r = big ? 5.0 : min(h / 2, 12)
                let path = Path(roundedRect: rect, cornerRadius: r)
                if !big {
                    c.fill(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: max(1, r - 1)), with: .linearGradient(Gradient(stops: [
                        .init(color: Color.white.opacity(0.95), location: 0), .init(color: Color.white.opacity(0.45), location: 0.5), .init(color: Color.black.opacity(0.07), location: 0.52), .init(color: Color.white.opacity(0.45), location: 1)]),
                        startPoint: .init(x: 0, y: 0), endPoint: .init(x: 0, y: h)))
                }
                c.stroke(path, with: .color(Color(white: big ? 0.62 : 0.50)), lineWidth: 1)
            } else {
                c.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color(white: 0.55)), lineWidth: 1)
                var p = Path(); p.move(to: .init(x: 2, y: 1.5)); p.addLine(to: .init(x: w - 2, y: 1.5)); c.stroke(p, with: .color(Color.black.opacity(0.18)), lineWidth: 1)
            }
        }.allowsHitTesting(false)
    }
}

// MARK: buttons
/// Background of a push button for the active skin (plus its pressed / default look).
struct ButtonBG: View {
    var pressed: Bool; var isDefault = false
    var body: some View {
        switch Theme.skin {
        case .win98:
            Color.gray98.overlay(Bevel(raised: !pressed)).overlay(isDefault ? Rectangle().stroke(Color.black, lineWidth: 1).padding(-1) : nil)
        case .platinum:
            ZStack { RoundedRectangle(cornerRadius: 3).fill(pressed ? Color(white: 0.62) : Color.gray98); Bevel(raised: !pressed) }
                .overlay(isDefault ? RoundedRectangle(cornerRadius: 4).strokeBorder(Color.black, lineWidth: 2.5) : nil)   // default ring stays inside the button so neighbours are not overlapped
        case .aqua:
            if isDefault {
                Canvas { c, s in
                    let r = min(s.height / 2, 12), rect = CGRect(origin: .zero, size: s).insetBy(dx: 0.5, dy: 0.5)
                    c.fill(Path(roundedRect: rect, cornerRadius: r), with: .linearGradient(Gradient(stops: [
                        .init(color: Color(red: 0.55, green: 0.76, blue: 1.0), location: 0), .init(color: Color(red: 0.25, green: 0.52, blue: 0.95), location: 0.5),
                        .init(color: Color(red: 0.12, green: 0.40, blue: 0.88), location: 0.52), .init(color: Color(red: 0.36, green: 0.65, blue: 1.0), location: 1)]),
                        startPoint: .zero, endPoint: .init(x: 0, y: s.height)))
                    c.stroke(Path(roundedRect: rect, cornerRadius: r), with: .color(Color(red: 0.12, green: 0.3, blue: 0.7)), lineWidth: 1)
                    if pressed { c.fill(Path(roundedRect: rect, cornerRadius: r), with: .color(.black.opacity(0.15))) }
                }
            } else {
                ZStack { Color.gray98; Bevel(raised: true); if pressed { Capsule().fill(Color.black.opacity(0.14)).padding(1) } }
            }
        }
    }
    static var pressShift: Bool { Theme.skin == .win98 }
    static func text(_ isDefault: Bool, enabled: Bool) -> Color { !enabled ? .shade : (Theme.skin == .aqua && isDefault ? .white : .black) }
}

// MARK: check boxes / radio buttons
struct SkinCheck: View {
    let on: Bool
    var body: some View {
        switch Theme.skin {
        case .win98: ZStack { Color.white.frame(width: 13, height: 13).overlay(Bevel(raised: false)); if on { Text("✓").font(rf(10, bold: true)).foregroundColor(.black) } }
        case .platinum:
            ZStack { Color.white.frame(width: 12, height: 12).overlay(Bevel(raised: false))
                if on { Canvas { c, s in var p = Path(); p.move(to: .init(x: 3, y: 3)); p.addLine(to: .init(x: 9, y: 9)); p.move(to: .init(x: 9, y: 3)); p.addLine(to: .init(x: 3, y: 9)); c.stroke(p, with: .color(.black), lineWidth: 1.5) }.frame(width: 12, height: 12) } }
        case .aqua:
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: on ? [Color(red: 0.45, green: 0.70, blue: 1.0), Color(red: 0.15, green: 0.45, blue: 0.92)] : [.white, Color(white: 0.84)], startPoint: .top, endPoint: .bottom)).frame(width: 14, height: 14)
                RoundedRectangle(cornerRadius: 3).stroke(on ? Color(red: 0.12, green: 0.3, blue: 0.7) : Color(white: 0.5), lineWidth: 1).frame(width: 14, height: 14)
                if on { Canvas { c, s in var p = Path(); p.move(to: .init(x: 3.5, y: 7.5)); p.addLine(to: .init(x: 6, y: 10)); p.addLine(to: .init(x: 10.5, y: 4)); c.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)) }.frame(width: 14, height: 14) }
            }
        }
    }
}
struct SkinRadio: View {
    let on: Bool
    var body: some View {
        switch Theme.skin {
        case .win98: ZStack { Circle().fill(Color.white).frame(width: 12, height: 12).overlay(Circle().stroke(Color.shade, lineWidth: 1)); if on { Circle().fill(Color.black).frame(width: 4, height: 4) } }
        case .platinum: ZStack { Circle().fill(Color.white).frame(width: 12, height: 12).overlay(Circle().stroke(Color.black, lineWidth: 1)); if on { Circle().fill(Color.black).frame(width: 6, height: 6) } }
        case .aqua:
            ZStack {
                Circle().fill(LinearGradient(colors: on ? [Color(red: 0.45, green: 0.70, blue: 1.0), Color(red: 0.15, green: 0.45, blue: 0.92)] : [.white, Color(white: 0.84)], startPoint: .top, endPoint: .bottom)).frame(width: 14, height: 14)
                Circle().stroke(on ? Color(red: 0.12, green: 0.3, blue: 0.7) : Color(white: 0.5), lineWidth: 1).frame(width: 14, height: 14)
                if on { Circle().fill(Color.white).frame(width: 5, height: 5) }
            }
        }
    }
}

// MARK: window chrome (title bars)
struct PlatinumTitleBar: View {
    @ObservedObject var info: WinInfo; let close: () -> Void; let mini: () -> Void
    var body: some View {
        let sm = info.small, th: CGFloat = sm ? 15 : 18
        ZStack {
            Color.gray98
            if info.key { VStack(spacing: 1) { ForEach(0..<(sm ? 6 : 7), id: \.self) { _ in Color(white: 0.45).frame(height: 1) } }.padding(.horizontal, 3) }
            HStack(spacing: 0) {
                box(close).padding(.leading, 3)
                Spacer(minLength: 0)
                box(mini, inner: true).padding(.trailing, 3)
            }
            Text(info.title).font(rf(11, bold: true)).foregroundColor(info.key ? .black : Color(white: 0.45)).lineLimit(1).padding(.horizontal, 5).background(Color.gray98).padding(.horizontal, 24)
        }.frame(height: th).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }
    func box(_ action: @escaping () -> Void, inner: Bool = false) -> some View {
        Button(action: action) { ZStack { Color.gray98.frame(width: 11, height: 11).overlay(Bevel(raised: false)); if inner { Rectangle().stroke(Color.black, lineWidth: 1).frame(width: 5, height: 5) } } }.buttonStyle(.plain)
    }
}
struct AquaTitleBar: View {
    @ObservedObject var info: WinInfo; let close: () -> Void; let mini: () -> Void; let zoom: () -> Void
    @State private var hover = false
    var body: some View {
        let sm = info.small, th: CGFloat = sm ? 15 : 18, d: CGFloat = sm ? 10 : 12
        ZStack {
            LinearGradient(colors: info.key ? [Color(white: 0.93), Color(white: 0.74)] : [Color(white: 0.95), Color(white: 0.87)], startPoint: .top, endPoint: .bottom)
            Text(info.title).font(rf(11, bold: true)).foregroundColor(info.key ? Color(white: 0.15) : Color(white: 0.55)).lineLimit(1).padding(.horizontal, 54)
            HStack(spacing: 6) {
                light(Color(red: 0.99, green: 0.37, blue: 0.34), "xmark", close, d); light(Color(red: 1.0, green: 0.74, blue: 0.18), "minus", mini, d); light(Color(red: 0.16, green: 0.78, blue: 0.25), "plus", zoom, d)
                Spacer(minLength: 0)
            }.padding(.leading, 6).onHover { hover = $0 }
        }.frame(height: th).overlay(Rectangle().fill(Color(white: 0.45)).frame(height: 1), alignment: .bottom)
    }
    func light(_ col: Color, _ sym: String, _ action: @escaping () -> Void, _ d: CGFloat) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(info.key ? LinearGradient(colors: [col.opacity(0.65), col], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color(white: 0.86), Color(white: 0.78)], startPoint: .top, endPoint: .bottom))
                Circle().stroke(info.key ? Color.black.opacity(0.35) : Color(white: 0.6), lineWidth: 0.7)
                Ellipse().fill(Color.white.opacity(0.55)).frame(width: d * 0.6, height: d * 0.32).offset(y: -d * 0.22)
                if hover && info.key { Image(systemName: sym).font(.system(size: d * 0.55, weight: .heavy)).foregroundColor(Color.black.opacity(0.55)) }
            }.frame(width: d, height: d)
        }.buttonStyle(.plain)
    }
}

/// Look of one tab cell of WTabs (the Win98 look is the original one).
struct TabLook: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        switch Theme.skin {
        case .win98:
            content.background(Color.gray98)
                .overlay(Rectangle().fill(Color.white).frame(height: 1), alignment: .top)
                .overlay(Rectangle().fill(Color.white).frame(width: 1), alignment: .leading)
                .overlay(Rectangle().fill(Color.black).frame(width: 1), alignment: .trailing)
                .overlay(Rectangle().fill(Color.shade).frame(width: 1).padding(.trailing, 1), alignment: .trailing)
        case .platinum:
            content.background(on ? Color.white : Color(white: 0.78)).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        case .aqua:
            content.foregroundColor(on ? .white : .black)
                .background(RoundedRectangle(cornerRadius: 9).fill(LinearGradient(colors: on ? [Color(red: 0.5, green: 0.74, blue: 1.0), Color(red: 0.15, green: 0.45, blue: 0.92)] : [.white, Color(white: 0.82)], startPoint: .top, endPoint: .bottom)).padding(.vertical, 1).padding(.horizontal, 1))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(on ? Color(red: 0.12, green: 0.3, blue: 0.7) : Color(white: 0.55), lineWidth: 1).padding(.vertical, 1).padding(.horizontal, 1))
        }
    }
}

// MARK: scroll bar parts and pop-up buttons of the Mac skins
struct SkinThumb: View {
    var body: some View {
        switch Theme.skin {
        case .win98: Color.gray98.overlay(Bevel(raised: true))
        case .platinum:
            Color.gray98.overlay(Bevel(raised: true)).overlay(VStack(spacing: 1) { ForEach(0..<3, id: \.self) { _ in Color.shade.frame(height: 1) } }.padding(.horizontal, 3))
        case .aqua:
            ZStack {
                Capsule().fill(LinearGradient(stops: [.init(color: Color(red: 0.62, green: 0.82, blue: 1.0), location: 0), .init(color: Color(red: 0.28, green: 0.58, blue: 0.97), location: 0.5),
                                                      .init(color: Color(red: 0.14, green: 0.45, blue: 0.90), location: 0.52), .init(color: Color(red: 0.42, green: 0.72, blue: 1.0), location: 1)], startPoint: .leading, endPoint: .trailing))
                Capsule().stroke(Color(red: 0.12, green: 0.32, blue: 0.7), lineWidth: 1)
            }
        }
    }
}
/// Pop-up button (status / system menu rows): Platinum = grey bevel with a small triangle, Aqua = gel pill with up/down arrows.
struct SkinPopup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 0) { content; Spacer(minLength: 0)
            switch Theme.skin {
            case .platinum: Canvas { c, s in var p = Path(); p.move(to: .init(x: 1, y: 3)); p.addLine(to: .init(x: 9, y: 3)); p.addLine(to: .init(x: 5, y: 8)); p.closeSubpath(); c.fill(p, with: .color(.black)) }.frame(width: 11, height: 11).padding(.trailing, 6)
            default:
                ZStack { Capsule().fill(LinearGradient(colors: [Color(red: 0.5, green: 0.75, blue: 1.0), Color(red: 0.13, green: 0.43, blue: 0.9)], startPoint: .top, endPoint: .bottom))
                    Canvas { c, s in
                        for up in [true, false] { var p = Path(); let y = up ? 5.0 : 11.0
                            if up { p.move(to: .init(x: 3, y: y + 2)); p.addLine(to: .init(x: 9, y: y + 2)); p.addLine(to: .init(x: 6, y: y - 1.5)) } else { p.move(to: .init(x: 3, y: y - 2)); p.addLine(to: .init(x: 9, y: y - 2)); p.addLine(to: .init(x: 6, y: y + 1.5)) }
                            p.closeSubpath(); c.fill(p, with: .color(.white)) }
                    }.frame(width: 12, height: 16) }.frame(width: 18, height: 16).padding(.trailing, 4)
            }
        }
    }
}
