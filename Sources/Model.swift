import SwiftUI
import AppKit
import Security

enum Status: String, CaseIterable, Codable {
    case online, away, na, occupied, dnd, ffc, invisible, offline
    var panelLabel: String { self == .online ? "Online" : label }
    var menuLabel: String { // wording of the Online Status menu (reference screenshot)
        switch self {
        case .online: "Available/Connect"; case .away: "Away"; case .na: "N/A (Extended Away)"; case .occupied: "Occupied (Urgent Msgs)"
        case .dnd: "DND (Do not Disturb)"; case .ffc: "Free For Chat"; case .invisible: "Privacy (Invisible)"; case .offline: "Offline/Disconnect"
        }
    }
    var label: String { // status labels
        switch self {
        case .online: "Online"; case .away: "Away"; case .na: "N/A (Extended Away)"
        case .occupied: "Occupied (Urgent Msgs)"; case .dnd: "DND"; case .ffc: "Free For Chat"
        case .invisible: "Invisible"; case .offline: "Offline"
        }
    }
}
struct Contact: Identifiable, Codable, Hashable {
    var name: String; var uin: String; var persona: String? = nil
    var assistant: Bool? = nil     // bot acts like a normal AI assistant (longer, complete answers)
    var initiative: Bool? = nil    // bot writes first from time to time (default on)
    var preset: String? = nil      // relationship preset id (see Presets); nil/"custom" = description only
    var bridge: String? = nil      // phone number / e-mail of an iMessage contact reached through the Messages bridge
    var email: String? = nil, phone: String? = nil   // optional details for "Send Mail" and FaceTime
    var isLive: Bool { bridge != nil }
    /// Address for "Send Mail": the e-mail field, or the iMessage handle when that is an e-mail address.
    var mailAddr: String? { if let e = email, !e.isEmpty { return e }; if let b = bridge, b.contains("@") { return b }; return nil }
    /// Number / address for FaceTime: the phone field, or the iMessage handle.
    var callTarget: String? { if let p = phone, !p.isEmpty { return p }; return bridge }
    var id: String { uin }
    var isBot: Bool { persona != nil }
    var isAssistant: Bool { assistant ?? false }
    var startsChats: Bool { initiative ?? true }
}
/// What the classic contact window shows (Preferences > Main Window).
struct MainOpts: Codable, Equatable {
    // Retro / classic window
    var tabs = true, search = true, icqNow = true, services = true
    var btnInstructions = true, btnRandom = true, btnWeb = true, btnCool = true
    var showOffline = true, showIMessage = true, alwaysOnTop = false
    // Modern Mac window
    var mProfile = true, mToolbar = true, mButtons = true, mOffline = true, mIMessage = true, mOnTop = false
    init() {}
    init(from d: Decoder) throws {   // older stores lack the newer keys: keep their defaults
        self.init()
        let c = try d.container(keyedBy: K.self)
        func g(_ k: K, _ v: inout Bool) { if let x = try? c.decodeIfPresent(Bool.self, forKey: k) { v = x } }
        g(.tabs, &tabs); g(.search, &search); g(.icqNow, &icqNow); g(.services, &services); g(.btnInstructions, &btnInstructions); g(.btnRandom, &btnRandom)
        g(.btnWeb, &btnWeb); g(.btnCool, &btnCool); g(.showOffline, &showOffline); g(.showIMessage, &showIMessage); g(.alwaysOnTop, &alwaysOnTop)
        g(.mProfile, &mProfile); g(.mToolbar, &mToolbar); g(.mButtons, &mButtons); g(.mOffline, &mOffline); g(.mIMessage, &mIMessage); g(.mOnTop, &mOnTop)
    }
    enum K: String, CodingKey { case tabs, search, icqNow, services, btnInstructions, btnRandom, btnWeb, btnCool, showOffline, showIMessage, alwaysOnTop, mProfile, mToolbar, mButtons, mOffline, mIMessage, mOnTop }
}
struct Msg: Codable { var dir: String; var text: String; var t: Date }
enum FreqMode: String, Codable { case hour, interval }

