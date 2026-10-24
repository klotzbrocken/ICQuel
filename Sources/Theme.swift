import SwiftUI
import AppKit

/// Visual themes. "classic" is the 1999 Windows client (pixel layout, Win98 chrome); "platinum" and "aqua" use the same layout with Mac OS 8/9
/// resp. Mac OS X Aqua window chrome and controls; "modern" uses real macOS windows and controls.
enum Theme: String, CaseIterable {
    case classic, modern, aqua, platinum
    var title: String {
        switch self { case .classic: return "\(App.name) Retro"; case .modern: return "\(App.name) Modern Mac"; case .aqua: return "\(App.name) Aqua"; case .platinum: return "\(App.name) Classic Mac" }
    }
    private static var cache: Theme?
    static var current: Theme {
        get {
            #if DEBUG
            if let e = ProcessInfo.processInfo.environment["ICQ_THEME"], let t = Theme(rawValue: e) { return t }   // debug builds only
            #endif
            if let c = cache { return c }
            let t = Theme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .classic; cache = t; return t
        }
        set { cache = newValue; UserDefaults.standard.set(newValue.rawValue, forKey: "theme") }
    }
    static var isModern: Bool { current == .modern }
    static var skin: Skin { switch current { case .aqua: return .aqua; case .platinum: return .platinum; default: return .win98 } }
}
enum Skin { case win98, platinum, aqua }

// MARK: native menus / alerts (modern theme)
func nativeMenu(_ items: [RMItem]) -> NSMenu {
    let m = NSMenu(); m.autoenablesItems = false
    for it in items {
        if it.sep { m.addItem(.separator()); continue }
        let mi: NSMenuItem
        if let kids = it.children {
            mi = NSMenuItem(title: brand(it.title), action: nil, keyEquivalent: ""); mi.submenu = nativeMenu(kids)
        } else if it.header {
            mi = NSMenuItem(title: brand(it.title), action: nil, keyEquivalent: ""); mi.isEnabled = false
        } else { mi = MItem(brand(it.title), enabled: it.enabled, fn: it.fn) }
        if it.checked { mi.state = .on }
        if it.bold { mi.attributedTitle = NSAttributedString(string: brand(it.title), attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]) }
        if let ic = it.icon { let i = pic(ic).copy() as! NSImage; i.size = NSSize(width: 16, height: 16); mi.image = i }
        m.addItem(mi)
    }
    return m
}
func nativeAlert(_ title: String, _ text: String, icon: String, buttons: [String]) -> Int {
    let a = NSAlert(); a.messageText = title; a.informativeText = text
    if Theme.isModern { a.icon = NSApp.applicationIconImage } else { a.icon = pic(icon) }
    buttons.forEach { a.addButton(withTitle: $0) }
    let r = a.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    return r
}

// MARK: shared bits
private func flowerImage(_ online: Bool, _ size: CGFloat) -> some View {
    Image(nsImage: pic("logo")).resizable().interpolation(.high).frame(width: size, height: size)
        .saturation(online ? 1 : 0).opacity(online ? 1 : 0.5)
}
private let hhmm: (Date) -> String = { d in let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d) }

struct ModernConnecting: View {
    @State private var p = 0.0
    @State private var done = false
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 10) {
            Text(p > 55 ? "Retrieving contact list…" : "Connecting to \(App.name)…")
            ProgressView(value: min(p, 100), total: 100).frame(width: 240)
        }.padding(20).onReceive(timer) { _ in
            p += Double(7 + Int.random(in: 0..<10))
            if p >= 100 && !done { done = true; WinMgr.shared.close("connect"); ICQ.begin() }
        }
    }
}

