import SwiftUI
import AppKit

// Windows-98 look for the window contents; the window chrome itself stays native macOS.
extension Color {
    // surface colours of the classic family (Win98 / Platinum / Aqua)
    static var gray98: Color { switch Theme.skin { case .win98: return Color(red: 192 / 255, green: 192 / 255, blue: 192 / 255); case .platinum: return Color(white: 221 / 255); case .aqua: return Color(white: 233 / 255) } }
    static var navy: Color { switch Theme.skin { case .win98: return Color(red: 0, green: 0, blue: 128 / 255); case .platinum: return Color(white: 0.18); case .aqua: return Color(red: 0.22, green: 0.47, blue: 0.90) } }
    static var shade: Color { switch Theme.skin { case .win98: return Color(white: 0.5); case .platinum: return Color(white: 0.52); case .aqua: return Color(white: 0.56) } }
    static var light: Color { switch Theme.skin { case .win98: return Color(white: 223 / 255); default: return Color(white: 0.9) } }
    static var ink: Color { Theme.isModern ? Color.primary : .black }
    /// explanatory text: readable in the dark Mac theme as well
    static var hint: Color { Theme.isModern ? Color.primary.opacity(0.75) : Color(white: 0.3) }
}
func rf(_ s: CGFloat = 10.5, bold: Bool = false) -> Font {
    if Theme.isModern { return .system(size: s + 2, weight: bold ? .semibold : .regular) }
    if Theme.skin == .aqua { return .custom(bold ? "LucidaGrande-Bold" : "LucidaGrande", size: s * 0.9) }
    if Theme.skin == .platinum { return bold ? Font.custom("Geneva", size: s * 0.9).bold() : .custom("Geneva", size: s * 0.9) }   // Mac OS 8/9 system font family
    return .custom(bold ? "Helvetica-Bold" : "Helvetica", size: s)
}

private var imgCache: [String: NSImage] = [:]
func clearImageCache() { imgCache = [:] }
func pic(_ name: String) -> NSImage {
    if let i = imgCache[name] { return i }
    if let f = Assets.resource("img", name + ".png"), let i = NSImage(contentsOfFile: f) { imgCache[name] = i; return i }
    return NSImage(size: NSSize(width: 16, height: 16))
}
/// Pixel-exact bitmap (no smoothing), optionally scaled to a fixed size.
struct Pix: View {
    let name: String; var w: CGFloat? = nil; var h: CGFloat? = nil
    var body: some View {
        let i = pic(name)
        Image(nsImage: i).interpolation(.none).resizable().frame(width: w ?? i.size.width, height: h ?? w ?? i.size.height)
    }
}
/// One 11-px tile out of a horizontal strip bitmap (used for the group arrows).
func tile(_ name: String, _ idx: Int, _ size: Int) -> NSImage {
    let src = pic(name)
    guard let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let c = cg.cropping(to: CGRect(x: idx * size, y: 0, width: size, height: cg.height)) else { return src }
    return NSImage(cgImage: c, size: NSSize(width: size, height: cg.height))
}