let dummyMessages = [
    "hey, wassup?", "a/s/l?", "lol that was so funny", "brb, mom needs the phone line",
    "did u see the new Matrix trailer??", "check out my new homepage on geocities",
    "anyone up for Quake 2 tonight?", "my modem keeps dropping the connection again...",
    "u there?", "just downloaded the new Winamp, it rocks", "can u send me that mp3 u mentioned?",
    "gotta go, dinner time. cya later!", "have u heard about Napster? crazy stuff", "omg my pc crashed again :(",
    "happy birthday!!! :-)", "r u coming to the LAN party on saturday?", "what's ur favorite band?",
    "i'm so bored at school today", "added u to my contact list, finally found u!",
    "can u help me with my html? my frames are broken", "did u get my email?", "ttyl, my sister wants the computer",
    "wanna chat later tonight? i'll be on after 8", "lol ur nick is so cool", "just got a 56k modem, finally!",
    "hey, long time no see! how r u?", "sorry, i was afk for a while", "have u tried the new ICQ version yet?",
    "me too! :-D", "ok cool, talk to u tomorrow then",
]
let seedContacts = ["Cool_Dude99", "Angel", "Matrix_Neo", "Sarah", "Sk8erBoy", "Mike"]

private struct Saved: Codable {
    var uin = "", nick = "", status = Status.online, sounds = true
    var contacts: [Contact] = [], freqEnabled = true, freqMode = FreqMode.hour, minutes = 15, demoFirst = true
    var aiEnabled = false, history: [String: [Msg]] = [:]
    var apiModel: String? = nil
    var simpleMode: Bool? = nil
    var botInit: Bool? = nil, botMin: Int? = nil, botMax: Int? = nil
    var opts: MainOpts? = nil
    var appName: String? = nil
    var bridgeEnabled: Bool? = nil, bridgeLast: Int64? = nil
    var autoAway: Bool? = nil, autoAwayMin: Int? = nil, autoAwayDND: Bool? = nil
}

/// Contacts, bots, history and settings live in ~/Library/Application Support/ICQ99b/store.json (one backup copy is kept),
/// not in UserDefaults: resetting preferences or rebuilding the app must never lose the user's chatbots.
/// Test runs (ICQ_SNAPSHOT) use a throw-away folder and never touch real data.
enum Persist {
    #if DEBUG
    static var testMode: Bool { ProcessInfo.processInfo.environment["ICQ_SNAPSHOT"] != nil }
    #else
    static var testMode: Bool { false }
    #endif
    static var dir: URL {
        let fm = FileManager.default
        if testMode { return fm.temporaryDirectory.appendingPathComponent("icq-test-\(ProcessInfo.processInfo.processIdentifier)") }
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ICQuel")
    }
    /// Data written by the first versions (folder "ICQ99b") is copied over once.
    static var file: URL { dir.appendingPathComponent("store.json") }
    private static var backedUp = false
    static func load() -> Data? {
        try? Data(contentsOf: file)
    }
    static func write(_ d: Data) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        if !backedUp, fm.fileExists(atPath: file.path) { try? fm.removeItem(at: dir.appendingPathComponent("store.bak")); try? fm.copyItem(at: file, to: dir.appendingPathComponent("store.bak")); backedUp = true }
        try? d.write(to: file, options: .atomic)
    }
}

enum Keychain { // the AI API key lives in the login keychain, not in UserDefaults
    private static let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "ICQ99b", kSecAttrAccount as String: "ai-api-key"]
    static func set(_ v: String) {
        SecItemDelete(base as CFDictionary)
        guard !v.isEmpty else { return }
        var a = base; a[kSecValueData as String] = Data(v.utf8); SecItemAdd(a as CFDictionary, nil)
    }
    static func get() -> String {
        var q = base; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var r: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return "" }
        return String(decoding: d, as: UTF8.self)
    }
}

