#if DEBUG
import AppKit

/// Debug builds only (DEBUG_BUILD=1 ./build.sh): scripted renders of the app's own windows for tools/screenshots.sh.
/// ICQ_SNAPSHOT=<dir> writes every step's windows as PNG and quits; ICQ_ONLY=a,b limits the steps; ICQ_THEME / ICQ_SCALE / ICQ_LIGHT / ICQ_PACK / ICQ_STEP pick the look.
enum DebugHooks {
    /// Made-up data for screenshots (the debug build always runs on a throw-away store): random ICQ-style nicknames and random first names for iMessage contacts.
    static let nicks = ["PixelPanda", "NightOwl99", "Sk8erGal", "ByteBandit", "MoonWalker", "Pretzel_X", "NeoTrinity", "RetroRita", "CyberCat42", "SunnyDay_", "LazerLemon", "TurboToast", "Glitter_Fox", "Zero_Cool_", "WaveRider", "Dr_Modem"]
    static let firstNames = ["Lena", "Jonas", "Mara", "Felix", "Nora", "Ben", "Ida", "Theo", "Mia", "Paul", "Clara", "Emil", "Hanna", "Leon", "Sofia", "Luca"]
    /// ICQ_OPTS=tabs,search,showIMessage switches those main-window options off (to check that the settings take effect).
    static func offOpts() {
        if ProcessInfo.processInfo.environment["ICQ_SIMPLE"] != nil { Store.shared.simpleMode = true }
        guard let v = ProcessInfo.processInfo.environment["ICQ_OPTS"], var d = (try? JSONEncoder().encode(Store.shared.opts)).flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) else { return }
        for k in v.split(separator: ",") { d[String(k)] = false }
        if let data = try? JSONSerialization.data(withJSONObject: d), let o = try? JSONDecoder().decode(MainOpts.self, from: data) { Store.shared.opts = o }
    }
    static func dummyData() {
        let s = Store.shared; guard s.contacts.isEmpty else { return }
        var pool = nicks.shuffled(), names = firstNames.shuffled()
        s.uin = String(Int.random(in: 10_000_000...99_999_999)); s.nick = pool.removeLast()
        s.contacts = (0..<8).map { _ in Contact(name: pool.removeLast(), uin: Store.newUin()) }
        s.simulatePresence()
        for _ in 0..<3 { _ = s.addBridgeContact(names.removeLast(), handle: "+4915\(Int.random(in: 10_000_000...99_999_999))") }
        _ = s.addBot("Pixel", persona: "A friendly chat buddy.", preset: "friend"); s.aiEnabled = true; s.bridgeEnabled = true
    }
    static func dummyChat() {
        let s = Store.shared
        guard let c = s.contacts.first(where: { !$0.isLive && s.online.contains($0.uin) }) ?? s.contacts.first else { return }
        let now = Date()
        s.log(c.uin, "in", "hey, wassup?", now.addingTimeInterval(-420)); s.log(c.uin, "out", "not much, just downloaded the new Winamp :-)", now.addingTimeInterval(-360))
        s.log(c.uin, "in", "nice! a/s/l? lol, kidding", now.addingTimeInterval(-300))
        s.deliver(to: c, text: "r u coming to the LAN party on saturday?")
        ICQ.openIncoming(c.uin)
    }
    static func run() {
        if ProcessInfo.processInfo.environment["ICQ_SELFTEST"] != nil { SelfTest.run() }
        if let t = ProcessInfo.processInfo.environment["ICQ_THEMELOOP"] {   // changes the theme with the preferences open and counts the window rebuilds
            DebugHooks.dummyData(); ICQ.openMain(); ICQ.openPrefs(0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { NotificationCenter.default.post(name: Notification.Name("ICQDebugTheme"), object: t) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { print("relayouts after a theme change:", ICQ.relayouts); exit(ICQ.relayouts <= 2 ? 0 : 1) }
        }
        if ProcessInfo.processInfo.environment["ICQ_LIGHT"] != nil { NSApp.appearance = NSAppearance(named: .aqua) }   // self-test only
        if let dir = ProcessInfo.processInfo.environment["ICQ_SNAPSHOT"] { // scripted self-test: ICQ_PACK=<theme folder> imports and selects it first
            if let pk = ProcessInfo.processInfo.environment["ICQ_PACK"] {
                do { let t = try Assets.importPack(from: URL(fileURLWithPath: pk)); Assets.select("pack:" + t.id); print("imported", t.name) } catch { print("import failed:", error.localizedDescription) }
            }
            let steps: [(String, () -> Void)] = [("main", { DebugHooks.dummyData(); DebugHooks.offOpts(); ICQ.openMain() }), ("live", { DebugHooks.dummyData(); ICQ.openMain(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Store.shared.opts.tabs = false; Store.shared.opts.showIMessage = false } }), ("setup", { ICQ.start(force: true) }), ("conn", { ICQ.connecting() }), ("edit", { if let c = Store.shared.contacts.first { ICQ.openContactEdit(c.uin) } }),
                                       ("incoming", { DebugHooks.dummyChat() }), ("hidedemo", { Store.shared.hideDemo = true; ICQ.openMain() }),
                ("im-in", { let s = Store.shared; if let c = s.contacts.first(where: \.isLive) { s.log(c.uin, "in", "Are we still on for tonight?"); s.deliver(to: c, text: "See you at 8?"); ICQ.openIncoming(c.uin) } }),
                ("im-send", { let s = Store.shared; if let c = s.contacts.first(where: \.isLive) { s.aiDrafts[c.uin] = "Yes, 8 works for me. See you there!"; ICQ.openSend(c.uin) } }), ("send", { if let c = Store.shared.contacts.first { ICQ.openSend(c.uin) } }), ("about", { ICQ.openAbout() }), ("add", { ICQ.openAdd() }), ("p0", { ICQ.openPrefs(0) }), ("p1", { ICQ.openPrefs(1) }), ("p2", { ICQ.openPrefs(2) }), ("p3", { ICQ.openPrefs(3) }), ("p4", { ICQ.openPrefs(4) }), ("archive", { DebugHooks.dummyData(); DebugHooks.dummyChat(); ICQ.openArchive() }), ("find", { DebugHooks.dummyData(); DebugHooks.dummyChat(); ICQ.openFind() }), ("active", { DebugHooks.dummyData(); DebugHooks.dummyChat(); ICQ.openActive() }), ("gif", { DebugHooks.dummyData(); if let c = Store.shared.contacts.first { Attach.giphy(c.uin) } }), ("p5", { ICQ.openPrefs(5) }), ("p6", { ICQ.openPrefs(6) }), ("p7", { ICQ.openPrefs(7) }), ("p8", { ICQ.openPrefs(8) }), ("away", { ICQ.confirmDelete("x") })]
            let only = ProcessInfo.processInfo.environment["ICQ_ONLY"]?.split(separator: ",").map(String.init)
            for (i, st) in steps.filter({ only == nil || only!.contains($0.0) }).enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(i) * 1.2) { WinMgr.shared.closeAll(); st.1(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { WinMgr.shared.snapshot(to: dir, prefix: st.0 + "-") } }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(steps.filter({ only == nil || only!.contains($0.0) }).count) * 1.2 + 1) { NSApp.terminate(nil) }
        }
    }
}
#endif
