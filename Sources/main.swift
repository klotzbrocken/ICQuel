import SwiftUI
import AppKit
import Sparkle
import Contacts

enum ICQ {
    static let s = Store.shared
    static var tray: NSStatusItem?

    static func start(force: Bool = false) {
        WinMgr.shared.closeAll()
        if !force && !s.uin.isEmpty && Persist.testMode == false { connecting(); return }   // the assistant runs on first start (or from the app menu)
        WinMgr.shared.open("wizard", "\(App.name) Setup", SetupView.size.width, SetupView.size.height) { SetupView() }
    }
    static func connecting() {
        if Theme.isModern { WinMgr.shared.open("connect", App.name, 300, 90) { ModernConnecting() } } else { WinMgr.shared.open("connect", App.name, 340, 80) { ConnectingView() } }
    }
    static func begin() {
        // the sample contacts (the dummy "friends") are added once, also when the setup assistant already created iMessage contacts or bots
        if !UserDefaults.standard.bool(forKey: "seeded") {
            UserDefaults.standard.set(true, forKey: "seeded")
            if !s.contacts.contains(where: { !$0.isLive && !$0.isBot }) { s.contacts += seedContacts.map { Contact(name: $0, uin: Store.newUin()) }; s.save() }
        }
        s.simulatePresence(); if s.status == .offline { s.status = .online }
        openMain(); Sound.play("startup"); s.resetSched(); s.startBots(); s.startBridge(); s.startIdleWatch(); offerMessagesImport(); if s.freqEnabled && s.demoFirst { s.startDemoFirst() }
        refreshTray()
    }
    static func openMain() {
        leaveMenuOnly()
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        if Theme.isModern { WinMgr.shared.open("main", App.name, ModernMain.size.width, ModernMain.size.height, at: NSPoint(x: screen.maxX - ModernMain.size.width - 40, y: screen.maxY - 30)) { ModernMain() }; applyMainOptions(); return }
        WinMgr.shared.open("main", s.uin, 164, s.simpleMode ? 261 : 330, at: NSPoint(x: screen.maxX - 200, y: screen.maxY - 30), icon: "", small: true, resizable: true) { MainView() }
        applyMainOptions()
    }
    static func openSession(_ u: String, activate: Bool = true) {
        guard let c = s.contact(u) else { return }
        WinMgr.shared.open("sess" + u, "Message Session: " + c.name, SessionView.size.width, SessionView.size.height, resizable: true, activate: activate) { SessionView(uin: u) }
    }
    static func openSend(_ u: String) { if Theme.isModern { openSession(u); return }; if let c = s.contact(u) { _ = c; WinMgr.shared.open("send" + u, s.online.contains(u) && s.status != .offline ? "Send Online Message" : "Send Offline Message", SendView.size.width, SendView.size.height, resizable: true) { SendView(uin: u) } } }
    static func openIncoming(_ u: String) {
        if Theme.isModern { openSession(u); return }
        guard let c = s.contact(u), !(s.unread[u] ?? []).isEmpty else { return }
        WinMgr.shared.open("in" + u, IncomingView.title((s.unread[u] ?? []).count), IncomingView.size.width, IncomingView.size.height, resizable: true) { IncomingView(uin: u) }
    }
    // MARK: contact details: e-mail (opens the default mail app) and FaceTime
    static func mail(_ c: Contact) {
        if let a = c.mailAddr, let u = URL(string: "mailto:" + a.trimmingCharacters(in: .whitespaces)) { NSWorkspace.shared.open(u) }
        else { notice("There is no e-mail address for \(c.name) yet.\nRight-click the contact > Edit Contact…") }
    }
    static func faceTime(_ c: Contact, audio: Bool) {
        guard let t = c.callTarget?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { notice("There is no phone number for \(c.name) yet.\nRight-click the contact > Edit Contact…"); return }
        let clean = t.contains("@") ? t : String(t.filter { $0.isNumber || $0 == "+" })   // spaces and dashes out
        if let enc = clean.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed), let u = URL(string: (audio ? "facetime-audio://" : "facetime://") + enc) { NSWorkspace.shared.open(u) }
    }
    /// Once, when the bridge works but no conversation has been picked yet: offer the import list.
    static func offerMessagesImport() {
        guard s.bridgeEnabled, !Persist.testMode, !UserDefaults.standard.bool(forKey: "imsg_import_offered"), Bridge.checkAccess() == .ok else { return }
        UserDefaults.standard.set(true, forKey: "imsg_import_offered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { openMessagesImport() }
    }
    static func openMessagesImport() {
        WinMgr.shared.close("msgimport")
        WinMgr.shared.open("msgimport", "Import from Messages", MessagesImportView.size.width, MessagesImportView.size.height) { MessagesImportView() }
    }
    static func openContactEdit(_ uin: String) {
        WinMgr.shared.close("edit" + uin)
        WinMgr.shared.open("edit" + uin, "Edit Contact", ContactEditView.size.width, ContactEditView.size.height) { ContactEditView(uin: uin) }
    }
    /// Entries appended to the right-click menus of the contact lists.
    static func contactItems(_ c: Contact) -> [NSMenuItem] {
        [MItem("Edit Contact…") { openContactEdit(c.uin) }, MItem("Send Mail…", enabled: c.mailAddr != nil) { mail(c) },
         MItem("FaceTime Video", enabled: c.callTarget != nil) { faceTime(c, audio: false) }, MItem("FaceTime Audio", enabled: c.callTarget != nil) { faceTime(c, audio: true) }]
    }
    static func openArchive(_ u: String? = nil) { WinMgr.shared.open("archive", "Message Archive", 480, 360, resizable: Theme.isModern) { ArchiveView(cur: u ?? s.selected) } }
    static func openBot(_ u: String?) { let id = "bot" + (u ?? "new"); WinMgr.shared.open(id, u == nil ? "New AI Chatbot" : "Edit AI Chatbot", BotView.size.width, BotView.size.height) { BotView(uin: u) } }
    static func applyMainOptions() { WinMgr.shared.setLevel("main", (Theme.isModern ? s.opts.mOnTop : s.opts.alwaysOnTop) ? .floating : .normal) }
    static func setSimple(_ simple: Bool) { if Theme.isModern { return }; s.simpleMode = simple; s.save(); WinMgr.shared.resize("main", 164, simple ? 261 : 330) }
    static func relayout(prefs: Bool = true) { WinMgr.shared.closeAll(); if s.uin.isEmpty { start(); return }; openMain(); refreshTray(); if prefs { openPrefs(0) } }
        static func openAdd() {
        if Theme.isModern { WinMgr.shared.open("add", "Add Users", ModernAdd.size.width, ModernAdd.size.height) { ModernAdd() }; return }
        WinMgr.shared.open("add", "Add Users", AddWizardView.size.width, AddWizardView.size.height) { AddWizardView() } }
    static func openAbout() {
        if Theme.isModern { WinMgr.shared.open("about", "About \(App.name)", ModernAbout.size.width, ModernAbout.size.height) { ModernAbout() }; return }
        WinMgr.shared.open("about", "About \(App.name)", AboutView.size.width, AboutView.size.height) { AboutView() }
    }
    static func confirmDelete(_ u: String) {
        if Theme.isModern { confirm("Delete \(s.contact(u)?.name ?? "?")?", "The contact will be removed from your list.", ok: "Delete", cancel: "Cancel") { s.remove(u) }; return }
        WinMgr.shared.open("del" + u, "Confirm Delete User", DeleteView.size.width, DeleteView.size.height) { DeleteView(uin: u) } }
    static func openPrefs(_ tab: Int = 1) { WinMgr.shared.close("prefs"); if Theme.isModern { WinMgr.shared.open("prefs", "Preferences", 760, 540) { PrefsView(tab: tab) }; return }; WinMgr.shared.open("prefs", "\(App.name) Preferences – " + s.nick, 600, PrefsView.height(tab), icon: "prefsicon") { PrefsView(tab: tab) } }
    static func setStatus(_ st: Status) {
        s.status = st; s.save(); refreshTray()
        if Theme.isModern, [.away, .na, .occupied, .dnd, .ffc].contains(st) {
            WinMgr.shared.close("away"); WinMgr.shared.open("away", "Status Message", ModernAway.size.width, ModernAway.size.height) { ModernAway(status: st) }
        }
        if !Theme.isModern, [.away, .na, .occupied, .dnd, .ffc].contains(st) {
            WinMgr.shared.close("away"); WinMgr.shared.open("away", st == .na ? "Change / Confirm N/A Message" : (st == .ffc ? "Change / Confirm \"Free For Chat\" Message" : "Change / Confirm Away Message"), AwayView.size.width, AwayView.size.height) { AwayView(status: st) }
        }
    }

    static func statusItems() -> [NSMenuItem] { Status.allCases.map { st in MItem(st.menuLabel, icon: st.rawValue, checked: s.status == st) { setStatus(st) } } }
    static func statusMenu() {
        let na = { comingSoon() }
        func st(_ x: Status) -> RMItem { RMItem(title: x.menuLabel, icon: x.rawValue, fn: { setStatus(x) }) }
        popRMenu([
            RMItem(title: "Random Chat", icon: "random", children: ["Find Random User", "Available For Random Chat", "My Random Chat Settings", "Random Chat Web Guide"].map { RMItem(title: $0, fn: na) }),
            RMItem(title: "Online Status", header: true),
            st(.online), st(.ffc), RMItem(sep: true), st(.away), st(.na), RMItem(sep: true), st(.occupied), st(.dnd), RMItem(sep: true), st(.invisible), st(.offline),
        ])
    }
    private static func na() { comingSoon() }
    private static func stub(_ titles: [String]) -> [RMItem] { titles.map { RMItem(title: $0, fn: na) } }
    /// The ICQ feature entries shared by the System Menu and the tray menu (icons matched from the original screenshot).
    static func icqEntries() -> [RMItem] {
        [RMItem(title: "My ICQ Page", icon: "m_page", children: stub(["Go To My ICQ Page", "Edit My ICQ Page"])),
         RMItem(title: "Reminder", icon: "m_reminder", children: stub(["Open Reminders List", "New Reminder"])),
         RMItem(title: "Notes", icon: "m_notes", children: stub(["New Note", "Open Notes"])),
         RMItem(title: "ToDo", icon: "m_todo", children: stub(["New ToDo", "Open ToDo List"])),
         RMItem(title: "Email", icon: "m_email", children: stub(["Send Email", "Send Email + Notify By ICQ", "Check Email", "Email Signature", "Email Center"])),
         RMItem(title: "Phone - \"Follow Me\"", icon: "m_phone", children: stub(["Send Phone Call Request", "Find Phone# and Dial", "Update Phone \"Follow Me\" info"])),
         RMItem(title: "Message Archive", icon: "m_archive", children: [RMItem(title: "Open Message Archive", fn: { openArchive() })]),
         RMItem(title: "ICQ White Pages", icon: "m_white", children: stub(["Search White Pages", "Find Users"])),
         RMItem(title: "ICQ Active List", icon: "m_active", children: stub(["Show ICQ ActiveLists", "ICQ ActiveList Preferences"])),
         RMItem(title: "E-ICQ", icon: "m_eicq", children: stub(["E-ICQ Online", "E-ICQ Options"]))]
    }
    static func statusRItems() -> [RMItem] { Status.allCases.map { st in RMItem(title: st.menuLabel, icon: st.rawValue, checked: s.status == st, fn: { setStatus(st) }) } }
    static func mainMenu() {
        popRMenu([RMItem(title: "Add/Find Users", fn: { openAdd() }), RMItem(sep: true)] + icqEntries() + [
            RMItem(sep: true),
            RMItem(title: "View / Change My Details", fn: { openPrefs(0) }), RMItem(title: "Preferences", fn: { openPrefs(1) }),
            RMItem(title: s.simpleMode ? "To Advanced Mode" : "To Simple Mode", fn: { setSimple(!s.simpleMode) }),
            RMItem(title: "Status", children: statusRItems()),
            RMItem(title: "Help", children: [RMItem(title: "Help Topics", enabled: false), RMItem(title: "ICQ - What's New", enabled: false), RMItem(sep: true), RMItem(title: "About", fn: { openAbout() })]),
            RMItem(sep: true), RMItem(title: "Shut Down", fn: { shutDown() }),
        ])
    }
    /// Menu of the tray icon (right click): status, alerts, settings, dock icon. A left click opens the app.
    static func trayMenu() {
        popRMenu([RMItem(title: "Status", children: statusRItems()),
                  RMItem(title: "Alerts", checked: s.sounds, fn: { s.sounds.toggle(); s.save() }),
                  RMItem(sep: true),
                  RMItem(title: "Settings…", fn: { openPrefs(1) }),
                  RMItem(title: "Show Dock Icon", checked: !dockHidden, fn: { setDock(dockHidden) }),
                  RMItem(sep: true),
                  RMItem(title: "Quit \(App.name)", fn: { shutDown() })])
    }
    /// Closing the main window keeps the app alive in the menu bar only (no Dock icon); minimizing goes to the Dock as usual.
    static var menuOnly = false
    static func toMenuOnly() {
        guard !s.uin.isEmpty, !Persist.testMode else { return }
        menuOnly = true; NSApp.setActivationPolicy(.accessory); refreshTray()
    }
    static func leaveMenuOnly() {
        guard menuOnly else { return }
        menuOnly = false
        if !dockHidden { NSApp.setActivationPolicy(.regular); Assets.applyIcon() }
    }
    static var dockHidden: Bool { UserDefaults.standard.bool(forKey: "dock_hidden") }
    static func setDock(_ show: Bool) {
        UserDefaults.standard.set(!show, forKey: "dock_hidden")
        NSApp.setActivationPolicy(show ? .regular : .accessory)
        if show { Assets.applyIcon() }
        refreshTray(); NSApp.activate(ignoringOtherApps: true)
    }
    static func openApp() {
        if WinMgr.shared.has("main") { WinMgr.shared.front("main"); NSApp.activate(ignoringOtherApps: true) } else { openMain(); NSApp.activate(ignoringOtherApps: true) }
    }
    static func servicesMenu() {
        let na = { comingSoon() }
        func list(_ t: [String]) -> [NSMenuItem] { t.map { $0 == "-" ? .separator() : MItem($0, fn: na) } }
        popMenu([
            submenu("Email", list(["Send Email", "Send Email + Notify By ICQ", "-", "Check Email", "Email Signature", "Email Center"])),
            submenu("Phone", list(["Send Phone Call Request", "Find Phone# and Dial", "Web Guide"])),
            submenu("Random", list(["Find Random User", "-", "Available For Random Chat", "My Random Chat Settings", "-", "Random Chat Web Guide"])),
            MItem("Message Archive") { openArchive() },
        ])
    }
    static func shutDown() {
        confirm("Confirm ShutDown...", "Are you sure you want to shut down \(App.name)?") {
            WinMgr.shared.closeAll(); s.stopSched(); s.stopBots(); s.stopBridge(); s.stopIdleWatch(); NSApp.dockTile.badgeLabel = nil; tray?.isVisible = false; NSApp.terminate(nil)
        }
    }
    static func trayClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true { trayMenu(); return }
        if let u = s.unread.first(where: { !$0.value.isEmpty })?.key { openIncoming(u) } else { openApp() }
    }
    static func refreshTray() {
        guard let b = tray?.button else { return }
        b.toolTip = "[\(s.uin)]"
        let n = s.unreadCount, name = n > 0 && s.flash ? "msg" : s.status.rawValue
        let i = pic(name).copy() as! NSImage; i.size = NSSize(width: 16, height: 16); b.image = i
        tray?.isVisible = dockHidden || menuOnly || (!s.uin.isEmpty && WinMgr.shared.has("main")) || n > 0
        NSApp.dockTile.badgeLabel = n > 0 ? String(n) : nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Sparkle checks the appcast on GitHub (SUFeedURL in Info.plist). Without a configured repository it stays off.
    private static let feedConfigured = !((Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String) ?? "OWNER/REPO").contains("OWNER/REPO") && !Persist.testMode
    let updater = SPUStandardUpdaterController(startingUpdater: AppDelegate.feedConfigured, updaterDelegate: nil, userDriverDelegate: nil)
    @objc func updatesNotConfigured() { notice("Updates are not set up yet.\nSet GITHUB_REPO in update.conf and rebuild.") }
    func applicationDidFinishLaunching(_ n: Notification) {
        Assets.applyIcon()
        // preferences used to live under the old bundle id; take them over once
        if !Persist.testMode, UserDefaults.standard.object(forKey: "migrated_from_icq99b") == nil, let old = UserDefaults(suiteName: "local.demo.icq99b") {
            for k in ["theme", "ui_scale", "snd_files", "snd_message"] { if let v = old.object(forKey: k) { UserDefaults.standard.set(v, forKey: k) } }
            UserDefaults.standard.set(true, forKey: "migrated_from_icq99b")
        }
        NSApp.setActivationPolicy(ICQ.dockHidden ? .accessory : .regular)
        Assets.applyIcon()
        ICQ.tray = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        ICQ.tray?.button?.target = self; ICQ.tray?.button?.action = #selector(trayClick); ICQ.tray?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp]); ICQ.tray?.isVisible = ICQ.dockHidden
        buildMenu()
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in Store.shared.flash.toggle() }
        Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { _ in Store.shared.shuffleOne() }
        ICQ.start()
        if ProcessInfo.processInfo.environment["ICQ_LIGHT"] != nil { NSApp.appearance = NSAppearance(named: .aqua) }   // self-test only
        if let dir = ProcessInfo.processInfo.environment["ICQ_SNAPSHOT"] { // scripted self-test: ICQ_PACK=<theme folder> imports and selects it first
            if let pk = ProcessInfo.processInfo.environment["ICQ_PACK"] {
                do { let t = try Assets.importPack(from: URL(fileURLWithPath: pk)); Assets.select("pack:" + t.id); print("imported", t.name) } catch { print("import failed:", error.localizedDescription) }
            }
            let steps: [(String, () -> Void)] = [("main", { Store.shared.uin = "10001"; Store.shared.nick = "Maik"; if Store.shared.contacts.isEmpty { Store.shared.contacts = seedContacts.prefix(6).map { Contact(name: $0, uin: Store.newUin()) }; Store.shared.simulatePresence(); _ = Store.shared.addBridgeContact("Anna (iMessage)", handle: "+491511234567") }; ICQ.openMain() }), ("setup", { ICQ.start(force: true) }), ("conn", { ICQ.connecting() }), ("edit", { if let c = Store.shared.contacts.first { ICQ.openContactEdit(c.uin) } }),
                                       ("selftest", {   // prints counts only, never message text
                let st = Store.shared; let n0 = st.unreadCount; st.status = .dnd; st.deliver(); print("DND: scheduled messages delivered:", st.unreadCount - n0)
                st.status = .away; st.deliver(); print("Away: scheduled messages delivered:", st.unreadCount - n0)
                st.status = .online; st.deliver(); print("Online: scheduled messages delivered:", st.unreadCount - n0)
                if let top = Bridge.maxRowID(), let h = Bridge.incoming(after: max(0, top - 800)).first?.handle { let r = Bridge.recent(handle: h, limit: 5); let cv = Bridge.conversations(limit: 15); print("Contacts authorization (0=undetermined,1=restricted,2=denied,3=authorized):", CNContactStore.authorizationStatus(for: .contacts).rawValue); let hs = Bridge.conversations(limit: 15).map(\.handle); Bridge.names(for: hs) { n in print("Names resolved:", n.count, "of", hs.count) }; print("Messages conversations: \(cv.count) found, \(cv.filter { $0.count > 1 }.count) with several messages"); print("Messages unread among latest 5 of one chat:", Bridge.unreadAmongLatest(handle: h, n: 5)); print("Messages recent: \(r.count) found, \(r.filter(\.fromMe).count) sent by me") } else { print("Messages recent: no access / no data") } }),
                                       ("incoming", { if let c = Store.shared.contacts.first { Store.shared.deliver(to: c, text: "Hey, bist du noch da"); Store.shared.deliver(to: c, text: "second"); print("unread before opening:", Store.shared.unreadCount); ICQ.openIncoming(c.uin); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { print("unread after opening:", Store.shared.unreadCount) } } }), ("send", { if let c = Store.shared.contacts.first { ICQ.openSend(c.uin) } }), ("about", { ICQ.openAbout() }), ("add", { ICQ.openAdd() }), ("p0", { ICQ.openPrefs(0) }), ("p1", { ICQ.openPrefs(1) }), ("p2", { ICQ.openPrefs(2) }), ("p3", { ICQ.openPrefs(3) }), ("p4", { ICQ.openPrefs(4) }), ("p6", { ICQ.openPrefs(6) }), ("p7", { ICQ.openPrefs(7) }), ("p8", { ICQ.openPrefs(8) }), ("away", { ICQ.confirmDelete("x") })]
            let only = ProcessInfo.processInfo.environment["ICQ_ONLY"]?.split(separator: ",").map(String.init)
            for (i, st) in steps.filter({ only == nil || only!.contains($0.0) }).enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(i) * 1.2) { WinMgr.shared.closeAll(); st.1(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { WinMgr.shared.snapshot(to: dir, prefix: st.0 + "-") } }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(steps.filter({ only == nil || only!.contains($0.0) }).count) * 1.2 + 1) { NSApp.terminate(nil) }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows f: Bool) -> Bool {
        if !f { ICQ.tray?.isVisible == true ? ICQ.openMain() : ICQ.start() }
        return true
    }
    @objc func trayClick() { ICQ.trayClicked() }
    @objc func prefs() { ICQ.openPrefs(1) }
    @objc func archive() { ICQ.openArchive() }
    @objc func about() { ICQ.openAbout() }
    @objc func setupAssistant() { ICQ.start(force: true) }
    @objc func addUsers() { ICQ.openAdd() }
    @objc func receiveNow() { Store.shared.deliver() }
    @objc func pickTheme(_ s: NSMenuItem) { guard let id = s.representedObject as? String, id != Assets.currentChoiceId() else { return }; Assets.select(id); ICQ.s.save(); ICQ.relayout(prefs: WinMgr.shared.has("prefs")); buildMenu() }
    static func rebuildMenu() { (NSApp.delegate as? AppDelegate)?.buildMenu() }
    func buildMenu() {
        let bar = NSMenu()
        func top(_ t: String, _ items: [NSMenuItem]) { let m = NSMenu(title: t); items.forEach { m.addItem($0) }; let i = NSMenuItem(); i.submenu = m; bar.addItem(i) }
        func it(_ t: String, _ sel: Selector, _ k: String = "") -> NSMenuItem { let i = NSMenuItem(title: t, action: sel, keyEquivalent: k); i.target = self; return i }
        let upd = NSMenuItem(title: "Check for Updates…", action: AppDelegate.feedConfigured ? #selector(SPUStandardUpdaterController.checkForUpdates(_:)) : #selector(updatesNotConfigured), keyEquivalent: "")
        upd.target = AppDelegate.feedConfigured ? updater : self
        top(App.name, [it("About \(App.name)", #selector(about)), upd, .separator(), it("Preferences…", #selector(prefs), ","), it("Setup Assistant…", #selector(setupAssistant)), .separator(),
                    NSMenuItem(title: "Hide \(App.name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"),
                    NSMenuItem(title: "Quit \(App.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")])
        top("Edit", [NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"), { let i = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z"); i.keyEquivalentModifierMask = [.command, .shift]; return i }(), .separator(),
                     NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"), NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
                     NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"), NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")])
        top("Contacts", [it("Add/Find Users", #selector(addUsers), "n"), it("Message Archive", #selector(archive), "a"), it("Receive Sample Message Now", #selector(receiveNow), "r")])
        top("Theme", Assets.choices().map { ch in let i = it(ch.title, #selector(pickTheme(_:))); i.representedObject = ch.id; i.state = ch.id == Assets.currentChoiceId() ? .on : .off; return i })
        top("Window", [NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"),
                       NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")])
        NSApp.mainMenu = bar
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