struct Bevel: View {
    var raised = true
    var win = false   // window frames: light grey outer / white inner on the top-left
    var body: some View {
        if Theme.isModern { Rectangle().stroke(Color.primary.opacity(0.25), lineWidth: 1).allowsHitTesting(false) }
        else { switch Theme.skin { case .win98: classic; case .platinum: platinum; case .aqua: aqua } }
    }
    var classic: some View {
        Canvas { c, s in
            func line(_ a: CGPoint, _ b: CGPoint, _ col: Color) { var p = Path(); p.move(to: a); p.addLine(to: b); c.stroke(p, with: .color(col), lineWidth: 1) }
            let w = s.width, h = s.height
            let (o1, o2, i1, i2): (Color, Color, Color, Color) = raised ? (win ? .light : .white, .black, win ? .white : .light, .shade) : (.shade, .white, .black, .light)
            line(.init(x: 0, y: h - 0.5), .init(x: w, y: h - 0.5), o2); line(.init(x: w - 0.5, y: 0), .init(x: w - 0.5, y: h), o2)
            line(.init(x: 0, y: 0.5), .init(x: w, y: 0.5), o1); line(.init(x: 0.5, y: 0), .init(x: 0.5, y: h), o1)
            line(.init(x: 1, y: h - 1.5), .init(x: w - 1, y: h - 1.5), i2); line(.init(x: w - 1.5, y: 1), .init(x: w - 1.5, y: h - 1), i2)
            line(.init(x: 1, y: 1.5), .init(x: w - 1, y: 1.5), i1); line(.init(x: 1.5, y: 1), .init(x: 1.5, y: h - 1), i1)
        }.allowsHitTesting(false)
    }
}

struct RetroButtonStyle: ButtonStyle {
    var isDefault = false; var minWidth: CGFloat = 75
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration c: Configuration) -> some View {
        c.label.font(rf()).foregroundColor(ButtonBG.text(isDefault, enabled: enabled))
            .padding(.horizontal, 8).frame(minWidth: minWidth, minHeight: 23)
            .background(ButtonBG(pressed: c.isPressed, isDefault: isDefault))
            .offset(x: c.isPressed && ButtonBG.pressShift ? 1 : 0, y: c.isPressed && ButtonBG.pressShift ? 1 : 0).contentShape(Rectangle())
    }
}
struct RButton: View {
    let title: String; var isDefault = false; var minWidth: CGFloat = 75; let action: () -> Void
    var body: some View {
        if Theme.isModern { Button(title, action: action).keyboardShortcut(isDefault ? KeyboardShortcut.defaultAction : nil).frame(minWidth: minWidth > 75 ? minWidth : nil) }
        else { Button(title, action: action).buttonStyle(RetroButtonStyle(isDefault: isDefault, minWidth: minWidth)) }
    }
}