// MARK: contact list (modern)
struct ModernMain: View {
    @ObservedObject var s = Store.shared
    @State private var openOn = true
    @State private var openOff = true
    @State private var openIM = true
    @State private var openBots = true
    static let size = CGSize(width: 272, height: 560)
    var body: some View {
        let o = s.opts
        let live = s.contacts.filter(\.isLive).sorted { $0.name.lowercased() < $1.name.lowercased() }
        let bots = s.contacts.filter(\.isBot).sorted { $0.name.lowercased() < $1.name.lowercased() }
        let shown: (Contact) -> Bool = { !$0.isLive && !$0.isBot && !(s.hideDemo && $0.isDemo) }
        let on = s.contacts.filter { shown($0) && s.status != .offline && s.online.contains($0.uin) }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        let off = o.mOffline ? s.contacts.filter { c in shown(c) && !on.contains(c) }.sorted { $0.name.lowercased() < $1.name.lowercased() } : []
        VStack(spacing: 10) {
            if o.mProfile { HStack(spacing: 12) {
                flowerImage(true, 64)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {   // nickname and ID side by side, scaled down to fit
                        Text(s.nick).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text(s.uin).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                    }.minimumScaleFactor(0.75).frame(maxWidth: .infinity, alignment: .leading)
                    Menu {
                        ForEach(Status.allCases, id: \.self) { st in Button(st.menuLabel) { ICQ.setStatus(st) } }
                    } label: {
                        HStack(spacing: 6) {
                            if s.status == .online || s.status == .offline { flowerImage(s.status == .online, 18) } else { Image(nsImage: pic(s.status.rawValue)).interpolation(.none).resizable().frame(width: 18, height: 18) }
                            Text(s.status.panelLabel); Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.menuStyle(.button).frame(maxWidth: .infinity, alignment: .leading)   // same left/right edge as the name line
                }
                Spacer(minLength: 0)
            }.padding(10).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .controlBackgroundColor))).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.75))) }
            if o.mToolbar { HStack(spacing: 6) {
                ForEach(Array([("person.crop.rectangle", "Contacts"), ("text.bubble", "Open message"), ("books.vertical", "Message Archive"), ("list.bullet.rectangle", "Preferences")].enumerated()), id: \.offset) { i, item in
                    Button {
                        switch i {
                        case 1: if let u = s.unread.first(where: { !$0.value.isEmpty })?.key ?? s.selected { ICQ.openSession(u) } else { NSSound.beep() }
                        case 2: ICQ.openArchive()
                        case 3: ICQ.openPrefs(1)
                        default: break
                        }
                    } label: { Image(systemName: item.0).font(.system(size: 18)).frame(maxWidth: .infinity, minHeight: 26) }.help(item.1)
                }
            } }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    group("Online", on.count, $openOn); if openOn { ForEach(on) { row($0, offline: false) } }
                    if o.mIMessage { group("iMessage", live.count, $openIM).padding(.top, 4); if openIM { ForEach(live) { row($0, offline: false) }; if s.bridgeEnabled { Button("Import from Messages…") { ICQ.openMessagesImport() }.buttonStyle(.link).padding(.leading, 22).padding(.vertical, 3) } } }
                    if !bots.isEmpty { group("Robot", bots.count, $openBots).padding(.top, 4); if openBots { ForEach(bots) { row($0, offline: false) } } }
                    if o.mOffline { group("Offline", off.count, $openOff).padding(.top, 4); if openOff { ForEach(off) { row($0, offline: true) } } }
                }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
            }.background(Color(nsColor: .textBackgroundColor)).overlay(Rectangle().stroke(Color(white: 0.7)))
            if o.mButtons { HStack(spacing: 6) {
                bigButton("person.badge.plus", "Add Users") { ICQ.openAdd() }
                bigButton("magnifyingglass", "Find") { ICQ.openFind() }
                bigButton("questionmark.circle.fill", "Help") { ICQ.openAbout() }
            } }
        }.padding(10).frame(width: ModernMain.size.width, height: ModernMain.size.height)
            .onChange(of: s.flash) { _ in ICQ.refreshTray() }
    }
    func group(_ title: String, _ n: Int, _ open: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: open.wrappedValue ? "minus.square" : "plus.square").foregroundColor(.secondary)
            Text("\(title) (\(n))"); Spacer()
        }.padding(.vertical, 3).contentShape(Rectangle()).onTapGesture { open.wrappedValue.toggle() }
    }
    func row(_ c: Contact, offline: Bool) -> some View {
        let pending = !(s.unread[c.uin] ?? []).isEmpty, sel = s.selected == c.uin
        return HStack(spacing: 8) {
            flowerImage(!offline, 22)
            Text(c.name).fontWeight(pending ? .bold : .regular).foregroundColor(offline ? .secondary : .primary)
            if pending { Image(systemName: "envelope.fill").foregroundColor(.blue).opacity(s.flash ? 1 : 0.3) }
            Spacer()
        }.padding(.leading, 22).padding(.vertical, 3).background(sel ? Color.accentColor.opacity(0.35) : Color.clear).contentShape(Rectangle())
            .onTapGesture(count: 2) { ICQ.openSession(c.uin) }
            .simultaneousGesture(TapGesture().onEnded { s.selected = c.uin })   // select at once, do not wait for a possible second click
            .overlay(RightClick { s.selected = c.uin; popMenu([MItem("Send Message") { ICQ.openSession(c.uin) }, MItem("History") { ICQ.openArchive(c.uin) }] + ICQ.contactItems(c) + (c.isBot ? [MItem("AI Assistant Mode", checked: c.isAssistant) { s.toggleAssistant(c.uin) }] : []) + [.separator(), MItem("Delete") { ICQ.confirmDelete(c.uin) }]) })
    }
    func bigButton(_ sym: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) { Image(systemName: sym).font(.system(size: 22)).foregroundColor(.blue); Text(title).font(.caption) }.frame(maxWidth: .infinity, minHeight: 54)
        }
    }
}

