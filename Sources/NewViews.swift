import SwiftUI
import AppKit

private func at(_ c: Ctl) -> some ViewModifier { Place(c: c) }
private struct Place: ViewModifier { let c: Ctl; func body(content: Content) -> some View { content.frame(width: c.w, height: c.h, alignment: .topLeading).offset(x: c.x, y: c.y) } }
extension View { fileprivate func place(_ c: Ctl) -> some View { modifier(Place(c: c)) } }

// MARK: About ICQ = dialog 2001
struct AboutView: View {
    var body: some View {
        let t = Tpl.load("2001")
        ZStack(alignment: .topLeading) {
            Pix(name: "splash", w: 120).frame(width: dx(84), height: dy(62), alignment: .topLeading).clipped()
            DlgView(tpl: t, texts: [5069: "Build # 2569"], custom: { c in
                switch c.id {
                case 1: return AnyView(PushBtn(label: "OK", isDefault: true) { WinMgr.shared.close("about") })
                case 1023, 1024: return AnyView(LinkLabel(text: c.text) { comingSoon() })
                default: return nil
                }
            })
        }
    }
    static var size: CGSize { let t = Tpl.load("2001"); return CGSize(width: t.w, height: t.h) }
}

// MARK: Confirm Delete User = dialog 1015
struct DeleteView: View {
    let uin: String
    var body: some View {
        let name = Store.shared.contact(uin)?.name ?? "?"
        DlgView(tpl: Tpl.load("1015"), texts: [1200: "Delete \(name) ?"]) { c in
            switch c.id {
            case 1: return AnyView(PushBtn(label: "Yes", isDefault: true) { Store.shared.remove(uin); WinMgr.shared.close("del" + uin) })
            case 2: return AnyView(PushBtn(label: "No", isCancel: true) { WinMgr.shared.close("del" + uin) })
            default: return nil
            }
        }
    }
    static var size: CGSize { let t = Tpl.load("1015"); return CGSize(width: t.w, height: t.h) }
}

// MARK: Change / Confirm Away Message = dialog 2064 (auto-closes after 7 s like the original)
struct AwayView: View {
    let status: Status
    @State private var msg: String
    @State private var left = 7
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    init(status: Status) {
        self.status = status
        _msg = State(initialValue: ["away": "I'm away from my computer right now.", "na": "I'm not available. Please leave a message.", "occupied": "I'm busy right now – urgent messages only.",
                                    "dnd": "Please do not disturb.", "ffc": "I'm free for a chat!"][status.rawValue] ?? "")
    }
    var body: some View {
        let word = status == .na ? "N/A" : (status == .ffc ? "free for chat" : status.rawValue)
        DlgView(tpl: Tpl.load("2064"), texts: [1242: "This message will be displayed to users when you are marked \"\(word)\".  The message may be modified to your preferences."]) { c in
            switch c.id {
            case 1: return AnyView(PushBtn(label: "Closing in \(left) sec", isDefault: true) { WinMgr.shared.close("away") })
            case 1237: return AnyView(REdit(text: $msg, multiline: true))
            case 1541: return AnyView(PushBtn(label: "Select Message") { notice("Not available in the local demo.") })
            default: return nil
            }
        }.onReceive(timer) { _ in left -= 1; if left <= 0 { WinMgr.shared.close("away") } }
    }
    static var size: CGSize { let t = Tpl.load("2064"); return CGSize(width: t.w, height: t.h) }
}