final class Store: ObservableObject {
    static let shared = Store()
    @Published var uin = ""
    @Published var nick = ""
    @Published var status = Status.online
    @Published var sounds = true
    @Published var contacts: [Contact] = []
    @Published var freqEnabled = true
    @Published var freqMode = FreqMode.hour
    @Published var minutes = 15
    @Published var demoFirst = true
    @Published var aiEnabled = false
    @Published var apiModel = "claude-haiku-5-5"
    @Published var simpleMode = false
    @Published var botInit = true
    @Published var opts = MainOpts()
    @Published var appName = "ICQuel"
    @Published var bridgeEnabled = false
    @Published var bridgeStatus = "Off"
    var bridgeLast: Int64 = 0
    @Published var autoAway = false          // switch to Away / DND after some minutes without keyboard or mouse use
    @Published var autoAwayMin = 15
    @Published var autoAwayDND = false       // false = Away, true = Do Not Disturb
    @Published var botMin = 5
    @Published var botMax = 20
    @Published var history: [String: [Msg]] = [:]
    @Published var online = Set<String>()
    @Published var unread: [String: [Msg]] = [:]
    @Published var flash = false
    @Published var selected: String?
    /// The AI key lives in the Keychain. It is loaded in the background: the system may ask for permission (the app is re-signed on every build),
    /// and that prompt must never block the UI or app start.
    var apiKey = "" { didSet { if !loadingKey { Keychain.set(apiKey) } } }
    @Published var keyLoaded = false
    private var loadingKey = false

    private var plan: [Date] = [], windowEnd = Date(), nextAt = Date(), lastMsg = -1
    private var sched: Timer?, first: Timer?

