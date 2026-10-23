import SwiftUI
import AppKit

// MARK: Add/Find Users = the original "Contact List Wizard" pages 2012 (search) -> 2006 (searching) -> 2018 (concluded)
struct AddWizardView: View {
    @State private var step = 0
    @State private var email = ""
    @State private var nick = ""
    @State private var first = ""
    @State private var last = ""
    @State private var uin = ""
    @State private var group = 1015            // which of the three radio groups is active
    @State private var more = false
    static var pageSize: CGSize { let t = Tpl.load("2012"); return CGSize(width: t.w, height: t.h) }
    static var size: CGSize { CGSize(width: pageSize.width + 16, height: pageSize.height + 62) }

    var found: String? {
        switch group {
        case 1017: return email.contains("@") ? String(email.split(separator: "@")[0]) : nil
        case 1016: return uin.filter(\.isNumber).isEmpty ? nil : App.name + uin.filter(\.isNumber)
        default:
            let n = nick.trimmingCharacters(in: .whitespaces); if !n.isEmpty { return n }
            let f = (first + " " + last).trimmingCharacters(in: .whitespaces); return f.isEmpty ? nil : f
        }
    }
    func next() {
        guard let name = found else { NSSound.beep(); return }
        step = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            Store.shared.add(name, uin: group == 1016 ? uin.filter(\.isNumber) : ""); step = 2
        }
    }
    func reset() { email = ""; nick = ""; first = ""; last = ""; uin = ""; group = 1015; more = false; step = 0 }
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0:
                    DlgView(tpl: Tpl.load("2012"), custom: { c in
                        switch c.id {
                        case 1130: return AnyView(REdit(text: Binding(get: { email }, set: { email = $0; group = 1017 })))
                        case 1131: return AnyView(REdit(text: Binding(get: { nick }, set: { nick = $0; group = 1015 })))
                        case 1132: return AnyView(REdit(text: Binding(get: { first }, set: { first = $0; group = 1015 })))
                        case 1035: return AnyView(REdit(text: Binding(get: { last }, set: { last = $0; group = 1015 })))
                        case 1133: return AnyView(REdit(text: Binding(get: { uin }, set: { uin = $0; group = 1016 })))
                        case 1015, 1016, 1017: return AnyView(DefCtl(c: c, on: group == c.id) { group = c.id })
                        default: return nil
                        }
                    })
                case 1: DlgView(tpl: Tpl.load("2006"), show: [1020])
                default:
                    DlgView(tpl: Tpl.load("2018"), custom: { c in
                        (c.id == 1141 || c.id == 1142) ? AnyView(DefCtl(c: c, on: (c.id == 1141) == more) { more = c.id == 1141 }) : nil
                    })
                }
            }.frame(width: AddWizardView.pageSize.width, height: AddWizardView.pageSize.height, alignment: .topLeading)
            Text("Dummy entry only – no real user is searched or added.").font(rf(10)).foregroundColor(.hint).frame(width: AddWizardView.pageSize.width, alignment: .leading).padding(.bottom, 6)
            HStack(spacing: 6) { Spacer()
                if step == 2 { PushBtn(label: "Finish", isDefault: true) { more ? reset() : WinMgr.shared.close("add") }.frame(width: 70, height: 23) }
                else {
                    PushBtn(label: "< Back") {}.disabled(true).frame(width: 70, height: 23)
                    PushBtn(label: "Next >", isDefault: true, action: next).disabled(step == 1).frame(width: 70, height: 23)
                    PushBtn(label: "Cancel", isCancel: true) { WinMgr.shared.close("add") }.frame(width: 70, height: 23)
                }
            }.padding(.horizontal, 8).padding(.top, 8)
        }.padding(.horizontal, 8).padding(.top, 4)
    }
}

