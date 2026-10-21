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
                            Text("\(m.dir == "in" ? name : s.nick) (\(stamp(m.t))):").font(rf(bold: true)); Text(m.text)
                        }
                    }
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
    @State private var autoMin = String(Store.shared.autoAwayMin)
    @State private var autoDND = Store.shared.autoAwayDND
    @State private var key = Store.shared.apiKey
    @State private var ai = Store.shared.aiEnabled
    @State private var showKey = false
    @State private var newName = ""
    @State private var model = Store.shared.apiModel
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
    static let heights: [Int: CGFloat] = [0: 375, 1: 440, 2: 440, 3: 470, 4: 530, 5: 395, 6: 490, 7: 400, 8: 450]
    static let icons: [(String, Color)] = [("person.crop.circle.fill", .blue), ("person.2.fill", .green), ("tray.and.arrow.down.fill", .orange), ("text.bubble.fill", .teal), ("speaker.wave.2.fill", .pink),
                                           ("lock.fill", .gray), ("sparkles", .purple), ("macwindow", .indigo), ("message.badge.filled.fill", Color(red: 0.2, green: 0.78, blue: 0.35))]
    /// The first page grows with the number of installed themes (+ room for the fan-made note).
    static func height(_ t: Int) -> CGFloat { t == 0 ? 380 + CGFloat(max(0, Assets.choices().count - 4)) * 17 + 45 : (heights[t] ?? 520) }
    static let pages = ["My Details", "Contact List", "Incoming", "Messages", "Sounds", "Security", "AI Chat", "Main Window", "Bridge"]
    var body: some View {
        (Theme.isModern ? AnyView(modernBody) : AnyView(classicBody))
            .onAppear { if !s.keyLoaded { s.loadKeyAsync() } }
            .onChange(of: tab) { t in if !Theme.isModern { WinMgr.shared.resize("prefs", 600, PrefsView.height(t)) } }
            .onChange(of: s.apiKey) { if key.isEmpty { key = $0 } }
    }
    var modernBody: some View {
        let visible = [0, 1, 2, 3, 4, 7, 6, 8]
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
                        if tab == 4 { ModernSounds().padding(.horizontal, 10) } else if tab == 5 { Text("Coming soon.").padding(10) } else { ScrollView { Page { pageBody } } }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            HStack {
                RButton(title: "Restore Defaults", minWidth: 120, action: restore)
                Spacer()
                RButton(title: "Cancel") { WinMgr.shared.close("prefs") }
                RButton(title: "Apply", action: apply)
                RButton(title: "OK", isDefault: true) { apply(); WinMgr.shared.close("prefs") }
            }
        }.padding(16).frame(width: 760, height: 540)
    }
    var classicBody: some View {
        VStack(spacing: 0) {
            WTabs(rows: [[0, 1, 2, 3], [4, 5, 7, 6, 8]], titles: PrefsView.pages, width: 584, sel: $tab)
            Group {
                switch tab {
                case 4: SoundsPage().padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Color.gray98).overlay(Bevel())
                case 5: SecurityPage().padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Color.gray98).overlay(Bevel())
                default: Page { pageBody }
                }
            }.padding(.top, -1)
            HStack {
                RButton(title: "Restore All Defaults", minWidth: 150, action: restore)
                Spacer()
                RButton(title: "OK", isDefault: true) { apply(); WinMgr.shared.close("prefs") }
                RButton(title: "Cancel") { WinMgr.shared.close("prefs") }
                RButton(title: "Apply", action: apply)
            }.padding(.top, 8)
        }.padding(8)
    }
    func restore() {
        s.freqEnabled = true; s.freqMode = .hour; s.minutes = 15; s.demoFirst = true; s.sounds = true; s.opts = MainOpts(); ICQ.applyMainOptions(); s.save()
        UserDefaults.standard.removeObject(forKey: "snd_files"); UserDefaults.standard.removeObject(forKey: "snd_message"); for e in Sound.defaults.keys { UserDefaults.standard.removeObject(forKey: "snd_on_" + e) }
        s.resetSched(); let t = tab; WinMgr.shared.close("prefs"); ICQ.openPrefs(t)
    }
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
        case 8:
            RCheck(title: "Enable the Messages bridge (iMessage through the Messages app of this Mac)", on: $bridgeOn)
            Text("Status: " + (bridgeOn ? s.bridgeStatus : "Off")).foregroundColor(.hint).padding(.top, 2)
            HStack {
                RButton(title: "1. Full Disk Access…", minWidth: 130) { _ = Bridge.checkAccess(); Bridge.openPrivacySettings() }
                RButton(title: "Show app in Finder", minWidth: 120) { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            }
            HStack {
                RButton(title: "2. Allow Messages control", minWidth: 150) { Bridge.requestAutomation { msg in bridgeMsg = msg } }
                RButton(title: "Check again") { s.bridgeEnabled = bridgeOn; s.startBridge() }
            }
            if !bridgeMsg.isEmpty { Text(bridgeMsg).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
            Text("If the app is not in the Full Disk Access list: click “Show app in Finder”, then drag the app into the list (or use the + button) and switch it on. Restart the app afterwards. Button 2 shows the macOS prompt that adds the app under Privacy & Security > Automation.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
            Text("Receiving needs Full Disk Access for this app, sending needs the Automation permission for Messages. Only the contacts listed below are read; nothing else is read, stored or sent. AI chatbots never answer bridged chats.").foregroundColor(.hint).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
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
                    RCheck(title: "Show the iMessage group", on: $opts.mIMessage)
                }.padding(.top, 6)
            }
            Text("Each theme keeps its own main-window settings. Pick a theme above to edit its options.").foregroundColor(.hint).padding(.top, 4)
        default:
            RGroup(title: "AI API Key") {
                RField(placeholder: "API key", text: $key, secure: !showKey)
                RCheck(title: "Show key", on: $showKey).padding(.top, 4)
                Text("Model (ID, e.g. claude-sonnet-5-5):").padding(.top, 4); RField(text: $model)
            }
            RCheck(title: "Enable real chats with the AI", on: $ai)
            Text("Off = chatbots answer with sample messages (no network).\nOn = replies come from the AI API using your key.").foregroundColor(.hint).padding(.top, 2)
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
        s.nick = nick.trimmingCharacters(in: .whitespaces).isEmpty ? s.nick : nick.trimmingCharacters(in: .whitespaces)
        s.uin = uin.trimmingCharacters(in: .whitespaces).isEmpty ? s.uin : uin.trimmingCharacters(in: .whitespaces)
        s.sounds = sounds; s.freqEnabled = enabled; s.freqMode = mode; s.minutes = max(1, Int(mins) ?? s.minutes); s.demoFirst = first; s.autoAway = autoAway; s.autoAwayMin = max(1, Int(autoMin) ?? s.autoAwayMin); s.autoAwayDND = autoDND
        if themeChoice != Assets.currentChoiceId() { Assets.select(themeChoice); s.save(); DispatchQueue.main.async { ICQ.relayout() } }
        else if UI.scale != scaleChoice { UI.scale = scaleChoice; s.save(); DispatchQueue.main.async { ICQ.relayout() } }
        let nm = appNameDraft.trimmingCharacters(in: .whitespaces); if nm != s.appName { s.appName = nm.isEmpty ? "ICQuel" : nm; s.save(); AppDelegate.rebuildMenu() }
        if bridgeOn != s.bridgeEnabled { s.bridgeEnabled = bridgeOn; s.save(); s.startBridge() }
        if s.opts != opts { s.opts = opts; ICQ.applyMainOptions() }
        if s.keyLoaded || !key.isEmpty { s.apiKey = key }; s.aiEnabled = ai; s.botInit = botInit; s.botMin = max(1, Int(botMinS) ?? s.botMin); s.botMax = max(s.botMin, Int(botMaxS) ?? s.botMax); s.apiModel = AIChat.normalizeModel(model).isEmpty ? s.apiModel : AIChat.normalizeModel(model); model = s.apiModel; s.save(); s.resetSched()
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