// MARK: message windows, laid out from the 1999 magazine screenshots ("Send Online Message", "Incoming Message")
private struct R { // absolute rectangle helper (client pixels)
    let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    init(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { self.x = x; self.y = y; self.w = w; self.h = h }
}
private extension View { func at(_ r: R) -> some View { frame(width: r.w, height: r.h, alignment: .topLeading).offset(x: r.x, y: r.y) } }
private func etched(_ title: String, _ r: R) -> some View { DefCtl(c: Ctl("Button", title, 0, 0, 0, 0, style: 0x50000007)).at(r) }
private func lbl(_ t: String, _ r: R, bold: Bool = false) -> some View { Text(t).font(rf(11, bold: bold)).foregroundColor(.black).lineLimit(1).fixedSize().frame(width: r.w, height: r.h, alignment: .leading).offset(x: r.x, y: r.y) }
private func val(_ t: String, _ r: R) -> some View {
    Text(t).font(rf()).foregroundColor(.black).lineLimit(1).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.gray98).overlay(Bevel(raised: false)).at(r)
}
private struct IconBtn: View {
    let name: String; var w: CGFloat = 20; var h: CGFloat = 20; let action: () -> Void
    var body: some View { Button(action: action) { Pix(name: name, w: 16).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.gray98) }.buttonStyle(PlainPush(isDefault: false)).frame(width: w, height: h) }
}
private struct VScrollBar: View { // static Win95 scroll bar (the message is short, the thumb fills the track)
    let h: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            Canvas { c, s in var p = Path(); p.move(to: .init(x: s.width / 2 - 3.5, y: s.height / 2 + 2)); p.addLine(to: .init(x: s.width / 2 + 3.5, y: s.height / 2 + 2)); p.addLine(to: .init(x: s.width / 2, y: s.height / 2 - 2)); p.closeSubpath(); c.fill(p, with: .color(.black)) }
                .frame(width: 15, height: 16).background(Color.gray98).overlay(Bevel())
            Color.gray98.overlay(Bevel()).frame(width: 15, height: h - 32)
            Canvas { c, s in var p = Path(); p.move(to: .init(x: s.width / 2 - 3.5, y: s.height / 2 - 2)); p.addLine(to: .init(x: s.width / 2 + 3.5, y: s.height / 2 - 2)); p.addLine(to: .init(x: s.width / 2, y: s.height / 2 + 2)); p.closeSubpath(); c.fill(p, with: .color(.black)) }
                .frame(width: 15, height: 16).background(Color.gray98).overlay(Bevel())
        }.frame(width: 15, height: h)
    }
}
private let msgDate: (Date) -> String = { d in let f = DateFormatter(); f.dateFormat = "yy/MM/dd"; return f.string(from: d) }
private let msgTime: (Date) -> String = { d in let f = DateFormatter(); f.dateFormat = "H:mm"; return f.string(from: d) }