// MARK: message session (modern): one window per contact, transcript + input
struct SessionView: View {
    let uin: String
    @ObservedObject var s = Store.shared
    @State private var text: String
    static let size = CGSize(width: 560, height: 460)
    init(uin: String) { self.uin = uin; _text = State(initialValue: Store.shared.aiDrafts[uin] ?? "") }   // an AI draft (never sent by the app) is put into the edit box
    var body: some View {
        let c = s.contact(uin) ?? Contact(name: "?", uin: uin), h = (s.history[uin] ?? []).suffix(300)
        VStack(spacing: 10) {
            ScrollViewReader { p in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(h.enumerated()), id: \.offset) { _, m in
                            let mine = m.dir == "out", col: Color = mine ? .blue : .red
                            VStack(alignment: .leading, spacing: 4) {
                            if !m.text.isEmpty || (m.files ?? []).isEmpty { (Text("[\(hhmm(m.t))] ").foregroundColor(col) + Text(mine ? s.uin : c.name).fontWeight(mine ? .regular : .bold).foregroundColor(col) + Text(": ").foregroundColor(col) + Text(m.text).foregroundColor(.primary))
                                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                            if let f = m.files, !f.isEmpty { if m.text.isEmpty { (Text("[\(hhmm(m.t))] ").foregroundColor(col) + Text(mine ? s.uin : c.name).fontWeight(mine ? .regular : .bold).foregroundColor(col) + Text(":").foregroundColor(col)) }; AttachList(files: f) }
                            }
                        }
                        if s.showReceipts, h.last?.dir == "out", let r = s.receipts[uin] { Text(r).font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .trailing) }
                        Color.clear.frame(height: 1).id("end")
                    }.padding(10)
                }.background(Color(nsColor: .textBackgroundColor)).overlay(Rectangle().stroke(Color(white: 0.7)))
                .onAppear { p.scrollTo("end") }.onChange(of: h.count) { _ in p.scrollTo("end") }
            }
            if s.drafting.contains(uin) { Text("AI is preparing a reply draft…").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            if s.aiDrafts[uin] != nil { Text("AI draft: check and edit it. Nothing is sent until you press Send.").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            HStack(spacing: 8) {
                TextField("", text: $text).textFieldStyle(.roundedBorder).onSubmit(send)
                Button("☺") { text += " :-)" }.help("Insert a smiley")
            }
            HStack { Spacer(); Button("Send", action: send).keyboardShortcut(.defaultAction); Button("Close") { WinMgr.shared.close("sess" + uin) }.keyboardShortcut(.cancelAction) }
        }.padding(12).frame(minWidth: 420, minHeight: 320)
            .onAppear { clear() }.onChange(of: s.history[uin]?.count) { _ in clear() }
            .onChange(of: s.aiDrafts[uin]) { if let d = $0, text.isEmpty { text = d } }
            .onChange(of: text) { [text] new in if new.count != text.count { Sound.play(new.count > text.count ? "msgtype" : "msgback") } }
    }
    func clear() { if s.unread[uin] != nil { s.unread[uin] = nil; ICQ.refreshTray() } }
    func send() {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }
        s.log(uin, "out", v); Sound.play("msgsent"); text = ""; s.botReply(uin); s.aiDrafts[uin] = nil
    }
}