    init() {
        if let d = Persist.load(), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            uin = s.uin; nick = s.nick; status = s.status; sounds = s.sounds; contacts = s.contacts
            freqEnabled = s.freqEnabled; freqMode = s.freqMode; minutes = s.minutes; demoFirst = s.demoFirst
            aiEnabled = s.aiEnabled; history = s.history; apiModel = s.apiModel ?? "claude-haiku-5-5"; simpleMode = s.simpleMode ?? false
            botInit = s.botInit ?? true; botMin = s.botMin ?? 5; botMax = s.botMax ?? 20; opts = s.opts ?? MainOpts(); appName = s.appName ?? "ICQuel"; bridgeEnabled = s.bridgeEnabled ?? false; bridgeLast = s.bridgeLast ?? 0
            autoAway = s.autoAway ?? false; autoAwayMin = s.autoAwayMin ?? 15; autoAwayDND = s.autoAwayDND ?? false
        }
        online = Set(contacts.filter { $0.isBot || $0.isLive }.map(\.uin))   // AI chatbots and bridged contacts are always shown online
    }
    private var loadStarted = false
    /// Loads the key only when it is needed (AI reply or the AI prefs page), never at app start.
    func loadKeyAsync(_ done: (() -> Void)? = nil) {
        guard !keyLoaded else { done?(); return }
        guard !Persist.testMode else { keyLoaded = true; done?(); return }
        guard !loadStarted else { return }
        loadStarted = true
        DispatchQueue.global(qos: .utility).async {
            let k = Keychain.get()
            DispatchQueue.main.async { self.loadingKey = true; self.apiKey = k; self.loadingKey = false; self.keyLoaded = true; done?() }
        }
    }
    func save() {
        let s = Saved(uin: uin, nick: nick, status: status, sounds: sounds, contacts: contacts, freqEnabled: freqEnabled,
                      freqMode: freqMode, minutes: minutes, demoFirst: demoFirst, aiEnabled: aiEnabled, history: history, apiModel: apiModel, simpleMode: simpleMode, botInit: botInit, botMin: botMin, botMax: botMax, opts: opts, appName: appName, bridgeEnabled: bridgeEnabled, bridgeLast: bridgeLast, autoAway: autoAway, autoAwayMin: autoAwayMin, autoAwayDND: autoAwayDND)
        if let d = try? JSONEncoder().encode(s) { Persist.write(d) }
    }
    static func newUin() -> String { String(Int.random(in: 10_000_000...99_999_999)) }
    func contact(_ uin: String) -> Contact? { contacts.first { $0.uin == uin } }

    @discardableResult func add(_ name: String, uin: String = "") -> Contact? {
        let n = name.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { return nil }
        let u = uin.trimmingCharacters(in: .whitespaces)
        let c = Contact(name: n, uin: u.isEmpty ? Store.newUin() : u)
        contacts.append(c); online.insert(c.uin); save(); return c
    }
    func remove(_ uin: String) { contacts.removeAll { $0.uin == uin }; unread[uin] = nil; online.remove(uin); save() }
    func log(_ uin: String, _ dir: String, _ text: String, _ t: Date = Date()) {
        history[uin, default: []].append(Msg(dir: dir, text: text, t: t))
        if history[uin]!.count > 500 { history[uin]!.removeFirst() }
        save()
    }
    /// Away / N/A / Occupied / Do Not Disturb: no sample messages and no chatbot messages of their own (replies to something you wrote still come).
    /// Real iMessages are never held back.
    var quiet: Bool { [.away, .na, .occupied, .dnd].contains(status) }
    private var idleTimer: Timer?, autoApplied = false, prevStatus = Status.online
    func startIdleWatch() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.idleCheck() }
    }
    func stopIdleWatch() { idleTimer?.invalidate() }
    private func idleCheck() {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        let target: Status = autoAwayDND ? .dnd : .away
        if autoApplied {
            if status != target { autoApplied = false }                       // changed by hand meanwhile: leave it alone
            else if idle < 5 { status = prevStatus; autoApplied = false; save(); ICQ.refreshTray() }
        } else if autoAway, !uin.isEmpty, idle >= Double(max(1, autoAwayMin)) * 60, status == .online || status == .ffc {
            prevStatus = status; status = target; autoApplied = true; ICQ.refreshTray()
        }
    }
    func simulatePresence() { online = Set(contacts.filter { $0.isBot || $0.isLive || Double.random(in: 0...1) < 0.65 }.map(\.uin)) }
    func shuffleOne() { // simulated contacts come and go; AI chatbots never leave
        guard !uin.isEmpty, status != .offline, let c = contacts.filter({ !$0.isBot && !$0.isLive }).randomElement() else { return }
        if online.contains(c.uin) { online.remove(c.uin) } else { online.insert(c.uin) }
    }

    // message scheduler: 1-3 messages per random hour window, or every X minutes
    func resetSched() {
        stopSched()
        guard !uin.isEmpty, freqEnabled else { return }
        planNow()
        sched = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }
    func stopSched() { sched?.invalidate(); first?.invalidate(); plan = [] }
    func startDemoFirst() { first = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in self?.deliver() } }
    private func planNow() {
        let now = Date()
        if freqMode == .hour {
            windowEnd = now.addingTimeInterval(3600)
            plan = (0..<Int.random(in: 1...3)).map { _ in now.addingTimeInterval(.random(in: 20..<3600)) }.sorted()
        } else { nextAt = now.addingTimeInterval(Double(minutes) * 60) }
    }
    private func tick() {
        let now = Date()
        if freqMode == .hour {
            if let p = plan.first, now >= p { plan.removeFirst(); deliver() }
            if now >= windowEnd { planNow() }
        } else if now >= nextAt { deliver(); nextAt = now.addingTimeInterval(Double(minutes) * 60) }
    }
    func deliver(to chosen: Contact? = nil, text: String? = nil) {
        if chosen == nil && quiet { return }                                  // scheduled sample message while Away / DND
        guard status != .offline, let c = chosen ?? contacts.filter({ online.contains($0.uin) && !$0.isLive }).randomElement() else { return }
        var t = text ?? ""
        if text == nil { var i: Int; repeat { i = Int.random(in: 0..<dummyMessages.count) } while i == lastMsg; lastMsg = i; t = dummyMessages[i] }
        let m = Msg(dir: "in", text: t, t: Date())
        unread[c.uin, default: []].append(m)
        log(c.uin, "in", m.text, m.t)
        Sound.event("message")
        NSApp.requestUserAttention(.informationalRequest)
        // like ICQ: no pop-up, the contact flashes an envelope until you open it (an already open session just keeps running)
    }
    @discardableResult func addBot(_ name: String, persona: String, assistant: Bool = false, initiative: Bool = true, preset: String = "custom") -> Contact? {
        let n = name.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { return nil }
        let c = Contact(name: n, uin: Store.newUin(), persona: persona.trimmingCharacters(in: .whitespacesAndNewlines), assistant: assistant, initiative: initiative, preset: preset)
        contacts.append(c); online.insert(c.uin); save(); return c
    }
    func editBot(_ uin: String, name: String, persona: String, assistant: Bool, initiative: Bool, preset: String = "custom") {
        guard let i = contacts.firstIndex(where: { $0.uin == uin }) else { return }
        contacts[i].name = name.trimmingCharacters(in: .whitespaces); contacts[i].persona = persona.trimmingCharacters(in: .whitespacesAndNewlines)
        contacts[i].assistant = assistant; contacts[i].initiative = initiative; contacts[i].preset = preset; save()
    }
    func toggleAssistant(_ uin: String) {
        guard let i = contacts.firstIndex(where: { $0.uin == uin }) else { return }
        contacts[i].assistant = !(contacts[i].assistant ?? false); save()
    }

    /// The user just sent a message. Simulated contacts answer with a dummy line, but only while they are online;
    /// AI chatbots (always online) answer through the AI if enabled and keyed, otherwise with a dummy line.
    func botReply(_ uin: String) {
        if let c = contact(uin), let h = c.bridge {       // a real iMessage contact: hand the message to Messages, never auto-answer
            guard bridgeEnabled else { notice("The Messages bridge is off.\nTurn it on in Preferences > Bridge."); return }
            guard status != .offline else { notice("You are offline."); return }
            guard let last = history[uin]?.last, last.dir == "out" else { return }
            Bridge.send(last.text, to: h) { err in if let err { notice("Messages could not send this message:\n\(err)") } }
            return
        }
        guard let c = contact(uin), status != .offline else { return }
        guard let persona = c.persona else {
            guard online.contains(uin) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 3.0...8.0)) { if self.online.contains(uin) && self.status != .offline { self.deliver(to: c) } }
            return
        }
        if aiEnabled && !keyLoaded { loadKeyAsync { self.botReply(uin) }; return }
        let hist = history[uin] ?? [], key = apiKey, model = apiModel, me = nick
        if aiEnabled && !key.isEmpty {
            Task {
                do {
                    let text = try await AIChat.reply(nick: c.name, persona: persona, user: me, history: hist, key: key, model: model, assistant: c.isAssistant, preset: Presets.get(c.preset))
                    DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 1.0...2.5)) { self.deliver(to: c, text: text) }
                } catch { DispatchQueue.main.async { notice("AI chat error (\(c.name)): \(error.localizedDescription)") } }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 2.0...5.0)) { self.deliver(to: c) }
        }
    }

    // MARK: Messages bridge
    private var bridgeTimer: Timer?
    private var polling = false
    func startBridge() {
        bridgeTimer?.invalidate(); bridgeTimer = nil
        guard bridgeEnabled else { bridgeStatus = "Off"; return }
        switch Bridge.checkAccess() {
        case .ok:
            bridgeStatus = "Connected to Messages"
            if bridgeLast == 0, let top = Bridge.maxRowID() { bridgeLast = top; save() }       // never import old history
            bridgeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.bridgePoll() }
        case .noFullDiskAccess: bridgeStatus = "Needs Full Disk Access (System Settings > Privacy & Security)"
        case .missing: bridgeStatus = "Messages database not found"
        }
    }
    func stopBridge() { bridgeTimer?.invalidate(); bridgeTimer = nil }
    private func bridgePoll() {
        guard !polling, status != .offline, contacts.contains(where: \.isLive) else { return }
        polling = true; let after = bridgeLast
        let pending = contacts.compactMap { c -> (String, String, Int)? in
            guard let h = c.bridge, let n = unread[c.uin]?.count, n > 0 else { return nil }; return (c.uin, h, n)
        }
        DispatchQueue.global(qos: .utility).async {
            let msgs = Bridge.incoming(after: after)
            let states = pending.map { ($0.0, Bridge.unreadAmongLatest(handle: $0.1, n: $0.2)) }
            DispatchQueue.main.async {
                self.polling = false
                // read in the Messages app (on this Mac or another device) = read here as well
                var changed = false
                for (u, k) in states { if let cur = self.unread[u]?.count, k < cur { self.unread[u] = k == 0 ? nil : Array(self.unread[u]!.suffix(k)); changed = true } }
                if changed { ICQ.refreshTray() }
                guard let top = msgs.last?.rowid else { return }
                self.bridgeLast = top; self.save()
                for m in msgs { if let c = self.contacts.first(where: { $0.bridge.map { Bridge.same($0, m.handle) } ?? false }) { self.deliver(to: c, text: m.text) } }
            }
        }
    }
    @discardableResult func addBridgeContact(_ name: String, handle: String) -> Contact? {
        let n = name.trimmingCharacters(in: .whitespaces), h = handle.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !h.isEmpty else { return nil }
        let c = Contact(name: n, uin: Store.newUin(), bridge: h)
        contacts.append(c); online.insert(c.uin); save()
        DispatchQueue.global(qos: .utility).async {      // fill the history with the last 5 iMessages (needs Full Disk Access; silently skipped otherwise)
            let recent = Bridge.recent(handle: h, limit: 5)
            guard !recent.isEmpty else { return }
            DispatchQueue.main.async { self.history[c.uin] = recent.map { Msg(dir: $0.fromMe ? "out" : "in", text: $0.text, t: $0.date) }; self.save() }
        }
        return c
    }

    // MARK: chatbots that write first, at randomised intervals
    private var botNext: [String: Date] = [:]
    private var botTimer: Timer?
    func startBots() {
        botTimer?.invalidate()
        botTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.botTick() }
    }
    func stopBots() { botTimer?.invalidate(); botNext = [:] }
    private func gap(first: Bool) -> TimeInterval {
        let lo = max(1, min(botMin, botMax)), hi = max(lo, botMax)
        return first ? .random(in: 45...Double(lo) * 60) : .random(in: Double(lo) * 60...Double(hi) * 60)
    }
    private func botTick() {
        guard botInit, status != .offline, !quiet, !uin.isEmpty else { return }
        let now = Date()
        for c in contacts where c.isBot && c.startsChats {
            guard let n = botNext[c.uin] else { botNext[c.uin] = now.addingTimeInterval(gap(first: true)); continue }
            guard now >= n else { continue }
            if let last = history[c.uin]?.last, now.timeIntervalSince(last.t) < 120 { botNext[c.uin] = now.addingTimeInterval(60); continue } // chat in progress
            botNext[c.uin] = now.addingTimeInterval(gap(first: false)); botInitiate(c)
        }
    }
    func botInitiate(_ c: Contact) {
        guard let persona = c.persona, status != .offline, !quiet else { return }
        if aiEnabled && !keyLoaded { loadKeyAsync { self.botInitiate(c) }; return }
        guard aiEnabled, !apiKey.isEmpty else { deliver(to: c); return }
        let hist = history[c.uin] ?? [], key = apiKey, model = apiModel, me = nick
        Task {
            if let text = try? await AIChat.reply(nick: c.name, persona: persona, user: me, history: hist, key: key, model: model, assistant: c.isAssistant, initiate: true, preset: Presets.get(c.preset)) {
                DispatchQueue.main.async { self.deliver(to: c, text: text) }   // background failures stay silent
            }
        }
    }
    var unreadCount: Int { unread.values.reduce(0) { $0 + $1.count } }
}