struct RField: View {
    var placeholder = ""; @Binding var text: String; var secure = false; var onSubmit: () -> Void = {}
    var body: some View {
        if Theme.isModern {
            Group { if secure { SecureField(placeholder, text: $text).onSubmit(onSubmit) } else { TextField(placeholder, text: $text).onSubmit(onSubmit) } }.textFieldStyle(.roundedBorder)
        } else { classic }
    }
    var classic: some View {
        Group { if secure { SecureField(placeholder, text: $text).onSubmit(onSubmit) } else { TextField(placeholder, text: $text).onSubmit(onSubmit) } }
            .textFieldStyle(.plain).font(rf()).foregroundColor(.black).frame(maxHeight: .infinity, alignment: .center).padding(.horizontal, 6).frame(height: 23)
            .background(Color.white).overlay(Bevel(raised: false))
    }
}
struct RText: View { // multi-line edit box
    @Binding var text: String
    var body: some View {
        if Theme.isModern { TextEditor(text: $text).padding(2).overlay(Rectangle().stroke(Color(white: 0.7))) } else { classic }
    }
    var classic: some View {
        TextEditor(text: $text).font(rf()).foregroundColor(.black).scrollContentBackground(.hidden)
            .padding(.horizontal, 5).padding(.vertical, 4).background(Color.white).overlay(Bevel(raised: false))
    }
}
struct Sunken<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.background(Theme.isModern ? Color(nsColor: .textBackgroundColor) : Color.white).overlay(Bevel(raised: false)) }
}
struct RCheck: View {
    let title: String; @Binding var on: Bool
    var body: some View {
        if Theme.isModern { Toggle(title, isOn: $on).toggleStyle(.checkbox) } else { classic }
    }
    var classic: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 5) {
                SkinCheck(on: on)
                Text(title).font(rf()).foregroundColor(.black)
            }
        }.buttonStyle(.plain)
    }
}
struct RRadio: View {
    let title: String; let on: Bool; let action: () -> Void
    var body: some View {
        if Theme.isModern { Button(action: action) { HStack(spacing: 6) { Image(systemName: on ? "largecircle.fill.circle" : "circle").foregroundColor(on ? .accentColor : .secondary); Text(title) } }.buttonStyle(.plain) }
        else { classic }
    }
    var classic: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                SkinRadio(on: on)
                Text(title).font(rf()).foregroundColor(.black)
            }
        }.buttonStyle(.plain)
    }
}
struct RGroup<Content: View>: View {
    static var icons: [String: String] { ["My Details": "person.text.rectangle", "Application name": "textformat", "Theme": "paintpalette", "Window size (Classic)": "arrow.up.left.and.arrow.down.right", "Window": "macwindow",
        "Contact list": "list.bullet.rectangle", "AI API Key": "key.fill", "AI Chatbots": "bubble.left.and.bubble.right", "Chatbot activity": "clock.arrow.2.circlepath", "Frequency": "timer",
        "Connected iMessage contacts": "message.fill", "Sound events": "speaker.wave.2", "Permissions (macOS asks you, this app cannot grant them itself)": "lock.shield", "First iMessage contact (optional)": "person.badge.plus",
        "API key": "key.fill", "Create your first chatbot": "sparkles"] }
    let title: String; @ViewBuilder var content: Content
    var body: some View {
        if Theme.isModern {
            GroupBox(label: Label(title, systemImage: RGroup<Content>.icons[title] ?? "square.grid.2x2").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 6) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
        } else { classic }
    }
    var classic: some View {
        VStack(alignment: .leading, spacing: 4) { content }.padding(.horizontal, 8).padding(.top, 12).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(Color.shade, lineWidth: 1))
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1).offset(x: 1, y: 1).mask(Rectangle().stroke(lineWidth: 2)))
            .overlay(Text(title).font(rf()).foregroundColor(.black).padding(.horizontal, 3).background(Color.gray98).padding(.leading, 6).offset(y: -7), alignment: .topLeading)
            .padding(.top, 7)
    }
}
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if Theme.isModern { VStack(alignment: .leading, spacing: 8) { content }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }
        else { VStack(alignment: .leading, spacing: 4) { content }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Color.gray98).overlay(Bevel()) }
    }
}
struct Win98: ViewModifier { // common window background + default text colour
    func body(content: Content) -> some View { content.foregroundColor(.black).font(rf()).background(Color.gray98).environment(\.colorScheme, .light) }
}
extension View { func win98() -> some View { modifier(Win98()) } }

/// Windows multi-row tab control (as in "Owner Prefs For: ..."): the row holding the selected tab sits next to the page.
struct WTabs: View {
    let rows: [[Int]]; let titles: [String]; let width: CGFloat; @Binding var sel: Int
    private func tw(_ i: Int) -> CGFloat { (titles[i] as NSString).size(withAttributes: [.font: NSFont(name: "Helvetica", size: 10.5) ?? .systemFont(ofSize: 11)]).width + 24 }
    var body: some View {
        let ordered = rows.sorted { !$0.contains(sel) && $1.contains(sel) }
        VStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, ids in
                let total = ids.reduce(0) { $0 + tw($1) }, k = (width - 4) / max(total, 1)
                HStack(spacing: 0) {
                    ForEach(ids, id: \.self) { i in
                        let on = i == sel
                        Text(titles[i]).font(rf(10.5, bold: on)).foregroundColor(.black).frame(width: tw(i) * k, height: on ? 21 : 19)
                            .modifier(TabLook(on: on))
                            .offset(y: on ? 1 : 0).zIndex(on ? 1 : 0).contentShape(Rectangle()).onTapGesture { sel = i }
                    }
                }.frame(width: width - 4, alignment: .leading).padding(.leading, 2)
            }
        }
    }
}
