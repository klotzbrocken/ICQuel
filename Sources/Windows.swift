import SwiftUI
import AppKit

let stamp: (Date) -> String = { d in
    let f = DateFormatter(); f.dateFormat = "dd/MM/yy HH:mm"; return f.string(from: d)
}

// MARK: send / incoming / archive
struct HistoryText: View {
    let uin: String; @ObservedObject var s = Store.shared
    var body: some View {
        let name = s.contact(uin)?.name ?? "?"
        Sunken {
            ScrollViewReader { p in
                ScrollView { VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array((s.history[uin] ?? []).suffix(30).enumerated()), id: \.offset) { _, m in
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(m.dir == "in" ? name : s.nick) (\(stamp(m.t))):").font(rf(bold: true)); if !m.text.isEmpty { Text(m.text) }; if let f = m.files, !f.isEmpty { AttachList(files: f, maxW: 200) }
                        }
                    }
                    if s.showReceipts, s.history[uin]?.last?.dir == "out", let r = s.receipts[uin] { Text(r).font(rf(10)).foregroundColor(.hint).frame(maxWidth: .infinity, alignment: .trailing) }
                    Color.clear.frame(height: 1).id("end")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4) }
                .onAppear { p.scrollTo("end") }.onChange(of: s.history[uin]?.count) { _ in p.scrollTo("end") }
            }
        }
    }
}
struct ContactHeader: View {
    let c: Contact; @ObservedObject var s = Store.shared
    var body: some View {
        HStack(spacing: 8) {
            Pix(name: s.online.contains(c.uin) ? "online" : "offline", w: 32)
            VStack(alignment: .leading) { Text(c.name).font(rf(bold: true)); Text("ICQ#: \(c.uin)") }
            Spacer()
        }
    }
}
struct ArchiveView: View {
    @State var cur: String?; @ObservedObject var s = Store.shared
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Sunken { ScrollView { VStack(spacing: 0) {
                    ForEach(s.contacts) { c in
                        Text(c.name).lineLimit(1).foregroundColor(cur == c.uin ? .white : Color.ink).padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading).background(cur == c.uin ? Color.navy : Color.clear)
                            .contentShape(Rectangle()).onTapGesture { cur = c.uin }
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading) } }.frame(width: 140)
                if let cur, s.contact(cur) != nil {
                    if (s.history[cur] ?? []).isEmpty { Sunken { Text("No messages.").padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) } }
                    else { HistoryText(uin: cur) }
                } else { Sunken { Text("Select a contact.").padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) } }
            }
            HStack { Spacer(); RButton(title: "Close", isDefault: true) { WinMgr.shared.close("archive") } }
        }.padding(8)
    }
}
struct PrefsView: View {
    @ObservedObject var s = Store.shared
    @State var tab: Int
    @State private var nick = Store.shared.nick
    @State private var uin = Store.shared.uin
    @State private var sounds = Store.shared.sounds
    @State private var enabled = Store.shared.freqEnabled
    @State private var mode = Store.shared.freqMode
    @State private var mins = String(Store.shared.minutes)
    @State private var first = Store.shared.demoFirst
    @State private var autoAway = Store.shared.autoAway
    @State private var draftIM = Store.shared.aiDraftIMessage
    @State private var autoAddIM = Store.shared.bridgeAutoAdd
    @State private var replyText = Store.shared.autoReplyText
    @State private var autoMin = String(Store.shared.autoAwayMin)
    @State private var autoDND = Store.shared.autoAwayDND
    @State private var key = Store.shared.apiKey
    @State private var ai = Store.shared.aiEnabled
    @State private var showKey = false
    @State private var newName = ""
    @State private var model = Store.shared.apiModel
    @State private var fda = ""
    @State private var skipApply = false
    @State private var pending: DispatchWorkItem?
    @State private var botSel: String?
    @State private var scaleChoice = UI.scale
    @State private var bridgeOn = Store.shared.bridgeEnabled
    @State private var bridgeName = ""
    @State private var bridgeHandle = ""
    @State private var bridgeSel: String?
    @State private var appNameDraft = Store.shared.appName
    @State private var opts = Store.shared.opts
    @State private var botInit = Store.shared.botInit
    @State private var botMinS = String(Store.shared.botMin)
    @State private var botMaxS = String(Store.shared.botMax)
    @State private var themeChoice = Assets.currentChoiceId()
    @State private var themeMsg = ""
    @State private var optModern = Theme.isModern
    @State private var bridgeMsg = ""
    /// Retro window height per page, so there are no large empty grey areas.
    static let heights: [Int: CGFloat] = [0: 375, 1: 440, 2: 480, 3: 470, 4: 530, 5: 720, 6: 520, 7: 400, 8: 620]
    static let icons: [(String, Color)] = [("person.crop.circle.fill", .blue), ("person.2.fill", .green), ("tray.and.arrow.down.fill", .orange), ("text.bubble.fill", .teal), ("speaker.wave.2.fill", .pink),
                                           ("lock.fill", .gray), ("sparkles", .purple), ("macwindow", .indigo), ("message.badge.filled.fill", Color(red: 0.2, green: 0.78, blue: 0.35))]
    /// The first page grows with the number of installed themes (+ room for the fan-made note).
    static func height(_ t: Int) -> CGFloat { t == 0 ? 380 + CGFloat(max(0, Assets.choices().count - 4)) * 17 + 45 : (heights[t] ?? 520) }
    static let pages = ["My Details", "Contact List", "Incoming", "Messages", "Sounds", "Privacy", "AI Chat", "Main Window", "Bridge"]
    var body: some View {
        (Theme.isModern ? AnyView(modernBody) : AnyView(classicBody))
            .onAppear { if !s.keyLoaded { s.loadKeyAsync { s.refreshModels() } } else if s.modelList[s.aiProvider.rawValue] == nil { s.refreshModels() }; fda = Bridge.checkAccess() == .ok ? "granted" : "not granted yet" }
            .onChange(of: stateKey) { _ in schedule() }
            .onChange(of: s.aiProvider) { _ in key = ""; model = s.apiModel; s.refreshModels() }
            .onDisappear { pending?.cancel(); if !skipApply { apply() } }
            .onChange(of: tab) { t in if !Theme.isModern { WinMgr.shared.resize("prefs", 600, PrefsView.height(t)) } }
            .onChange(of: s.apiKey) { if key.isEmpty { key = $0 } }
    }
    /// Everything the user can change on the pages: any change is applied after a short pause (no OK / Apply).
    var stateKey: String { [nick, uin, "\(sounds)", "\(enabled)", "\(mode)", mins, "\(first)", "\(autoAway)", "\(draftIM)", "\(autoAddIM)", replyText, autoMin, "\(autoDND)", key, "\(ai)", model, "\(bridgeOn)", appNameDraft, "\(opts)", "\(botInit)", botMinS, botMaxS, themeChoice, "\(scaleChoice)"].joined(separator: "\u{1}") }
    func schedule() {
        pending?.cancel()
        let w = DispatchWorkItem { apply() }; pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: w)
    }
    var modernBody: some View {
        let visible = [0, 1, 2, 3, 4, 5, 7, 6, 8]
        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    ForEach(visible, id: \.self) { i in
                        Button { tab = i } label: {
                            HStack(spacing: 8) {
                                ZStack { RoundedRectangle(cornerRadius: 6).fill(PrefsView.icons[i].1); Image(systemName: PrefsView.icons[i].0).font(.system(size: 12, weight: .semibold)).foregroundColor(.white) }.frame(width: 24, height: 24)
                                Text(PrefsView.pages[i]); Spacer(minLength: 0)
                            }.padding(.vertical, 4).padding(.horizontal, 6)
                                .background(tab == i ? Color.accentColor.opacity(0.85) : Color.clear).foregroundColor(tab == i ? .white : .primary).cornerRadius(7).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }.frame(width: 130)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ZStack { RoundedRectangle(cornerRadius: 8).fill(PrefsView.icons[tab].1); Image(systemName: PrefsView.icons[tab].0).font(.system(size: 16, weight: .semibold)).foregroundColor(.white) }.frame(width: 32, height: 32)
                        Text(PrefsView.pages[tab]).font(.system(size: 20, weight: .semibold))
                    }.padding(.horizontal, 10)
                    Group {
                        if tab == 4 { ModernSounds().padding(.horizontal, 10) } else { ScrollView { Page { pageBody } } }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            HStack {
                RButton(title: "Restore Defaults", minWidth: 120, action: restore)
                Spacer()
                RButton(title: "Close", isDefault: true) { WinMgr.shared.close("prefs") }
            }
        }.padding(16).frame(width: 760, height: 540)
    }
    var classicBody: some View {
        VStack(spacing: 0) {
            WTabs(rows: [[0, 1, 2, 3], [4, 5, 7, 6, 8]], titles: PrefsView.pages, width: 584, sel: $tab)
            Group {
                switch tab {
                case 4: SoundsPage().padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Color.gray98).overlay(Bevel())
                default: Page { ScrollView { VStack(alignment: .leading, spacing: 4) { pageBody }.frame(maxWidth: .infinity, alignment: .topLeading) } }   // long pages scroll: OK / Cancel / Apply stay visible
                }
            }.padding(.top, -1)
            HStack {
                RButton(title: "Restore All Defaults", minWidth: 150, action: restore)
                Spacer()
                RButton(title: "Close", isDefault: true) { WinMgr.shared.close("prefs") }
            }.padding(.top, 8)
        }.padding(8)
    }
    func restore() {
        s.freqEnabled = true; s.freqMode = .hour; s.minutes = 15; s.demoFirst = true; s.sounds = true; s.opts = MainOpts(); ICQ.applyMainOptions(); s.save()
        UserDefaults.standard.removeObject(forKey: "snd_files"); UserDefaults.standard.removeObject(forKey: "snd_message"); for e in Sound.defaults.keys { UserDefaults.standard.removeObject(forKey: "snd_on_" + e) }
        s.resetSched(); skipApply = true; let t = tab; WinMgr.shared.close("prefs"); ICQ.openPrefs(t)
    }
    func note(_ t: String) -> some View { Text(t).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
    @ViewBuilder var pageBody: some View {
        switch tab {
        case 0:
            HStack(alignment: .top, spacing: 8) {
                RGroup(title: "My Details") { Text("Nickname:"); RField(text: $nick); Text("ICQ#:").padding(.top, 2); RField(text: $uin) }
                VStack(alignment: .leading, spacing: 6) {
                    RGroup(title: "Application name") { RField(text: $appNameDraft); Text("Shown in menus and window titles. Default: ICQuel.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
                    RCheck(title: "Play sounds", on: $sounds)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                RGroup(title: "Theme") {
                    ForEach(Assets.choices()) { ch in RRadio(title: ch.title, on: themeChoice == ch.id) { themeChoice = ch.id } }
                    HStack(spacing: 6) {
                        RButton(title: "Import Theme…", minWidth: 100) { importTheme() }
                        if themeChoice.hasPrefix("pack:") { RButton(title: "Remove", minWidth: 60) { Assets.removePack(id: String(themeChoice.dropFirst(5))); themeChoice = Assets.currentChoiceId(); AppDelegate.rebuildMenu() } }
                    }.padding(.top, 2)
                    if let a = Assets.installed().first(where: { "pack:" + $0.pack.id == themeChoice }), a.pack.isFanMade { Text("Fan Made Theme: made by fans, not affiliated with or endorsed by the owners of the original software or its trademarks.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
                    if !themeMsg.isEmpty { Text(themeMsg).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
                }
                if !Theme.isModern {
                    RGroup(title: "Window size (Classic)") {
                        RRadio(title: "Original (1.0x)", on: scaleChoice == 1) { scaleChoice = 1 }
                        RRadio(title: "Comfortable (1.05x, default)", on: scaleChoice == 1.05) { scaleChoice = 1.05 }
                        RRadio(title: "Large (1.5x)", on: scaleChoice == 1.5) { scaleChoice = 1.5 }
                        RRadio(title: "Extra large (2.0x)", on: scaleChoice == 2) { scaleChoice = 2 }
                    }
                }
            }.padding(.top, 4)
            Text("Network connection: coming soon.").foregroundColor(.hint).padding(.top, 4)
        case 1:
            RCheck(title: "Hide demo contacts (the made-up sample friends)", on: Binding(get: { s.hideDemo }, set: { s.hideDemo = $0; s.save() }))
            Text("Name list:")
            Sunken { ScrollView { VStack(spacing: 0) {
                ForEach(s.contacts) { c in
                    HStack(spacing: 4) { Pix(name: "online", w: 16); Text("\(c.name)  (\(c.uin))").foregroundColor(s.selected == c.uin ? .white : Color.ink); Spacer() }
                        .padding(.horizontal, 4).frame(height: 18).background(s.selected == c.uin ? Color.navy : Color.clear)
                        .contentShape(Rectangle()).onTapGesture { s.selected = c.uin }
                }
            }.frame(maxWidth: .infinity, alignment: .topLeading) } }.frame(height: 260)
            HStack {
                RField(placeholder: "Nickname", text: $newName, onSubmit: addName)
                RButton(title: "Add", action: addName)
                RButton(title: "Remove") { if let u = s.selected, s.contact(u) != nil { s.remove(u) } }
            }
        case 2:
            RCheck(title: "Receive simulated incoming messages", on: $enabled)
            RGroup(title: "Frequency") {
                RRadio(title: "1 – 3 times per hour (random)", on: mode == .hour) { mode = .hour }
                HStack(spacing: 5) { RRadio(title: "Every", on: mode == .interval) { mode = .interval }
                    RField(text: $mins).frame(width: 60); Text("minutes") }.padding(.top, 4)
            }.padding(.top, 6)
            RCheck(title: "Send a first message 10 seconds after start", on: $first)
            RButton(title: "Receive one now", minWidth: 130) { s.deliver() }.padding(.top, 6)
            RGroup(title: "Status when I am away from the keyboard") {
                RCheck(title: "Switch my status automatically when I do not use the Mac", on: $autoAway)
                HStack(spacing: 5) { Text("after"); RField(text: $autoMin).frame(width: 50); Text("minutes to") }
                HStack(spacing: 14) { RRadio(title: "Away", on: !autoDND) { autoDND = false }; RRadio(title: "Do Not Disturb", on: autoDND) { autoDND = true } }
                Text("Tip: link a macOS Focus to the status. Shortcuts > Automation > Focus > Open URL: icquel://status/dnd (and icquel://status/online when it ends). Also available: away, na, occupied, ffc, invisible, offline.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
                Text("While Away, N/A, Occupied or Do Not Disturb is set, no sample messages and no chatbot messages arrive (not even silently). Real iMessages still do. The status switches back when you use the Mac again.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 8)
        case 3:
            Text("Sample messages (\(dummyMessages.count)) – delivered at random:")
            Sunken { ScrollView { VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(dummyMessages.enumerated()), id: \.offset) { i, m in
                    Text("\(i + 1). \(m)").padding(.horizontal, 8).padding(.vertical, 3).frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(Rectangle().fill(Color.gray98).frame(height: 1), alignment: .bottom)
                }
            }.padding(.vertical, 3) } }.frame(height: 330)
        case 5:
            RGroup(title: "Reading messages and attachments (Full Disk Access)") {
                note("ICQuel reads the Messages database and its attachment folder read-only. macOS only allows this with Full Disk Access. Only the conversations you import are shown; nothing is copied anywhere or sent to a server.")
                Text("Status: " + (fda.isEmpty ? "…" : fda)).foregroundColor(.hint)
                HStack {
                    RButton(title: "1. Full Disk Access…", minWidth: 130) { _ = Bridge.checkAccess(); Bridge.openPrivacySettings() }
                    RButton(title: "Show app in Finder", minWidth: 120) { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
                    RButton(title: "Check", minWidth: 60) { fda = Bridge.checkAccess() == .ok ? "granted" : "not granted yet" }
                }
                note("If the app is not in the list: click \u{201C}Show app in Finder\u{201D}, drag the app into the list (or use +) and switch it on. Restart the app afterwards.")
            }
            RGroup(title: "Sending and other apps (Automation)") {
                note("Sending, replies and attachments go through the Messages app. \u{201C}New Reminder\u{201D} and \u{201C}New ToDo\u{201D} use Reminders and Notes. macOS asks once per app.")
                HStack {
                    RButton(title: "2. Allow Messages control", minWidth: 150) { Bridge.requestAutomation { msg in bridgeMsg = msg } }
                    RButton(title: "Check again") { s.bridgeEnabled = bridgeOn; s.startBridge() }
                }
                if !bridgeMsg.isEmpty { note(bridgeMsg) }
            }.padding(.top, 6)
            RGroup(title: "iMessage chats") {
                RCheck(title: "Show group chats (import them from Messages)", on: Binding(get: { s.showGroups }, set: { s.showGroups = $0; s.save() }))
                note("Group messages appear in the group's own chat, never inside a person's chat. Auto-reply and AI drafts never run in groups.")
                RCheck(title: "Show delivered / read status under my last message", on: Binding(get: { s.showReceipts }, set: { s.showReceipts = $0; s.save() })).padding(.top, 4)
                note("Read from the Messages database on this Mac; nobody is told anything.")
            }.padding(.top, 6)
            RGroup(title: "AI service and key") {
                HStack(spacing: 6) {
                    Text("Service:")
                    RButton(title: s.aiProvider.title + "   \u{25BE}", minWidth: 190) { popRMenu(AIProvider.allCases.map { p in RMItem(title: p.title, checked: s.aiProvider == p, fn: { s.switchProvider(p) }) }) }
                }
                RField(placeholder: s.aiProvider.keyPlaceholder, text: $key, secure: !showKey).padding(.top, 4)
                RCheck(title: "Show key", on: $showKey).padding(.top, 2)
                if !s.keyStatus.isEmpty { note(s.keyStatus) }
                note("The key is stored in your macOS Keychain. Text leaves your Mac only when you use a chatbot or one of the AI features below, and only goes to the service you picked.")
            }.padding(.top, 6)
            RGroup(title: "AI features that read your chats") {
                RCheck(title: "Prepare replies to iMessages (AI draft, never sent)", on: Binding(get: { draftIM }, set: { v in
                    if !v { draftIM = false; return }
                    retroBox("Prepare iMessage replies?", "When a real iMessage arrives, the text of that chat (the latest messages) is sent to the Anthropic API with your key, and the AI writes a reply DRAFT. The draft only appears in the reply window; nothing is ever sent to your contact unless you press Send yourself.\n\nDo you really want this?", icon: "question32", buttons: ["Yes, enable", "Cancel"]) { if $0 == 0 { draftIM = true } }
                }))
                Text("Only for iMessage contacts. You always review and send the text yourself.").foregroundColor(.hint)
                RCheck(title: "Summarize what I missed when I am back (Away / DND ends)", on: Binding(get: { s.aiSummary }, set: { v in
                    if !v { s.aiSummary = false; s.save(); return }
                    retroBox("Summarize missed messages?", s.aiLocal ? "When your Away / DND status ends, the AI writes one line per unread iMessage chat. This runs on your Mac." : "When your Away / DND status ends, the unread iMessages are sent to the Anthropic API with your key and the AI writes one line per chat.\n\nDo you really want this?", icon: "question32", buttons: ["Yes, enable", "Cancel"]) { if $0 == 0 { s.aiSummary = true; s.save() } }
                }))
                if LocalAI.available {
                    RCheck(title: "Use Apple's on-device model for drafts, translation, summaries and auto-replies (private, no API key)", on: Binding(get: { s.aiLocal }, set: { s.aiLocal = $0; AIChat.useLocal = $0; s.save() }))
                } else {
                    Text("On-device model (Apple Intelligence): not available on this Mac yet (\(LocalAI.status)).").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
                }
                note("Chatbots only see their own conversation. Drafts and summaries are never sent to a contact. These features need AI Chat to be enabled.")
            }.padding(.top, 6)
            RGroup(title: "Automatic reply while I am away") {
                RCheck(title: "Reply automatically to iMessages while my status is Away, N/A, Occupied or DND", on: Binding(get: { s.autoReplyOn }, set: { v in
                    if !v { s.autoReplyOn = false; s.save(); return }
                    retroBox("Send automatic replies?", "While your status is Away, N/A, Occupied or Do Not Disturb, ICQuel sends the reply text below by iMessage, in your name, to contacts that you marked with \"Allow auto-reply\" (right-click a contact > Edit Contact). One reply per contact every 6 hours, only in one-to-one iMessage chats.\n\nDo you really want ICQuel to send messages on its own?", icon: "question32", buttons: ["Yes, enable", "Cancel"]) { if $0 == 0 { s.autoReplyOn = true; s.save() } }
                }))
                Text("Reply text:"); RText(text: $replyText).frame(height: 44)
                if s.aiEnabled { RCheck(title: "Let the AI write the reply (it only says that I cannot answer now)", on: Binding(get: { s.autoReplyAI }, set: { s.autoReplyAI = $0; s.save() })) }
                Text("Nobody gets a reply unless you ticked \"Allow auto-reply\" for that contact.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 4)
            RGroup(title: "Other network use") {
                note("The GIF search sends your search words to Giphy. Update checks contact GitHub (Sparkle). Nothing else connects to the internet.")
            }.padding(.top, 6)
        case 8:
            RCheck(title: "Enable the Messages bridge (iMessage through the Messages app of this Mac)", on: $bridgeOn)
            Text("Status: " + (bridgeOn ? s.bridgeStatus : "Off")).foregroundColor(.hint).padding(.top, 2)
            RCheck(title: "Also show new iMessages from people I have not imported yet (adds them as contacts)", on: $autoAddIM)
            Text("Off by default: then only the conversations you import are read.").foregroundColor(.hint)
            note("Permissions (Full Disk Access, Messages control) are in Preferences > Privacy. Only the contacts listed below are read; nothing else is read, stored or sent.")
            RButton(title: "Import from Messages…", minWidth: 170) { ICQ.openMessagesImport() }.padding(.top, 2)
            RGroup(title: "Connected iMessage contacts") {
                Sunken { ScrollView { VStack(spacing: 0) {
                    ForEach(s.contacts.filter(\.isLive)) { c in
                        HStack(spacing: 4) { Pix(name: "online", w: 16); Text("\(c.name)  (\(c.bridge ?? ""))").foregroundColor(bridgeSel == c.uin ? .white : Color.ink); Spacer() }
                            .padding(.horizontal, 4).frame(height: 18).background(bridgeSel == c.uin ? Color.navy : Color.clear)
                            .contentShape(Rectangle()).onTapGesture { bridgeSel = c.uin }
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading) } }.frame(height: 90)
                HStack {
                    RField(placeholder: "Name", text: $bridgeName).frame(width: 110)
                    RField(placeholder: "Phone number or e-mail", text: $bridgeHandle)
                    RButton(title: "Add", minWidth: 50) { if s.addBridgeContact(bridgeName, handle: bridgeHandle) != nil { bridgeName = ""; bridgeHandle = "" } }
                    RButton(title: "Remove", minWidth: 60) { if let u = bridgeSel { s.remove(u); bridgeSel = nil } }
                }
            }.padding(.top, 6)
        case 7:
            HStack(spacing: 6) {
                Text("Settings for theme:")
                RButton(title: (optModern ? "Modern Mac" : "Retro") + "   ▾", minWidth: 140) { popRMenu([RMItem(title: "Retro", checked: !optModern, fn: { optModern = false }), RMItem(title: "Modern Mac", checked: optModern, fn: { optModern = true })]) }
            }
            if !optModern {
                RGroup(title: "Window") {
                    RCheck(title: "Show tabs (All / User)", on: $opts.tabs)
                    RCheck(title: "Show search bar", on: $opts.search)
                    RCheck(title: "Show the \"Now!\" button", on: $opts.icqNow)
                    RCheck(title: "Show the \"Services\" button", on: $opts.services)
                    RCheck(title: "Keep the window on top of other windows", on: $opts.alwaysOnTop)
                }
                RGroup(title: "Contact list") {
                    RCheck(title: "Show offline contacts", on: $opts.showOffline)
                    RCheck(title: "Hide demo contacts (the made-up sample friends)", on: Binding(get: { s.hideDemo }, set: { s.hideDemo = $0; s.save() }))
                    RCheck(title: "Show the iMessage group", on: $opts.showIMessage)
                    RCheck(title: "Show \"Instructions\"", on: $opts.btnInstructions)
                    RCheck(title: "Show \"Find Random Chat Partner\"", on: $opts.btnRandom)
                    RCheck(title: "Show \"Website\"", on: $opts.btnWeb)
                    RCheck(title: "Show \"Cool Links\"", on: $opts.btnCool)
                }.padding(.top, 6)
            } else {
                RGroup(title: "Window") {
                    RCheck(title: "Show the profile box (name, ID, status)", on: $opts.mProfile)
                    RCheck(title: "Show the toolbar", on: $opts.mToolbar)
                    RCheck(title: "Show the buttons at the bottom", on: $opts.mButtons)
                    RCheck(title: "Keep the window on top of other windows", on: $opts.mOnTop)
                }
                RGroup(title: "Contact list") {
                    RCheck(title: "Show offline contacts", on: $opts.mOffline)
                    RCheck(title: "Hide demo contacts (the made-up sample friends)", on: Binding(get: { s.hideDemo }, set: { s.hideDemo = $0; s.save() }))
                    RCheck(title: "Show the iMessage group", on: $opts.mIMessage)
                }.padding(.top, 6)
            }
            Text("Each theme keeps its own main-window settings. Pick a theme above to edit its options.").foregroundColor(.hint).padding(.top, 4)
        default:
            RGroup(title: "AI service") {
                Text("Service: " + s.aiProvider.title + "  (change it and set the key in Preferences > Privacy)").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("Model:")
                    RButton(title: (model.isEmpty ? "Choose…" : model) + "   ▾", minWidth: 220) {
                        popRMenu(s.modelChoices().map { m in RMItem(title: m, checked: m == model, fn: { model = m }) } + [RMItem(sep: true), RMItem(title: "Custom…", fn: { ICQ.askText("Model", "Model ID:", model) { model = $0 } })])
                    }
                }.padding(.top, 4)
                if !s.keyStatus.isEmpty { Text(s.keyStatus).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
            }
            RCheck(title: "Enable real chats with the AI", on: $ai)
            Text("Off = chatbots answer with sample messages (no network).\nOn = replies come from the AI service using your key.").foregroundColor(.hint).padding(.top, 2)
            Text("Note: by default chatbots play a chat friend and do not announce that they are an AI. They are still AI chatbots; tick \"Act as a normal AI assistant\" on a bot for answers that say so.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            RGroup(title: "AI Chatbots") {
                Sunken { ScrollView { VStack(spacing: 0) {
                    ForEach(s.contacts.filter(\.isBot)) { c in
                        HStack(spacing: 4) { Pix(name: "ffc", w: 16); Text(c.name).foregroundColor(botSel == c.uin ? .white : Color.ink); Spacer() }
                            .padding(.horizontal, 4).frame(height: 18).background(botSel == c.uin ? Color.navy : Color.clear)
                            .contentShape(Rectangle()).onTapGesture { botSel = c.uin }
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading) } }.frame(height: 66)
                HStack {
                    RButton(title: "+", minWidth: 30) { ICQ.openBot(nil) }
                    RButton(title: "Edit") { if let u = botSel { ICQ.openBot(u) } }
                    RButton(title: "–", minWidth: 30) { if let u = botSel, let c = s.contact(u) { confirm("Confirm Delete User", "Delete \(c.name) ?") { s.remove(u); botSel = nil } } }
                    Spacer()
                }.padding(.top, 4)
            }.padding(.top, 6)
            RGroup(title: "Chatbot activity") {
                RCheck(title: "Chatbots start conversations on their own", on: $botInit)
                HStack(spacing: 5) { Text("Every"); RField(text: $botMinS).frame(width: 44); Text("to"); RField(text: $botMaxS).frame(width: 44); Text("minutes (random)") }
            }.padding(.top, 6)
        }
    }
    func importTheme() {
        let p = NSOpenPanel(); p.canChooseFiles = true; p.canChooseDirectories = true; p.allowsMultipleSelection = false
        p.message = "Choose a theme folder or .zip (it must contain theme.json)"
        guard p.runModal() == .OK, let u = p.url else { return }
        do { let t = try Assets.importPack(from: u); themeChoice = "pack:" + t.id; themeMsg = "Imported “\(t.name)”. Press OK to apply it."; AppDelegate.rebuildMenu() }
        catch { themeMsg = error.localizedDescription }
    }
    func addName() { if s.add(newName) != nil { newName = "" } }
    func apply() {
        let schedChanged = s.freqEnabled != enabled || s.freqMode != mode || s.minutes != max(1, Int(mins) ?? s.minutes) || s.demoFirst != first
        s.nick = nick.trimmingCharacters(in: .whitespaces).isEmpty ? s.nick : nick.trimmingCharacters(in: .whitespaces)
        s.uin = uin.trimmingCharacters(in: .whitespaces).isEmpty ? s.uin : uin.trimmingCharacters(in: .whitespaces)
        s.sounds = sounds; s.freqEnabled = enabled; s.freqMode = mode; s.minutes = max(1, Int(mins) ?? s.minutes); s.demoFirst = first; s.aiDraftIMessage = draftIM && ai; s.autoReplyText = replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? s.autoReplyText : replyText; s.bridgeAutoAdd = autoAddIM; s.autoAway = autoAway; s.autoAwayMin = max(1, Int(autoMin) ?? s.autoAwayMin); s.autoAwayDND = autoDND
        if themeChoice != Assets.currentChoiceId() { Assets.select(themeChoice); s.save(); DispatchQueue.main.async { ICQ.relayout() } }
        else if UI.scale != scaleChoice { UI.scale = scaleChoice; s.save(); DispatchQueue.main.async { ICQ.relayout() } }
        let nm = appNameDraft.trimmingCharacters(in: .whitespaces); if nm != s.appName { s.appName = nm.isEmpty ? "ICQuel" : nm; s.save(); AppDelegate.rebuildMenu() }
        if bridgeOn != s.bridgeEnabled { s.bridgeEnabled = bridgeOn; s.save(); s.startBridge() }
        if s.opts != opts { s.opts = opts; ICQ.applyMainOptions() }
        if (s.keyLoaded || !key.isEmpty) && s.apiKey != key { s.apiKey = key; s.refreshModels() }; s.aiEnabled = ai; s.botInit = botInit; s.botMin = max(1, Int(botMinS) ?? s.botMin); s.botMax = max(s.botMin, Int(botMaxS) ?? s.botMax); let m = s.aiProvider == .anthropic ? AIChat.normalizeModel(model) : model.trimmingCharacters(in: .whitespaces); if !m.isEmpty { s.apiModel = m }; if model != s.apiModel { model = s.apiModel }; s.save(); if schedChanged { s.resetSched() }
    }
}

// MARK: registration wizard + connecting
struct ConnectingView: View {
    @State private var p = 0.0
    @State private var done = false
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 12) {
            Pix(name: "flower32", w: 32)
            VStack(alignment: .leading, spacing: 8) {
                Text(p > 55 ? "Retrieving contact list..." : "Connecting to \(App.name)...")
                ZStack(alignment: .leading) {
                    Color.gray98.frame(height: 18).overlay(Bevel(raised: false))
                    HStack(spacing: 2) { ForEach(0..<Int(min(p, 100) / 100 * 24), id: \.self) { _ in Color.navy.frame(width: 8, height: 12) } }.padding(.leading, 3)
                }
            }
        }.padding(14).onReceive(timer) { _ in
            p += Double(7 + Int.random(in: 0..<10))
            if p >= 100 && !done { done = true; WinMgr.shared.close("connect"); ICQ.begin() }
        }
    }
}