struct SendView: View {
    let uin: String; @State private var text = ""
    static let size = CGSize(width: 334, height: 170)
    var body: some View {
        let c = Store.shared.contact(uin) ?? Contact(name: "?", uin: uin)
        GeometryReader { g in
            let W = floor(g.size.width), H = floor(g.size.height)
            ZStack(alignment: .topLeading) {
                etched("To:", R(0, 0, W, 44))
                lbl("ICQ#:", R(8, 20, 34, 14), bold: true); val(c.uin, R(42, 17, 66, 18))
                lbl("Nick:", R(114, 20, 28, 14), bold: true); val(c.name, R(144, 17, 62, 18))
                lbl("EMail:", R(212, 20, 36, 14), bold: true); val(c.mailAddr ?? "", R(248, 17, max(30, W - 248 - 30), 18))
                IconBtn(name: "m_email", w: 20, h: 22) { ICQ.mail(c) }.offset(x: W - 24, y: 15)
                lbl("Enter Message:", R(4, 52, 90, 14)); lbl("Chars:", R(100, 52, 34, 14)); val(String(text.count), R(134, 49, 30, 18))
                IconBtn(name: "tool_0") {}.offset(x: 170, y: 48)
                IconBtn(name: "tool_3") {}.offset(x: 196, y: 48)
                IconBtn(name: "tool_4") {}.offset(x: 218, y: 48)
                IconBtn(name: "tool_5") {}.offset(x: 240, y: 48)
                PushBtn(label: "History") { ICQ.openArchive(uin) }.at(R(W - 60, 48, 58, 21))
                REdit(text: $text, multiline: true).at(R(2, 72, W - 4, max(40, H - 72 - 28)))
                Button { comingSoon() } label: { Pix(name: "more").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.gray98) }.buttonStyle(PlainPush(isDefault: false)).at(R(2, H - 24, 52, 22))
                PushBtn(label: "Cancel", isCancel: true) { WinMgr.shared.close("send" + uin) }.at(R(W - 146, H - 24, 70, 22))
                PushBtn(label: "Send", isDefault: true) {
                    let v = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }
                    Store.shared.log(uin, "out", v); Sound.play("msgsent"); WinMgr.shared.close("send" + uin); Store.shared.botReply(uin)
                }.keyboardShortcut(.return, modifiers: .command).at(R(W - 72, H - 24, 70, 22))
            }.frame(width: W, height: H, alignment: .topLeading)
        }
        .onChange(of: text) { [text] new in
            if new.count > 450 { self.text = String(new.prefix(450)); return }
            Sound.play(new.count >= text.count ? "msgtype" : "msgback")
        }
    }
}
struct IncomingView: View {
    let uin: String; @ObservedObject var s = Store.shared
    @State private var textH: CGFloat = 0
    /// Messages being read in this window: they count as read as soon as the window takes them over (the envelope stops flashing).
    @State private var queue: [Msg]
    init(uin: String) { self.uin = uin; _queue = State(initialValue: Store.shared.unread[uin] ?? []) }
    static let size = CGSize(width: 334, height: 220)
    static func title(_ n: Int) -> String { "Incoming Message [" + (n <= 1 ? "No More Events" : "\(n - 1) More Event" + (n == 2 ? "" : "s")) + "]" }
    var body: some View {
        let c = s.contact(uin) ?? Contact(name: "?", uin: uin), q = queue, id = "in" + uin
        let m = q.first, pop = { if !queue.isEmpty { queue.removeFirst() } }
        GeometryReader { g in
            let W = floor(g.size.width), H = floor(g.size.height), mh = max(40, H - 92 - 70)
            ZStack(alignment: .topLeading) {
                etched("From:", R(0, 0, W, 66))
                lbl("Nick Name:", R(6, 17, 60, 14), bold: true); val(c.name, R(68, 14, 84, 18))
                lbl("EMail:", R(158, 17, 36, 14), bold: true); val(c.mailAddr ?? "", R(196, 14, max(30, W - 196 - 28), 18))
                IconBtn(name: "m_email", w: 20, h: 22) { ICQ.mail(c) }.offset(x: W - 24, y: 12)
                lbl("ICQ#:", R(6, 42, 34, 14), bold: true); Pix(name: "contact", w: 16).offset(x: 42, y: 40); val(c.uin, R(62, 38, 62, 18))
                lbl("Date:", R(130, 42, 30, 14), bold: true); val(m.map { msgDate($0.t) } ?? "", R(162, 38, 56, 18))
                lbl("Time:", R(224, 42, 30, 14), bold: true); val(m.map { msgTime($0.t) } ?? "", R(256, 38, 50, 18))
                lbl("Message", R(6, 72, 60, 14))
                IconBtn(name: "tool_5") {}.offset(x: W - 102, y: 70)
                PushBtn(label: "History") { ICQ.openArchive(uin) }.at(R(W - 76, 70, 72, 20))
                let needsBar = textH > mh - 4
                ZStack(alignment: .topLeading) {
                    Color.white
                    ScrollView(showsIndicators: false) {
                        Text(m?.text ?? "").font(rf()).foregroundColor(.black).textSelection(.enabled).frame(width: max(40, W - 4 - (needsBar ? 17 : 0) - 14), alignment: .topLeading).padding(5)
                            .background(GeometryReader { t in Color.clear.onAppear { textH = t.size.height }.onChange(of: t.size.height) { textH = $0 } })
                    }.frame(width: W - 4 - (needsBar ? 17 : 0), height: mh)
                    if needsBar { VScrollBar(h: mh).offset(x: W - 4 - 17, y: 0) }   // scroll bar only when the text does not fit
                }.overlay(Bevel(raised: false)).at(R(2, 92, W - 4, mh))
                etched("Response Action", R(0, H - 64, W, 38))
                PushBtn(label: "Reply", isDefault: true) { pop(); WinMgr.shared.close(id); ICQ.openSend(uin) }.at(R(8, H - 52, 66, 21))
                PushBtn(label: "Forward") { comingSoon() }.at(R(80, H - 52, 66, 21))
                PushBtn(label: "Request Chat") { comingSoon() }.at(R(W - 102, H - 52, 94, 21))
                PushBtn(label: "More Functions") { popMenu([MItem("Message Archive") { ICQ.openArchive(uin) }, MItem("History") { ICQ.openArchive(uin) }]) }.at(R(2, H - 24, 104, 22))
                PushBtn(label: "Close", isCancel: true) { pop(); WinMgr.shared.close(id) }.at(R(W - 146, H - 24, 64, 22))
                PushBtn(label: "Read Next") { pop(); WinMgr.shared.setTitle(id, IncomingView.title(max(0, q.count - 1))) }.disabled(q.count < 2).at(R(W - 78, H - 24, 76, 22))
            }.frame(width: W, height: H, alignment: .topLeading)
        }
        .onAppear { if s.unread[uin] != nil { s.unread[uin] = nil; ICQ.refreshTray() } }
        .onChange(of: s.unread[uin]?.count ?? 0) { n in      // more messages arrived while the window is open
            guard n > 0, let more = s.unread[uin] else { return }
            queue += more; s.unread[uin] = nil; ICQ.refreshTray(); WinMgr.shared.setTitle(id, IncomingView.title(queue.count))
        }
    }
}