// MARK: Preferences > Sounds = original "Sound Config" page 3036; Select opens a list of all original sound files
struct SoundsPage: View {
    @State private var on: [Int: Bool] = [1035: true, 1019: Sound.isOn("online"), 1053: Sound.isOn("message"), 1020: Sound.isOn("chat"), 1021: Sound.isOn("url"), 1030: Sound.isOn("file"), 1022: Sound.isOn("external"), 1026: Sound.isOn("phone"), 1027: Sound.isOn("contact"), 1550: false, 1081: false]
    static let toggles: [Int: String] = [1019: "online", 1053: "message", 1020: "chat", 1021: "url", 1030: "file", 1022: "external", 1026: "phone", 1027: "contact"]
    @State private var chosen: [String: String] = Dictionary(uniqueKeysWithValues: Sound.defaults.keys.map { ($0, Sound.file(for: $0)) })
    // event -> (edit id, select id, test id)
    static let rows: [String: (Int, Int, Int)] = ["online": (1015, 1050, 1051), "message": (1054, 1055, 1056), "chat": (1058, 1059, 1060), "url": (1062, 1063, 1064),
                                                  "file": (1066, 1067, 1068), "external": (1070, 1071, 1072), "phone": (1074, 1075, 1076), "contact": (1077, 1078, 1079)]
    static var allSounds: [String] {
        Assets.soundNames()
    }
    static var size: CGSize { let t = Tpl.load("3036"); return CGSize(width: t.w, height: t.h) }
    var body: some View {
        var texts: [Int: String] = [1036: "usermsg.wav", 1081: "Play the User ID sound before the Online Alert sound"]
        for (ev, r) in SoundsPage.rows { texts[r.0] = (chosen[ev] ?? "") + ".wav" }
        return DlgView(tpl: Tpl.load("3036"), hidden: [1, 2], texts: texts, custom: { c in
            for (ev, r) in SoundsPage.rows {
                if c.id == r.2 { return AnyView(PushBtn(label: "Test") { Sound.play(chosen[ev] ?? ev) }) }
                if c.id == r.1 {
                    return AnyView(PushBtn(label: "Select") {
                        popMenu(SoundsPage.allSounds.map { n in MItem(n + ".wav", checked: chosen[ev] == n) { chosen[ev] = n; Sound.setFile(n, for: ev); Sound.play(n) } })
                    })
                }
            }
            if c.id == 1038 { return AnyView(PushBtn(label: "Test") { Sound.play(Sound.file(for: "message")) }) }
            if c.id == 1037 || c.id == 1046 { return AnyView(PushBtn(label: clean(c.text)) { notice("Not available in the local demo.") }) }
            if on[c.id] != nil { return AnyView(DefCtl(c: c, on: on[c.id] ?? false) { on[c.id]?.toggle(); if let ev = SoundsPage.toggles[c.id] { Sound.setOn(ev, on[c.id] ?? true) } }) }
            return nil
        })
    }
}

// MARK: Preferences > Security = original page 3018
struct SecurityPage: View {
    @State private var auth = 1364
    @State private var level = 1009
    @State private var pw1 = ""
    @State private var pw2 = ""
    @State private var save = false
    static var size: CGSize { let t = Tpl.load("3018"); return CGSize(width: t.w, height: t.h) }
    var body: some View {
        DlgView(tpl: Tpl.load("3018"), custom: { c in
            switch c.id {
            case 1364, 1365: return AnyView(DefCtl(c: c, on: auth == c.id) { auth = c.id })
            case 1007, 1008, 1009: return AnyView(DefCtl(c: c, on: level == c.id) { level = c.id })
            case 1366: return AnyView(REdit(text: $pw1, secure: true))
            case 1367: return AnyView(REdit(text: $pw2, secure: true))
            case 1368: return AnyView(DefCtl(c: c, on: save) { save.toggle() })
            default: return nil
            }
        })
    }
}

