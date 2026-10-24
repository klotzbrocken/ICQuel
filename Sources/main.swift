import SwiftUI
import AppKit
import Sparkle

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
        openMain(); Sound.play("startup"); s.resetSched(); s.startBots(); s.startBridge(); WABridge.shared.onMessage = { s.waIncoming($0) }; WABridge.shared.startIfEnabled(); s.startIdleWatch(); offerMessagesImport(); if s.freqEnabled && s.demoFirst { s.startDemoFirst() }
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
    static func openWAImport() {
        WinMgr.shared.close("waimport")
        WinMgr.shared.open("waimport", "Import from WhatsApp", WAImportView.size.width, WAImportView.size.height) { WAImportView() }
    }
    static func openContactEdit(_ uin: String) {
        WinMgr.shared.close("edit" + uin)
        WinMgr.shared.open("edit" + uin, "Edit Contact", ContactEditView.size.width, ContactEditView.size.height) { ContactEditView(uin: uin) }
    }
    /// Entries appended to the right-click menus of the contact lists.
    static func contactItems(_ c: Contact) -> [NSMenuItem] {
        [MItem("Edit Contact…") { openContactEdit(c.uin) }, MItem("Send Mail…", enabled: c.mailAddr != nil) { mail(c) },
         MItem("FaceTime Video", enabled: c.callTarget != nil) { faceTime(c, audio: false) }, MItem("FaceTime Audio", enabled: c.callTarget != nil) { faceTime(c, audio: true) },
         MItem("Prepare AI Reply Draft", enabled: c.isLive && s.aiEnabled && s.aiDraftIMessage) { s.prepareDraft(for: c) }]
    }
    static func openFind() { WinMgr.shared.close("find"); WinMgr.shared.open("find", "Find – ICQ White Pages", FindView.size.width, FindView.size.height, resizable: Theme.isModern) { FindView() } }
    static func openActive() { WinMgr.shared.close("active"); WinMgr.shared.open("active", "ICQ ActiveList", ActiveListView.size.width, ActiveListView.size.height, resizable: Theme.isModern) { ActiveListView() } }
    /// Random Chat: a made-up chat partner (an AI chatbot with a random persona; without an AI key it answers with sample lines).
    static let randoms: [(String, String, String)] = [
        ("RetroRita", "technerd", "A 1999 computer enthusiast who loves modems, Winamp and LAN parties."),
        ("NightOwl_99", "friend", "A friendly night owl who is up too late and loves talking about music, games and life."),
        ("SunnyDay_", "friend", "A cheerful, curious person who likes asking questions and sharing small joys."),
        ("QuakeKid", "gaming", "A gamer from the e-sports scene who talks about frag movies, clans and ping times."),
        ("MissMidi", "technerd", "A tracker-music fan who talks about MIDI files, demoscene and old sound cards."),
        ("PixelPete", "gaming", "A retro gaming collector who loves pixel art and arcade stories."),
        ("DeepThought", "mentor", "A calm, thoughtful person who likes philosophical small talk and good advice."),
        ("CyberGran", "family", "A warm grandmother who just discovered the internet and asks for help with funny questions.")]
    static func randomChat() {
        guard !s.uin.isEmpty else { return }
        let r = randoms.randomElement()!
        var name = r.0, n = 2; while s.contacts.contains(where: { $0.name == name }) { name = r.0 + String(n); n += 1 }
        guard let c = s.addBot(name, persona: r.2, initiative: false, preset: r.1) else { return }
        openSend(c.uin)
    }
    /// Forward / Request Chat: asks first, then sends exactly like the send window would.
    static func forward(_ text: String, files: [String], from uin: String) {
        let targets = s.contacts.filter { $0.uin != uin && (!$0.isLive || ($0.isWA ? s.waEnabled : s.bridgeEnabled)) }
        guard !targets.isEmpty, !(text.isEmpty && files.isEmpty) else { NSSound.beep(); return }
        popMenu(targets.map { c in MItem("Forward to " + c.name) {
            retroBox("Forward message?", "Send this message to \(c.name)?", icon: "question32", buttons: ["Send", "Cancel"]) { if $0 == 0 { s.sendText(to: c.uin, text, files: files) } }
        } })
    }
    static func requestChat(_ uin: String) {
        guard let c = s.contact(uin) else { return }
        let text = "Hi \(c.name), do you have time for a chat? (ICQ chat request)"
        retroBox("Request chat?", "Send \u{201C}\(text)\u{201D} to \(c.name)?", icon: "question32", buttons: ["Send", "Cancel"]) { if $0 == 0 { s.sendText(to: uin, text) } }
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

    static func statusItems() -> [NSMenuItem] {
        Status.allCases.map { st in MItem(st.menuLabel, icon: st.rawValue, checked: s.status == st) { setStatus(st) } }
            + [NSMenuItem.separator(), MItem("What Did I Miss?", enabled: s.aiEnabled && s.bridgeEnabled) { s.summarizeUnread(manual: true) }]
    }
    static func statusMenu() {
        let na = { comingSoon() }
        func st(_ x: Status) -> RMItem { RMItem(title: x.menuLabel, icon: x.rawValue, fn: { setStatus(x) }) }
        popRMenu([
            RMItem(title: "Random Chat", icon: "random", children: [RMItem(title: "Find Random User", fn: { randomChat() })] + ["Available For Random Chat", "My Random Chat Settings"].map { RMItem(title: $0, fn: na) }),
            RMItem(title: "Online Status", header: true),
            st(.online), st(.ffc), RMItem(sep: true), st(.away), st(.na), RMItem(sep: true), st(.occupied), st(.dnd), RMItem(sep: true), st(.invisible), st(.offline),
        ])
    }
    static let defaultPage = "http://myretromac.app/"
    static var myPage: String { UserDefaults.standard.string(forKey: "myPageURL") ?? defaultPage }
    static func openURL(_ u: String) { if let url = URL(string: u) { NSWorkspace.shared.open(url) } }
    static func openApp(_ name: String) { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/\(name).app")) }
    /// Asks for one line of text in a themed window; empty or Cancel does nothing.
    static var askHandler: ((String) -> Void)?
    static func askText(_ title: String, _ label: String, _ initial: String = "", ok: @escaping (String) -> Void) {
        askHandler = ok
        WinMgr.shared.close("ask")
        WinMgr.shared.open("ask", title, AskView.size.width, AskView.size.height) { AskView(label: label, text: initial) }
    }
    static func editMyPage() {
        askText("Edit My ICQ Page", "Address of your own page (leave the default to use \(defaultPage)):", myPage) { u in
            UserDefaults.standard.set(u == defaultPage ? nil : (u.contains("://") ? u : "https://" + u), forKey: "myPageURL")
        }
    }
    /// New Reminders item / Notes note: the text is escaped and handed to AppleScript.
    static func newEntry(_ title: String, _ label: String, script: @escaping (String) -> String) {
        askText(title, label) { t in
            let src = script(t.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))
            DispatchQueue.global().async {
                var err: NSDictionary?; NSAppleScript(source: src)?.executeAndReturnError(&err)
                if let e = err { DispatchQueue.main.async { notice(((e[NSAppleScript.errorNumber] as? Int) == -1743) ? "Not allowed yet: enable ICQuel under Privacy & Security > Automation." : "Could not create the entry: \(e[NSAppleScript.errorMessage] as? String ?? "error")") } }
            }
        }
    }
    private static func na() { comingSoon() }
    private static func stub(_ titles: [String]) -> [RMItem] { titles.map { RMItem(title: $0, fn: na) } }
    /// The ICQ feature entries shared by the System Menu and the tray menu (icons matched from the original screenshot).
    static func icqEntries() -> [RMItem] {
        [RMItem(title: "My ICQ Page", icon: "m_page", children: [RMItem(title: "Go To My ICQ Page", fn: { openURL(myPage) }), RMItem(title: "Edit My ICQ Page", fn: { editMyPage() })]),
         RMItem(title: "Reminder", icon: "m_reminder", children: [RMItem(title: "Open Reminders List", fn: { openApp("Reminders") }), RMItem(title: "New Reminder", fn: { newEntry("New Reminder", "Remind me to:") { "tell application \"Reminders\" to make new reminder with properties {name:\"\($0)\"}" } })]),
         RMItem(title: "Notes", icon: "m_notes", children: stub(["New Note", "Open Notes"])),
         RMItem(title: "ToDo", icon: "m_todo", children: [RMItem(title: "New ToDo", fn: { newEntry("New ToDo", "ToDo:") { "tell application \"Notes\" to make new note with properties {body:\"<div>☐ \($0)</div>\"}" } }), RMItem(title: "Open ToDo List", fn: { openApp("Notes") })]),
         RMItem(title: "Email", icon: "m_email", children: stub(["Send Email", "Send Email + Notify By ICQ", "Check Email", "Email Signature", "Email Center"])),
         RMItem(title: "Phone - \"Follow Me\"", icon: "m_phone", children: stub(["Send Phone Call Request", "Find Phone# and Dial", "Update Phone \"Follow Me\" info"])),
         RMItem(title: "Message Archive", icon: "m_archive", children: [RMItem(title: "Open Message Archive", fn: { openArchive() })]),
         RMItem(title: "ICQ White Pages", icon: "m_white", children: ["Search White Pages", "Find Users"].map { RMItem(title: $0, fn: { openFind() }) }),
         RMItem(title: "ICQ Active List", icon: "m_active", children: [RMItem(title: "Show ICQ ActiveLists", fn: { openActive() }), RMItem(title: "ICQ ActiveList Preferences", fn: { openPrefs(1) })]),
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
            submenu("Phone", list(["Send Phone Call Request", "Find Phone# and Dial"])),
            submenu("Random", [MItem("Find Random User") { randomChat() }, NSMenuItem.separator()] + list(["Available For Random Chat", "My Random Chat Settings"])),
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
        NSApp.setActivationPolicy(ICQ.dockHidden ? .accessory : .regular)
        Assets.applyIcon()
        ICQ.tray = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        ICQ.tray?.button?.target = self; ICQ.tray?.button?.action = #selector(trayClick); ICQ.tray?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp]); ICQ.tray?.isVisible = ICQ.dockHidden
        buildMenu()
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in Store.shared.flash.toggle() }
        Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { _ in Store.shared.shuffleOne() }
        ICQ.start()
        #if DEBUG
        DebugHooks.run()
        #endif
        NSApp.activate(ignoringOtherApps: true)
    }
    /// icquel://status/<away|dnd|online|...>: lets a Shortcuts Focus automation set the status.
    func application(_ app: NSApplication, open urls: [URL]) {
        for u in urls where u.scheme == "icquel" && u.host == "status" {
            if let st = Status(rawValue: u.lastPathComponent.lowercased()), !Store.shared.uin.isEmpty { Store.shared.status = st; Store.shared.save(); ICQ.refreshTray() }
        }
    }
    func applicationWillTerminate(_ n: Notification) { WABridge.shared.stop() }
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
