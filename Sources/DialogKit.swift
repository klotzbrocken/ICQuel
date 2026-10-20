import SwiftUI
import AppKit

// Renders dialog templates (built-in ones, or the dialogs.json of an imported theme pack). Coordinates are dialog units of
// "MS Sans Serif" 8pt (base units 6x13): px_x = du*6/4, px_y = du*13/8, exactly as Windows' MapDialogRect.
func dx(_ v: Int) -> CGFloat { CGFloat((v * 6 + 2) / 4) }
func dy(_ v: Int) -> CGFloat { CGFloat((v * 13 + 4) / 8) }

struct Ctl {
    var cls: String; var text: String; var ord: Int?; var id: Int
    var x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat; var style: UInt32
    var visible: Bool { style & 0x10000000 != 0 }
    init(_ cls: String, _ text: String = "", id: Int = 65535, _ x: Int, _ y: Int, _ w: Int, _ h: Int, style: UInt32 = 0x50020000, ord: Int? = nil) {
        self.cls = cls; self.text = text; self.ord = ord; self.id = id
        self.x = dx(x); self.y = dy(y); self.w = dx(w); self.h = dy(h); self.style = style
    }
}
struct Tpl {
    var w: CGFloat, h: CGFloat, ctls: [Ctl], pt: Int, face: String
    static func load(_ key: String) -> Tpl {
        let t: [String: Any]
        if let j = Assets.dialogs(), let x = j[key] as? [String: Any] { t = x } else if let b = Builtin.template(key) { return b } else { return Tpl(w: 200, h: 100, ctls: [], pt: 8, face: "MS Sans Serif") }
        do {
            let names = [0x80: "Button", 0x81: "Edit", 0x82: "Static", 0x83: "ListBox", 0x84: "ScrollBar", 0x85: "ComboBox"]
            let cs: [Ctl] = (t["controls"] as? [[String: Any]] ?? []).map { c in
                let cl = (c["cls"] as? Int).flatMap { names[$0] } ?? (c["cls"] as? String ?? "?")
                var ctl = Ctl(cl, c["text"] as? String ?? "", id: c["id"] as? Int ?? 0, c["x"] as? Int ?? 0, c["y"] as? Int ?? 0, c["w"] as? Int ?? 0, c["h"] as? Int ?? 0,
                              style: UInt32(truncatingIfNeeded: c["style"] as? Int ?? 0), ord: c["text"] as? Int)
                ctl.id = ctl.id & 0xFFFF; return ctl
            }
            let f = t["font"] as? [Any]
            return Tpl(w: dx(t["cx"] as? Int ?? 0), h: dy(t["cy"] as? Int ?? 0), ctls: cs, pt: f?.first as? Int ?? 8, face: f?.last as? String ?? "MS Sans Serif")
        }
    }
}
/// Win32 label cleanup: "&Yes" -> "Yes", "&&" -> "&".
func clean(_ s: String) -> String {
    var out = "", skip = false
    for ch in s { if ch == "&" && !skip { skip = true; continue }; skip = false; out.append(ch) }
    return out.replacingOccurrences(of: "\r", with: "")
}
var dlgFont: (CGFloat, Bool) -> Font = { s, b in rf(s, bold: b) }

struct PushBtn: View {
    let label: String; var isDefault = false; var isCancel = false; let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        Button(action: action) {
            Text(label).font(rf()).foregroundColor(ButtonBG.text(isDefault, enabled: enabled)).lineLimit(1).minimumScaleFactor(0.85).padding(.horizontal, 2).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(PlainPush(isDefault: isDefault))
            .keyboardShortcut(isDefault ? KeyboardShortcut.defaultAction : (isCancel ? KeyboardShortcut.cancelAction : nil))
    }
}
struct PlainPush: ButtonStyle {
    var isDefault: Bool
    func makeBody(configuration c: Configuration) -> some View {
        c.label.background(ButtonBG(pressed: c.isPressed, isDefault: isDefault))
            .offset(x: c.isPressed && ButtonBG.pressShift ? 1 : 0, y: c.isPressed && ButtonBG.pressShift ? 1 : 0).contentShape(Rectangle())
    }
}
struct REdit: View {
    @Binding var text: String; var secure = false; var multiline = false
    var body: some View {
        Group {
            if multiline { TextEditor(text: $text).scrollContentBackground(.hidden) }
            else if secure { SecureField("", text: $text).frame(maxHeight: .infinity) } else { TextField("", text: $text).frame(maxHeight: .infinity) }
        }.textFieldStyle(.plain).font(rf()).foregroundColor(.black).padding(.horizontal, multiline ? 5 : 5).padding(.vertical, multiline ? 4 : 0)
            .background(Color.white).overlay(Bevel(raised: false))
    }
}
struct LinkLabel: View {
    let text: String; let action: () -> Void
    var body: some View {
        Text(text).font(rf()).underline().foregroundColor(Color(red: 0, green: 0, blue: 1)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle()).onTapGesture(perform: action)
    }
}

