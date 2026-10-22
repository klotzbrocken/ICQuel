import SwiftUI
import AppKit

// The ICQ 99b contact list window, laid out from the reference screenshot (client area 164 x 330 px advanced, 164 x 261 px simple).
private struct ScrollInfo: Equatable { var offset: CGFloat = 0; var content: CGFloat = 0 }
private extension View {
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View { frame(width: w, height: h, alignment: .topLeading).offset(x: x, y: y) }
}
private struct Raised: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label.frame(maxWidth: .infinity, maxHeight: .infinity).background(ButtonBG(pressed: c.isPressed))
            .offset(x: c.isPressed && ButtonBG.pressShift ? 1 : 0, y: c.isPressed && ButtonBG.pressShift ? 1 : 0)
    }
}
private struct Sunken98<C: View>: View {
    @ViewBuilder var content: C
    var body: some View { content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(Color.gray98).overlay(Bevel(raised: false)) }
}
private struct Arrow: View {
    let up: Bool
    var body: some View {
        Canvas { c, s in
            var p = Path(); let cx = s.width / 2, cy = s.height / 2
            if up { p.move(to: .init(x: cx - 3.5, y: cy + 2)); p.addLine(to: .init(x: cx + 3.5, y: cy + 2)); p.addLine(to: .init(x: cx, y: cy - 2)) }
            else { p.move(to: .init(x: cx - 3.5, y: cy - 2)); p.addLine(to: .init(x: cx + 3.5, y: cy - 2)); p.addLine(to: .init(x: cx, y: cy + 2)) }
            p.closeSubpath(); c.fill(p, with: .color(.black))
        }
    }
}
private struct Dither: View { // scroll bar track
    var body: some View {
        switch Theme.skin {
        case .win98: checker(.white, Color.gray98)
        case .platinum: checker(Color(white: 0.93), Color(white: 0.68)).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        case .aqua: LinearGradient(colors: [Color(white: 0.82), Color(white: 0.97)], startPoint: .leading, endPoint: .trailing).overlay(Rectangle().stroke(Color(white: 0.6), lineWidth: 1))
        }
    }
    func checker(_ a: Color, _ b: Color) -> some View {
        Canvas { c, s in
            for y in 0..<Int(s.height) { for x in 0..<Int(s.width) where (x + y) % 2 == 0 { c.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(a)) } }
        }.background(b)
    }
}

struct MainView: View {
    @ObservedObject var s = Store.shared
    @State private var tab = 0
    @State private var search = ""
    @State private var scroll = ScrollInfo()
    private let listH: CGFloat = 211
    static let help = "Instructions: double-click a contact to send a message. Use \"Add Users\" to add contacts and the System Menu for preferences."

    var body: some View {
        GeometryReader { g in
            let W = floor(g.size.width), H = floor(g.size.height)
            Group { if Theme.skin == .platinum { platinumBody(W, H) } else if s.simpleMode { simpleBody(W, H) } else { advancedBody(W, H) } }.frame(width: W, height: H, alignment: .topLeading)
        }
        .onChange(of: s.uin) { WinMgr.shared.setTitle("main", $0) }
        .onChange(of: s.flash) { _ in ICQ.refreshTray() }
    }

    // MARK: simple mode (reference: window "30033529"); the layout stretches with the window
    func simpleBody(_ W: CGFloat, _ H: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            list(simple: true, w: W - 4, h: H - 77).box(3, 2, W - 4, H - 77)
            Button { ICQ.openAdd() } label: { Pix(name: "addusers") }.buttonStyle(Raised()).box(2, H - 73, W - 4, 22)
            HStack(spacing: 5) { Pix(name: "contact", w: 16); Text("System Menu").font(rf()).foregroundColor(.white) }.padding(.leading, 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(Color.navy).overlay(Bevel(raised: false))
                .contentShape(Rectangle()).onTapGesture { ICQ.mainMenu() }.box(2, H - 49, W - 4, 22)
            Button { ICQ.openAbout() } label: { Image(nsImage: pic("icqlogo")).interpolation(.none).resizable().scaledToFit().frame(width: 44, height: 18) }.buttonStyle(Raised()).box(2, H - 25, 50, 22)
            Sunken98 { HStack(spacing: 4) { Pix(name: s.status.rawValue, w: 16); Text(s.status.panelLabel).font(rf()).foregroundColor(.black) }.padding(.leading, 3) }
                .contentShape(Rectangle()).onTapGesture { ICQ.statusMenu() }.box(55, H - 25, W - 55, 22)
        }
    }