// MARK: New / edit AI chatbot
struct BotView: View {
    let uin: String?          // nil = new bot
    @State private var nick: String
    @State private var persona: String
    @State private var assistant: Bool
    @State private var initiative: Bool
    @State private var preset: String
    init(uin: String?) {
        self.uin = uin
        let c = uin.flatMap { Store.shared.contact($0) }
        _nick = State(initialValue: c?.name ?? ""); _persona = State(initialValue: c?.persona ?? "")
        _assistant = State(initialValue: c?.isAssistant ?? false); _initiative = State(initialValue: c?.startsChats ?? true)
        _preset = State(initialValue: c?.preset ?? (uin == nil ? "friend" : "custom"))
    }
    static let size = CGSize(width: 380, height: 500)
    var id: String { "bot" + (uin ?? "new") }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nickname:"); RField(text: $nick)
            Text("Preset:").padding(.top, 6)
            RButton(title: Presets.title(preset) + "   ▾", minWidth: 200) {
                popRMenu(Presets.all.map { p in RMItem(title: p.title, checked: p.id == preset, fn: { preset = p.id }) })
            }
            Text(Presets.blurb(preset)).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
            Text("Additional description (optional – it supplements the preset and wins on conflicts):").fixedSize(horizontal: false, vertical: true).padding(.top, 6)
            RText(text: $persona).frame(height: 100)
            RCheck(title: "Act as a normal AI assistant (complete answers)", on: $assistant).padding(.top, 6)
            RCheck(title: "Starts conversations on its own", on: $initiative)
            Text("When chatting, the instant-messenger context (short chat-style replies) is added to your text automatically.")
                .foregroundColor(.hint).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            Spacer(minLength: 0)
            HStack { Spacer()
                RButton(title: "OK", isDefault: true) {
                    let n = nick.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { NSSound.beep(); return }
                    if let u = uin { Store.shared.editBot(u, name: n, persona: persona, assistant: assistant, initiative: initiative, preset: preset) } else { Store.shared.addBot(n, persona: persona, assistant: assistant, initiative: initiative, preset: preset) }
                    WinMgr.shared.close(id)
                }
                RButton(title: "Cancel") { WinMgr.shared.close(id) }
            }
        }.padding(10)
    }
}

// MARK: Edit Contact: nickname, e-mail ("Send Mail") and phone number (FaceTime)
struct ContactEditView: View {
    let uin: String
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var autoReply: Bool
    static let size = CGSize(width: 360, height: 290)
    init(uin: String) {
        self.uin = uin; let c = Store.shared.contact(uin)
        _name = State(initialValue: c?.name ?? ""); _email = State(initialValue: c?.email ?? ""); _phone = State(initialValue: c?.phone ?? ""); _autoReply = State(initialValue: c?.autoReply ?? false)
    }
    var body: some View {
        let c = Store.shared.contact(uin)
        VStack(alignment: .leading, spacing: 6) {
            Text("Nickname:"); RField(text: $name)
            Text("E-mail (\"Send Mail…\" opens your mail app):"); RField(placeholder: c?.bridge.flatMap { $0.contains("@") ? $0 : nil } ?? "name@example.com", text: $email)
            Text("Phone (FaceTime Video / Audio):"); RField(placeholder: c?.bridge.flatMap { $0.contains("@") ? nil : $0 } ?? "+49 151 1234567", text: $phone)
            if let b = c?.bridge { Text("iMessage address: \(b) (used when the fields stay empty)").foregroundColor(.hint).font(rf(10)).fixedSize(horizontal: false, vertical: true) }
            if c?.isLive == true { RCheck(title: "Allow auto-reply when I am away (needs Auto-reply on in Preferences > Bridge)", on: $autoReply) }
            Spacer(minLength: 0)
            HStack { Spacer()
                RButton(title: "Cancel") { WinMgr.shared.close("edit" + uin) }
                RButton(title: "OK", isDefault: true) {
                    let s = Store.shared
                    if let i = s.contacts.firstIndex(where: { $0.uin == uin }) {
                        let n = name.trimmingCharacters(in: .whitespaces); if !n.isEmpty { s.contacts[i].name = n }
                        s.contacts[i].email = email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces)
                        s.contacts[i].phone = phone.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phone.trimmingCharacters(in: .whitespaces)
                        s.contacts[i].autoReply = autoReply ? true : nil
                        s.save()
                    }
                    WinMgr.shared.close("edit" + uin)
                }
            }
        }.padding(14).frame(width: ContactEditView.size.width, height: ContactEditView.size.height, alignment: .topLeading)
    }
}