/// Default Win98 rendering of one control; `on` drives checkbox/radio state.
struct DefCtl: View {
    let c: Ctl; var on = false; var action: () -> Void = {}
    var body: some View {
        let label = clean(c.text)
        switch c.cls {
        case "Static":
            let t = c.style & 0x1F
            if t == 3 {
                if let o = c.ord { Pix(name: "ico_\(o)", w: 32).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }
            } else if t >= 7 && t <= 9 {
                if c.h <= 3 { VStack(spacing: 0) { Color.shade.frame(height: 1); Color.white.frame(height: 1) } .frame(maxHeight: .infinity, alignment: .top) }
                else { Rectangle().stroke(Color.shade, lineWidth: 1) }
            } else {
                let sunk = c.style & 0x1000 != 0, single = !label.contains("\n") && c.h < 22
                Text(label).font(rf()).foregroundColor(.black).lineSpacing(0).lineLimit(single ? 1 : nil).fixedSize(horizontal: single, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: t == 1 ? .top : (t == 2 ? .topTrailing : .topLeading))
                    .multilineTextAlignment(t == 1 ? .center : (t == 2 ? .trailing : .leading))
                    .padding(.horizontal, sunk ? 2 : 0).overlay(sunk ? Bevel(raised: false) : nil)
            }
        case "Button":
            switch c.style & 0xF {
            case 7:
                ZStack(alignment: .topLeading) {
                    Rectangle().stroke(Color.shade, lineWidth: 1).padding(.top, 6)
                    Rectangle().stroke(Color.white, lineWidth: 1).padding(.top, 6).offset(x: 1, y: 1).mask(Rectangle().stroke(lineWidth: 2).padding(.top, 6))
                    if !label.isEmpty { Text(label).font(rf()).foregroundColor(.black).padding(.horizontal, 2).background(Color.gray98).offset(x: 8, y: -1) }
                }
            case 2, 3, 5, 6:
                HStack(alignment: .top, spacing: 4) {
                    SkinCheck(on: on)
                    Text(label).font(rf()).foregroundColor(.black).fixedSize(horizontal: true, vertical: false).padding(.top, -1); Spacer(minLength: 0)
                }.contentShape(Rectangle()).onTapGesture(perform: action)
            case 4, 9:
                HStack(alignment: .top, spacing: 4) {
                    SkinRadio(on: on)
                    Text(label).font(rf()).foregroundColor(.black).fixedSize(horizontal: true, vertical: false); Spacer(minLength: 0)
                }.contentShape(Rectangle()).onTapGesture(perform: action)
            default:
                PushBtn(label: label, isDefault: (c.style & 0xF) == 1, action: action)
            }
        case "Edit", "ListBox", "RICHEDIT", "RichEdit20A", "RichEdit":
            Text(label).font(rf()).foregroundColor(.black).lineLimit(c.h < 22 ? 1 : nil).padding(.horizontal, 5).padding(.vertical, c.h < 22 ? 0 : 3).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: c.h < 22 ? .leading : .topLeading)
                .background(Color.white).overlay(Bevel(raised: false))
        case "ComboBox":
            HStack(spacing: 0) {
                Text(label).font(rf()).foregroundColor(.black).padding(.leading, 3).frame(maxWidth: .infinity, alignment: .leading)
                ZStack { Color.gray98; Text("▾").font(rf(10)).foregroundColor(.black) }.frame(width: 16).overlay(Bevel())
            }.frame(height: 21).background(Color.white).overlay(Bevel(raised: false)).frame(maxHeight: .infinity, alignment: .top)
        default: Color.clear
        }
    }
}

/// A whole dialog: every control placed at its original pixel position. `custom` lets a screen replace individual controls.
struct DlgView: View {
    let tpl: Tpl
    var hidden: Set<Int> = []
    var texts: [Int: String] = [:]
    var show: Set<Int> = []
    var custom: (Ctl) -> AnyView? = { _ in nil }
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(tpl.ctls.enumerated()), id: \.offset) { _, c0 in
                let c = { () -> Ctl in var c = c0; if let t = texts[c0.id] { c.text = t }; return c }()
                if (c.visible || show.contains(c.id)) && !hidden.contains(c.id) {
                    (custom(c) ?? AnyView(DefCtl(c: c))).frame(width: c.w, height: c.h, alignment: .topLeading).offset(x: c.x, y: c.y)
                }
            }
        }.frame(width: tpl.w, height: tpl.h, alignment: .topLeading)
    }
}