    /// Row / pop-up look: Win98 sunken field, Platinum bevel + triangle, Aqua gel pill.
    @ViewBuilder func popup<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        if Theme.skin == .win98 { Sunken98 { c() } }
        else { SkinPopup { c() }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(ButtonBG(pressed: false)) }
    }
    // MARK: Mac OS 8/9 layout: list with scroll bar, then "System", "Add/Find Users" and the status pop-up (as in ICQ for Mac)
    func platinumBody(_ W: CGFloat, _ H: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            list(simple: false, w: W - 4, h: H - 84).box(3, 3, W - 4, H - 84)
            Button { ICQ.mainMenu() } label: { HStack(spacing: 5) { Pix(name: "contact", w: 16); Text("System").font(rf()); Spacer(minLength: 0) }.padding(.leading, 6) }.buttonStyle(Raised()).box(3, H - 78, W - 6, 22)
            Button { ICQ.openAdd() } label: { HStack(spacing: 5) { Pix(name: "usertab", w: 16); Text("Add/Find Users").font(rf()); Spacer(minLength: 0) }.padding(.leading, 6) }.buttonStyle(Raised()).box(3, H - 53, W - 6, 22)
            popup { HStack(spacing: 4) { Pix(name: s.status.rawValue, w: 16); Text(s.status.panelLabel).font(rf()).foregroundColor(.black) }.padding(.leading, 6) }
                .contentShape(Rectangle()).onTapGesture { ICQ.statusMenu() }.box(3, H - 28, W - 6, 24)
        }
    }

    // MARK: advanced mode (reference: window "21864060")
    func advancedBody(_ W: CGFloat, _ H: CGFloat) -> some View {
        let o = s.opts, half = (W - 6) / 2
        let listTop: CGFloat = o.tabs ? 22 : 3, listBottom: CGFloat = o.search ? H - 97 : H - 75
        return ZStack(alignment: .topLeading) {
            if o.tabs { tabButton(0, "All", "alltab").box(4, 3, 58, 19); tabButton(1, "User", "usertab").box(64, 3, 62, 19) }
            list(simple: false, w: W - 4, h: listBottom - listTop).box(3, listTop, W - 4, listBottom - listTop)
            if o.search { searchRow(W, H - 93) }
            Button { ICQ.openAdd() } label: { Pix(name: "addusers") }.buttonStyle(Raised()).box(2, H - 71, o.icqNow ? half : W - 4, 22)
            if o.icqNow { Button { openWeb("https://myretromac.app") } label: { Pix(name: "icqnow") }.buttonStyle(Raised()).box(4 + half, H - 71, half, 22) }
            if o.services { Button { ICQ.servicesMenu() } label: { Pix(name: "services") }.buttonStyle(Raised()).box(2, H - 47, 50, 22) }
            popup { HStack(spacing: 5) { Pix(name: "contact", w: 16); Text("System Menu").font(rf()).foregroundColor(.black).lineLimit(1).minimumScaleFactor(0.75) }.padding(.leading, 3) }
                .contentShape(Rectangle()).onTapGesture { ICQ.mainMenu() }.box(o.services ? 55 : 2, H - 47, o.services ? W - 55 : W - 4, 22)
            Button { ICQ.openAbout() } label: { Image(nsImage: pic("icqlogo")).interpolation(.none).resizable().scaledToFit().frame(width: 44, height: 18) }.buttonStyle(Raised()).box(2, H - 22, 50, 22)
            popup { HStack(spacing: 4) { Pix(name: s.status.rawValue, w: 16); Text(s.status.panelLabel).font(rf()).foregroundColor(.black) }.padding(.leading, 3) }
                .contentShape(Rectangle()).onTapGesture { ICQ.statusMenu() }.box(55, H - 22, W - 55, 22)
        }
    }

    func tabButton(_ i: Int, _ label: String, _ icon: String) -> some View {
        Button { tab = i } label: { HStack(spacing: 4) { Pix(name: icon, w: 16); Text(label).font(rf(12)).foregroundColor(.black) }.padding(.leading, 2) }
            .buttonStyle(Raised())
    }

    func searchRow(_ W: CGFloat, _ y: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: tile("grip", 0, 10)).interpolation(.none).resizable().frame(width: 8, height: 20).box(3, y + 0, 8, 20)
            TextField("", text: $search, prompt: Text(brand("Search ICQ IT!")).foregroundColor(.black)).textFieldStyle(.plain).font(rf()).foregroundColor(.black).onSubmit { googleSearch(search) }
                .frame(maxHeight: .infinity).padding(.horizontal, 3).background(Color.white).overlay(Bevel(raised: false)).box(14, y, W - 40, 19)
            Button { googleSearch(search) } label: { Pix(name: "go") }.buttonStyle(Raised()).box(W - 22, y, 14, 19)
            Button { googleSearch(search) } label: { Pix(name: "arrowr") }.buttonStyle(Raised()).box(W - 7, y, 7, 19)
        }
    }

    // MARK: contact list box (with its own scroll bar in advanced mode)
    func list(simple: Bool, w boxW: CGFloat, h listH: CGFloat) -> some View {
        let live = s.contacts.filter(\.isLive).sorted { $0.name.lowercased() < $1.name.lowercased() }
        let on = s.contacts.filter { !$0.isLive && s.status != .offline && s.online.contains($0.uin) }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        let o = s.opts
        let off = o.showOffline ? s.contacts.filter { c in !c.isLive && !on.contains(c) }.sorted { $0.name.lowercased() < $1.name.lowercased() } : []
        let viewH = listH - 4, track = listH - 4 - 32
        let needsBar = !simple && scroll.content > viewH                  // scroll bar only when the list does not fit
        let barW: CGFloat = needsBar ? 15 : 0, contentW = boxW - 4 - barW
        let thumbH = max(14, track * viewH / max(scroll.content, 1))
        let thumbY = scroll.content <= viewH ? 0 : (track - thumbH) * scroll.offset / (scroll.content - viewH)
        return ZStack(alignment: .topLeading) {
            (Theme.skin == .win98 ? Color.gray98 : Color.white)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if simple {
                        VStack(spacing: 2) {
                            if o.btnInstructions { flat("Instructions") { notice(MainView.help) } }
                            flat("To Advanced Mode") { ICQ.setSimple(false) }
                            if o.btnRandom { flat("Find Random Chat Partner") { comingSoon() } }
                        }.padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 6)
                        ForEach(on + live + off) { row($0, offline: !(on + live).contains($0)) }
                    } else if tab == 0 {
                        header("Online"); ForEach(on) { row($0, offline: false) }
                        if o.showIMessage { header("iMessage"); ForEach(live) { row($0, offline: false) }; if s.bridgeEnabled { flat("Import from Messages…") { ICQ.openMessagesImport() }.padding(.horizontal, 4).padding(.vertical, 2) } }
                        if o.showOffline { header("Offline"); ForEach(off) { row($0, offline: true) } }
                    } else {
                        ForEach((on + live + off).sorted { $0.name.lowercased() < $1.name.lowercased() }) { c in row(c, offline: !(on + live).contains(c)) }
                    }
                    if !simple {
                        // the button block sits at the bottom of the list: hidden rows/buttons never leave gaps below it
                        let rows = tab == 0 ? 20 * (on.count + (o.showIMessage ? live.count : 0) + off.count) + 17 * (1 + (o.showIMessage ? 1 : 0) + (o.showOffline ? 1 : 0)) + (o.showIMessage && s.bridgeEnabled ? 19 : 0) : 20 * (on.count + live.count + off.count)
                        let nb = CGFloat((o.btnInstructions ? 1 : 0) + 1 + (o.btnRandom ? 1 : 0) + (o.btnWeb ? 1 : 0) + (o.btnCool ? 1 : 0))
                        Color.clear.frame(height: max(0, viewH - CGFloat(rows) - (nb * 15 + (nb - 1) * 2 + 10)))
                        VStack(spacing: 2) {
                            if o.btnInstructions { flat("Instructions") { notice(MainView.help) } }
                            flat("To Simple Mode") { ICQ.setSimple(true) }
                            if o.btnRandom { flat("Find Random Chat Partner") { comingSoon() } }
                            if o.btnWeb { flat("Website") { openWeb("https://myretromac.app") } }
                            if o.btnCool { flat(brand("ICQ Cool Links")) { comingSoon() } }
                        }.padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 4)
                    }
                }.frame(width: contentW).background(GeometryReader { g in
                    Color.clear
                        .onAppear { scroll = ScrollInfo(offset: -g.frame(in: .named("lst")).minY, content: g.size.height) }
                        .onChange(of: g.size.height) { scroll.content = $0 }
                        .onChange(of: g.frame(in: .named("lst")).minY) { scroll.offset = -$0 }
                })
            }.coordinateSpace(name: "lst").box(2, 2, contentW, viewH)
            if needsBar {
                Group {
                    Button {} label: { Arrow(up: true) }.buttonStyle(Raised()).box(boxW - 17, 2, 15, 16)
                    Dither().box(boxW - 17, 18, 15, track)
                    SkinThumb().box(boxW - 17, 18 + thumbY, 15, thumbH)
                    Button {} label: { Arrow(up: false) }.buttonStyle(Raised()).box(boxW - 17, 2 + 16 + track, 15, 16)
                }
            }
        }.overlay(Bevel(raised: false))
    }
    func flat(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(t).font(rf()).foregroundColor(.black).lineLimit(1).minimumScaleFactor(0.85).padding(.horizontal, 2).frame(maxWidth: .infinity) }.buttonStyle(Raised()).frame(height: 15)
    }
    func header(_ t: String) -> some View {
        HStack(spacing: 4) {
            VStack(spacing: 0) { Color.shade.frame(height: 1); Color.white.frame(height: 1) }.frame(maxWidth: .infinity)
            Text(t).font(rf()).foregroundColor(.black).lineLimit(1).minimumScaleFactor(0.7).fixedSize()
            VStack(spacing: 0) { Color.shade.frame(height: 1); Color.white.frame(height: 1) }.frame(maxWidth: .infinity)
        }.frame(height: 17).padding(.horizontal, 3)
    }
    func row(_ c: Contact, offline: Bool) -> some View {
        let pending = !(s.unread[c.uin] ?? []).isEmpty, sel = s.selected == c.uin
        let col: Color = sel ? .white : (offline ? Color(red: 1, green: 0, blue: 0) : Color(red: 0, green: 0, blue: 1))
        return HStack(spacing: 6) {
            Pix(name: pending && s.flash ? "note" : "contact", w: 16)
            Text(c.name).font(rf(12)).foregroundColor(col).lineLimit(1)
            Spacer(minLength: 0)
        }.padding(.leading, 5).frame(height: 20).background(sel ? Color.navy : Color.clear).contentShape(Rectangle())
            .onTapGesture(count: 2) { pending ? ICQ.openIncoming(c.uin) : ICQ.openSend(c.uin) }
            .onTapGesture { s.selected = c.uin }
            .overlay(RightClick { s.selected = c.uin; popMenu([MItem("Send Message") { ICQ.openSend(c.uin) }, MItem("History") { ICQ.openArchive(c.uin) }] + ICQ.contactItems(c) + (c.isBot ? [MItem("AI Assistant Mode", checked: c.isAssistant) { s.toggleAssistant(c.uin) }] : []) + [.separator(), MItem("Delete") { ICQ.confirmDelete(c.uin) }]) })
    }
}

func openWeb(_ s: String) { if let u = URL(string: s) { NSWorkspace.shared.open(u) } }
/// "Search ICQ IT!" uses Google in the default browser.
func googleSearch(_ q: String) {
    let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty || t == brand("Search ICQ IT!") { openWeb("https://www.google.com"); return }
    openWeb("https://www.google.com/search?q=" + (t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t))
}