// MARK: Import from Messages: pick recent iMessage conversations instead of typing every contact
final class ConvModel: ObservableObject {
    @Published var convs: [Bridge.Conversation] = []
    @Published var names: [String: String] = [:]
    @Published var picked = Set<String>()
    @Published var state = "Not loaded yet."
    private let s = Store.shared
    func known(_ h: String) -> Bool { s.contacts.contains { $0.bridge.map { Bridge.same($0, h) || $0 == h } ?? false } }
    func load() {
        state = "Reading Messages…"
        DispatchQueue.global(qos: .userInitiated).async {
            let list = Bridge.conversations(limit: 15)
            DispatchQueue.main.async {
                self.convs = list; self.picked = Set(list.prefix(5).filter { !self.known($0.handle) }.map(\.handle))
                if list.isEmpty { self.state = Bridge.checkAccess() == .ok ? "No conversations found." : "Messages cannot be read yet. Give this app Full Disk Access first, restart it and load again." }
                let mine = self.s.contacts.compactMap(\.bridge)
                Bridge.names(for: list.map(\.handle) + mine) { n in DispatchQueue.main.async {
                    self.names = n
                    // contacts added earlier under their number / address get the real name now
                    func bare(_ t: String) -> Bool { t.contains("@") || t.filter(\.isNumber).count >= 6 && t.filter(\.isLetter).isEmpty }
                    for i in self.s.contacts.indices { if let h = self.s.contacts[i].bridge, bare(self.s.contacts[i].name), let nm = n.first(where: { Bridge.same($0.key, h) || $0.key == h })?.value { self.s.contacts[i].name = nm } }
                    self.s.save()
                } }
            }
        }
    }
    func importPicked() {
        for c in convs where picked.contains(c.handle) && !known(c.handle) { _ = s.addBridgeContact(names[c.handle] ?? c.handle, handle: c.handle) }
        if !picked.isEmpty && !s.bridgeEnabled { s.bridgeEnabled = true; s.save(); s.startBridge() }
    }
}
/// The tick list of recent conversations (used by the import window and the setup assistant).
struct ConvList: View {
    @ObservedObject var m: ConvModel
    var body: some View {
        Sunken { ScrollView { VStack(alignment: .leading, spacing: 5) {
            if m.convs.isEmpty { Text(m.state).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
            ForEach(m.convs, id: \.handle) { c in
                VStack(alignment: .leading, spacing: 1) {
                    RCheck(title: (m.names[c.handle] ?? c.handle) + (m.names[c.handle] == nil ? "" : "  (\(c.handle))") + (m.known(c.handle) ? "  – already added" : ""),
                           on: Binding(get: { m.picked.contains(c.handle) }, set: { if $0 { m.picked.insert(c.handle) } else { m.picked.remove(c.handle) } }))
                    Text(c.last).font(rf(10)).foregroundColor(.hint).lineLimit(1).padding(.leading, 24)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .topLeading).padding(8) } }
    }
}
struct MessagesImportView: View {
    static let size = CGSize(width: 440, height: 480)
    @StateObject private var m = ConvModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose the conversations to show as contacts. Only the ones you tick are used; the last 5 messages of each are loaded into its history.").fixedSize(horizontal: false, vertical: true)
            ConvList(m: m).frame(maxHeight: .infinity)
            HStack {
                RButton(title: "Select all") { m.picked = Set(m.convs.filter { !m.known($0.handle) }.map(\.handle)) }
                RButton(title: "None") { m.picked = [] }
                Spacer()
                RButton(title: "Cancel") { WinMgr.shared.close("msgimport") }
                RButton(title: "Import", isDefault: true) { m.importPicked(); WinMgr.shared.close("msgimport") }.disabled(m.picked.isEmpty)
            }
        }.padding(14).frame(width: MessagesImportView.size.width, height: MessagesImportView.size.height, alignment: .topLeading).onAppear { m.load() }
    }
}