// MARK: about / add users / sounds (modern)
struct ModernAbout: View {
    static let size = CGSize(width: 360, height: 250)
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: pic("logo")).resizable().interpolation(.high).frame(width: 80, height: 80)
            Text(App.name).font(.title.weight(.semibold))
            Text("Version 99b (Build 2569) – Modern Mac theme"); Text("Network connection: coming soon.").foregroundColor(.secondary)
            Text("Spring water, flowing chats.").font(.caption).foregroundColor(.secondary)
            Text("GIF search powered by GIPHY").font(.caption).foregroundColor(.secondary).onTapGesture { NSWorkspace.shared.open(URL(string: "https://giphy.com")!) }
            Button("OK") { WinMgr.shared.close("about") }.keyboardShortcut(.defaultAction).padding(.top, 6)
        }.padding(20).frame(width: ModernAbout.size.width, height: ModernAbout.size.height)
    }
}
struct ModernAdd: View {
    @State private var name = ""
    @State private var uin = ""
    static let size = CGSize(width: 340, height: 210)
    var body: some View {
        let go = { if Store.shared.add(name, uin: uin) != nil { WinMgr.shared.close("add") } }
        VStack(spacing: 12) {
            Form { TextField("Nickname", text: $name).onSubmit(go); TextField("ID (optional)", text: $uin).onSubmit(go) }.formStyle(.columns)
            Text("Dummy entry only – no real user is searched or added.").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            HStack { Spacer(); Button("Cancel") { WinMgr.shared.close("add") }.keyboardShortcut(.cancelAction); Button("Add", action: go).keyboardShortcut(.defaultAction) }
        }.padding(20).frame(width: ModernAdd.size.width, height: ModernAdd.size.height)
    }
}
struct ModernSounds: View {
    @State private var chosen: [String: String] = Dictionary(uniqueKeysWithValues: Sound.defaults.keys.map { ($0, Sound.file(for: $0)) })
    @State private var enabled: [String: Bool] = Dictionary(uniqueKeysWithValues: Sound.defaults.keys.map { ($0, Sound.isOn($0)) })
    static let symbols = ["message": "envelope.fill", "online": "person.crop.circle.badge.checkmark", "chat": "bubble.left.and.bubble.right.fill", "url": "link", "file": "doc.fill", "external": "arrow.up.right.square", "phone": "phone.fill", "contact": "person.fill"]
    static let events: [(String, String)] = [("message", "Message"), ("online", "Online Alert"), ("chat", "Chat"), ("url", "URL"), ("file", "File"), ("external", "External"), ("phone", "Phone"), ("contact", "Contact")]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ModernSounds.events, id: \.0) { ev, label in
                HStack {
                    Image(systemName: ModernSounds.symbols[ev] ?? "speaker.fill").foregroundColor(.accentColor).frame(width: 20)
                    Toggle(label, isOn: Binding(get: { enabled[ev] ?? true }, set: { enabled[ev] = $0; Sound.setOn(ev, $0) })).frame(width: 130, alignment: .leading)
                    Picker("", selection: Binding(get: { chosen[ev] ?? ev }, set: { chosen[ev] = $0; Sound.setFile($0, for: ev) })) {
                        ForEach(SoundsPage.allSounds, id: \.self) { Text($0 + ".wav").tag($0) }
                    }.labelsHidden().frame(width: 200)
                    Button("Test") { Sound.play(chosen[ev] ?? ev) }
                }
            }
            Spacer()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModernAway: View {
    let status: Status
    @State private var msg: String
    static let size = CGSize(width: 380, height: 230)
    init(status: Status) {
        self.status = status
        _msg = State(initialValue: Store.shared.awayText(status))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status message for “\(status.menuLabel)”").font(.headline)
            Text("This message is shown to your contacts while you are in this mode.").font(.caption).foregroundColor(.secondary)
            TextEditor(text: $msg).overlay(Rectangle().stroke(Color(white: 0.7))).frame(height: 90).onChange(of: msg) { Store.shared.awayTexts[status.rawValue] = $0; Store.shared.save() }
            HStack { Spacer(); Button("OK") { WinMgr.shared.close("away") }.keyboardShortcut(.defaultAction) }
        }.padding(16).frame(width: ModernAway.size.width, height: ModernAway.size.height)
    }
}

/// The name the app calls itself (Preferences > My Details). Default "ICQuel".
enum App {
    static var name: String { Store.shared.appName.isEmpty ? "ICQuel" : Store.shared.appName }
}
/// Replaces the product word in built-in strings with the configured app name.
func brand(_ s: String) -> String {
    guard App.name != "ICQ", s.contains("ICQ") else { return s }
    return s.replacingOccurrences(of: "ICQ(?![A-Za-z0-9])", with: NSRegularExpression.escapedTemplate(for: App.name), options: .regularExpression)
}