enum Sound { // sound files of the active theme / built-in set
    private static var live: [NSSound] = []
    private static var last: [String: Date] = [:]
    private static let hold = ["msgtype": 1.6, "msgback": 0.5] // long typing samples: don't stack them on every keystroke
    /// Which original WAV plays for an event; changeable on Preferences > Sounds.
    static let defaults = ["online": "hello", "message": "chime", "chat": "pop", "url": "ping", "file": "drop", "external": "bell", "phone": "ring", "contact": "tick"]
    static func file(for event: String) -> String {
        if let u = (UserDefaults.standard.dictionary(forKey: "snd_files") as? [String: String])?[event], Assets.resource("sounds", u + ".wav") != nil { return u }
        return Assets.active?.pack.sounds?[event] ?? defaults[event] ?? event
    }
    static func setFile(_ f: String, for event: String) {
        var d = (UserDefaults.standard.dictionary(forKey: "snd_files") as? [String: String]) ?? [:]; d[event] = f; UserDefaults.standard.set(d, forKey: "snd_files")
    }
    /// Each event can be switched off on its own (Preferences > Sounds).
    static func isOn(_ e: String) -> Bool { UserDefaults.standard.object(forKey: e == "message" ? "snd_message" : "snd_on_" + e) as? Bool ?? true }
    static func setOn(_ e: String, _ v: Bool) { UserDefaults.standard.set(v, forKey: e == "message" ? "snd_message" : "snd_on_" + e) }
    static func event(_ e: String) { if isOn(e) { play(file(for: e)) } }
    static func play(_ name: String) {
        let s = Store.shared; guard s.sounds, s.status != .dnd else { return }
        if let h = hold[name], let t = last[name], Date().timeIntervalSince(t) < h { return }
        last[name] = Date()
        if let f = Assets.resource("sounds", name + ".wav"), let snd = NSSound(contentsOfFile: f, byReference: false) { live.append(snd); snd.play(); if live.count > 12 { live.removeFirst() } }
    }
}
