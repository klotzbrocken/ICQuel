#if DEBUG
import AppKit

/// Debug builds only (DEBUG_BUILD=1 ./build.sh): scripted renders of the app's own windows for tools/screenshots.sh.
/// ICQ_SNAPSHOT=<dir> writes every step's windows as PNG and quits; ICQ_ONLY=a,b limits the steps; ICQ_THEME / ICQ_SCALE / ICQ_LIGHT / ICQ_PACK / ICQ_STEP pick the look.
enum DebugHooks {
    static func run() {
        if ProcessInfo.processInfo.environment["ICQ_LIGHT"] != nil { NSApp.appearance = NSAppearance(named: .aqua) }   // self-test only
        if let dir = ProcessInfo.processInfo.environment["ICQ_SNAPSHOT"] { // scripted self-test: ICQ_PACK=<theme folder> imports and selects it first
            if let pk = ProcessInfo.processInfo.environment["ICQ_PACK"] {
                do { let t = try Assets.importPack(from: URL(fileURLWithPath: pk)); Assets.select("pack:" + t.id); print("imported", t.name) } catch { print("import failed:", error.localizedDescription) }
            }
            let steps: [(String, () -> Void)] = [("main", { Store.shared.uin = "10001"; Store.shared.nick = "Maik"; if Store.shared.contacts.isEmpty { Store.shared.contacts = seedContacts.prefix(6).map { Contact(name: $0, uin: Store.newUin()) }; Store.shared.simulatePresence(); _ = Store.shared.addBridgeContact("Anna (iMessage)", handle: "+491511234567") }; ICQ.openMain() }), ("setup", { ICQ.start(force: true) }), ("conn", { ICQ.connecting() }), ("edit", { if let c = Store.shared.contacts.first { ICQ.openContactEdit(c.uin) } }),
                                       ("incoming", { if let c = Store.shared.contacts.first { Store.shared.deliver(to: c, text: "Hey, bist du noch da"); Store.shared.deliver(to: c, text: "second"); print("unread before opening:", Store.shared.unreadCount); ICQ.openIncoming(c.uin); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { print("unread after opening:", Store.shared.unreadCount) } } }), ("send", { if let c = Store.shared.contacts.first { ICQ.openSend(c.uin) } }), ("about", { ICQ.openAbout() }), ("add", { ICQ.openAdd() }), ("p0", { ICQ.openPrefs(0) }), ("p1", { ICQ.openPrefs(1) }), ("p2", { ICQ.openPrefs(2) }), ("p3", { ICQ.openPrefs(3) }), ("p4", { ICQ.openPrefs(4) }), ("p6", { ICQ.openPrefs(6) }), ("p7", { ICQ.openPrefs(7) }), ("p8", { ICQ.openPrefs(8) }), ("away", { ICQ.confirmDelete("x") })]
            let only = ProcessInfo.processInfo.environment["ICQ_ONLY"]?.split(separator: ",").map(String.init)
            for (i, st) in steps.filter({ only == nil || only!.contains($0.0) }).enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(i) * 1.2) { WinMgr.shared.closeAll(); st.1(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { WinMgr.shared.snapshot(to: dir, prefix: st.0 + "-") } }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(steps.filter({ only == nil || only!.contains($0.0) }).count) * 1.2 + 1) { NSApp.terminate(nil) }
        }
    }
}
#endif
