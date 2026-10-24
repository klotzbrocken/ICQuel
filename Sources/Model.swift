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
    var notes: String? = nil       // private notes about the contact (never sent anywhere)
    var autoReply: Bool? = nil     // may get an automatic away reply (needs Auto-reply on in Preferences > Bridge)
    var isLive: Bool { bridge != nil }
    /// An iMessage group chat (bridge = "group:<chat guid>").
    var isGroup: Bool { bridge?.hasPrefix("group:") == true || (isWA && (waJid ?? "").hasSuffix("@g.us")) }
    /// A WhatsApp chat (bridge = "wa:<jid>") reached through the experimental WhatsApp helper.
    var isWA: Bool { bridge?.hasPrefix("wa:") == true }
    var waJid: String? { isWA ? String(bridge!.dropFirst(3)) : nil }
    /// An iMessage contact or group (everything live that is not WhatsApp).
    var isIM: Bool { bridge != nil && !isWA }
    /// A made-up sample friend (neither an AI chatbot nor an iMessage contact): can be hidden in Preferences.
    var isDemo: Bool { persona == nil && bridge == nil }
    /// Address for "Send Mail": the e-mail field, or the iMessage handle when that is an e-mail address.
    var mailAddr: String? { if let e = email, !e.isEmpty { return e }; if let b = bridge, !isGroup, !isWA, b.contains("@") { return b }; return nil }
    /// Number / address for FaceTime: the phone field, or the iMessage handle.
    var callTarget: String? { if isGroup { return nil }; if let p = phone, !p.isEmpty { return p }; if let j = waJid { return j.hasSuffix("@s.whatsapp.net") ? WAProtocol.number(j) : nil }; return bridge }
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
struct Msg: Codable { var dir: String; var text: String; var t: Date; var files: [String]? = nil }
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

struct Saved: Codable {
    var uin = "", nick = "", status = Status.online, sounds = true
    var contacts: [Contact] = [], freqEnabled = true, freqMode = FreqMode.hour, minutes = 15, demoFirst = true
    var aiEnabled = false, history: [String: [Msg]] = [:]
    var apiModel: String? = nil
    var aiProvider: String? = nil, aiModels: [String: String]? = nil
    var simpleMode: Bool? = nil
    var botInit: Bool? = nil, botMin: Int? = nil, botMax: Int? = nil
    var opts: MainOpts? = nil
    var appName: String? = nil
    var bridgeEnabled: Bool? = nil, bridgeLast: Int64? = nil
    var autoAway: Bool? = nil, autoAwayMin: Int? = nil, autoAwayDND: Bool? = nil
    var hideDemo: Bool? = nil, aiDraftIMessage: Bool? = nil, bridgeAutoAdd: Bool? = nil
    var showGroups: Bool? = nil, showReceipts: Bool? = nil
    var awayTexts: [String: String]? = nil
    var waEnabled: Bool? = nil, waAutoAdd: Bool? = nil
    var aiLocal: Bool? = nil, aiSummary: Bool? = nil, autoReplyOn: Bool? = nil, autoReplyText: String? = nil, autoReplyAI: Bool? = nil, autoReplied: [String: Double]? = nil
}

/// Contacts, bots, history and settings live in ~/Library/Application Support/ICQ99b/store.json (one backup copy is kept),
/// not in UserDefaults: resetting preferences or rebuilding the app must never lose the user's chatbots.
/// Test runs (ICQ_SNAPSHOT) use a throw-away folder and never touch real data.
enum Persist {
    #if DEBUG
    static var testMode: Bool { ProcessInfo.processInfo.environment["ICQ_SNAPSHOT"] != nil || ProcessInfo.processInfo.environment["ICQ_SELFTEST"] != nil }
    #else
    static var testMode: Bool { false }
    #endif
    static var dir: URL {
        let fm = FileManager.default
        if testMode { return fm.temporaryDirectory.appendingPathComponent("icq-test-\(ProcessInfo.processInfo.processIdentifier)") }
        if let d = ProcessInfo.processInfo.environment["ICQUEL_DATA_DIR"], !d.isEmpty { return URL(fileURLWithPath: d, isDirectory: true) }   // e.g. tools/demo.sh: run on made-up data
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
    private static func base(_ account: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "ICQ99b", kSecAttrAccount as String: account] }
    static func set(_ v: String, account: String = "ai-api-key") {
        SecItemDelete(base(account) as CFDictionary)
        guard !v.isEmpty else { return }
        var a = base(account); a[kSecValueData as String] = Data(v.utf8); SecItemAdd(a as CFDictionary, nil)
    }
    static func get(account: String = "ai-api-key") -> String {
        var q = base(account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var r: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return "" }
        return String(decoding: d, as: UTF8.self)
    }
}

final class Store: ObservableObject {
    static let shared = Store()
    @Published var uin = ""
    @Published var nick = ""
    @Published var status = Status.online {
        didSet {
            guard status != oldValue else { return }
            statusSince = Date()
            let quietSet: Set<Status> = [.away, .na, .occupied, .dnd]
            if quietSet.contains(oldValue) && !quietSet.contains(status) && aiSummary && aiEnabled { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.summarizeUnread() } }
        }
    }
    var statusSince = Date()
    var regen = Set<String>()
    @Published var attachments: [String: [URL]] = [:]   // files / pictures waiting in the send window
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
    @Published var hideDemo = false          // hide the made-up sample contacts
    @Published var awayTexts: [String: String] = [:]   // my message per status (edited in the status message window)
    static let defaultAway = ["away": "I'm away from my computer right now.", "na": "I'm not available. Please leave a message.", "occupied": "I'm busy right now – urgent messages only.",
                              "dnd": "Please do not disturb.", "ffc": "I'm free for a chat!"]
    func awayText(_ st: Status) -> String { awayTexts[st.rawValue] ?? Store.defaultAway[st.rawValue] ?? "" }
    @Published var waAutoAdd = false         // unknown WhatsApp 1:1 senders become contacts (off: they are dropped)
    @Published var waEnabled = false         // experimental WhatsApp helper (Preferences > Privacy)
    @Published var showGroups = false        // group chats can be imported and are shown (off by default)
    @Published var showReceipts = true       // "delivered / read" under my last message
    @Published var receipts: [String: String] = [:]
    @Published var bridgeAutoAdd = false     // new 1:1 iMessages from people that are not imported yet create a contact (off by default: privacy)
    @Published var aiDraftIMessage = false   // AI writes a reply DRAFT for incoming iMessages (never sent by the app)
    @Published var aiDrafts: [String: String] = [:]
    @Published var aiLocal = false           // Apple's on-device model for drafts, translation, summaries and auto-replies
    @Published var aiSummary = false         // "what did I miss" summary when I am back
    @Published var autoReplyOn = false       // automatic away reply to allowed contacts (iMessage)
    @Published var autoReplyText = "Sorry, I can't answer right now. I'll get back to you later. (automatic reply)"
    @Published var autoReplyAI = false       // the AI writes the away reply
    var autoReplied: [String: Double] = [:]  // contact -> time of the last automatic reply
    @Published var drafting = Set<String>()   // contacts for whom the AI is writing a draft right now
    private var lastDraftError = Date.distantPast
    @Published var botMin = 5
    @Published var botMax = 20
    @Published var history: [String: [Msg]] = [:]
    @Published var online = Set<String>()
    @Published var unread: [String: [Msg]] = [:]
    @Published var flash = false
    @Published var selected: String?
    /// The AI key lives in the Keychain. It is loaded in the background: the system may ask for permission (the app is re-signed on every build),
    /// and that prompt must never block the UI or app start.
    var apiKey = "" { didSet { if !loadingKey { Keychain.set(apiKey, account: aiProvider.account) } } }
    @Published var aiProvider = AIProvider.anthropic
    var aiModels: [String: String] = [:]          // last chosen model per provider
    @Published var modelList: [String: [String]] = [:]   // live model lists per provider (Preferences drop-down)
    @Published var keyStatus = ""
    /// Loads the model list of the active provider with the current key; also tells whether the key works.
    func refreshModels() {
        let p = aiProvider, k = apiKey
        guard !k.isEmpty else { keyStatus = ""; return }
        keyStatus = "Checking key…"
        Task {
            do { let l = try await AIChat.fetchModels(provider: p, key: k); await MainActor.run { if p == self.aiProvider { self.modelList[p.rawValue] = l; self.keyStatus = "Key works · \(l.count) models available" } } }
            catch { await MainActor.run { if p == self.aiProvider { self.keyStatus = error.localizedDescription } } }
        }
    }
    /// Entries of the model drop-down: the live list (else the built-in one), always including the current choice.
    func modelChoices() -> [String] {
        var l = modelList[aiProvider.rawValue] ?? aiProvider.fallbackModels
        if !apiModel.isEmpty, !l.contains(apiModel) { l.insert(apiModel, at: 0) }
        return l
    }
    /// Switches the AI service: each provider keeps its own key (Keychain) and model.
    func switchProvider(_ p: AIProvider) {
        guard p != aiProvider else { return }
        aiModels[aiProvider.rawValue] = apiModel
        aiProvider = p; AIChat.provider = p
        apiModel = aiModels[p.rawValue] ?? p.defaultModel
        loadingKey = true; apiKey = ""; loadingKey = false; keyLoaded = false; loadStarted = false
        loadKeyAsync(); save()
    }
    @Published var keyLoaded = false
    private var loadingKey = false

    private var plan: [Date] = [], windowEnd = Date(), nextAt = Date(), lastMsg = -1
    private var sched: Timer?, first: Timer?

    init() {
        if let d = Persist.load(), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            uin = s.uin; nick = s.nick; status = s.status; sounds = s.sounds; contacts = s.contacts
            freqEnabled = s.freqEnabled; freqMode = s.freqMode; minutes = s.minutes; demoFirst = s.demoFirst
            aiEnabled = s.aiEnabled; history = s.history; apiModel = s.apiModel ?? "claude-haiku-5-5"; aiProvider = AIProvider(rawValue: s.aiProvider ?? "") ?? .anthropic; aiModels = s.aiModels ?? [:]; AIChat.provider = aiProvider; simpleMode = s.simpleMode ?? false
            botInit = s.botInit ?? true; botMin = s.botMin ?? 5; botMax = s.botMax ?? 20; opts = s.opts ?? MainOpts(); appName = s.appName ?? "ICQuel"; bridgeEnabled = s.bridgeEnabled ?? false; bridgeLast = s.bridgeLast ?? 0
            autoAway = s.autoAway ?? false; autoAwayMin = s.autoAwayMin ?? 15; autoAwayDND = s.autoAwayDND ?? false
            hideDemo = s.hideDemo ?? false; aiDraftIMessage = s.aiDraftIMessage ?? false; bridgeAutoAdd = s.bridgeAutoAdd ?? false; showGroups = s.showGroups ?? false; awayTexts = s.awayTexts ?? [:]; waEnabled = s.waEnabled ?? false; waAutoAdd = s.waAutoAdd ?? false; showReceipts = s.showReceipts ?? true
            aiLocal = s.aiLocal ?? false; aiSummary = s.aiSummary ?? false; autoReplyOn = s.autoReplyOn ?? false; autoReplyAI = s.autoReplyAI ?? false
            if let t = s.autoReplyText, !t.isEmpty { autoReplyText = t }; autoReplied = s.autoReplied ?? [:]
            AIChat.useLocal = aiLocal
        }
        online = Set(contacts.filter { $0.isBot || $0.isLive }.map(\.uin))   // AI chatbots and bridged contacts are always shown online
    }
    private var loadStarted = false
    /// Loads the key only when it is needed (AI reply or the AI prefs page), never at app start.
    func loadKeyAsync(_ done: (() -> Void)? = nil) {
        guard !keyLoaded else { done?(); return }
        guard !Persist.testMode else { keyLoaded = true; done?(); return }
        guard !loadStarted else { return }
        loadStarted = true; let acct = aiProvider.account
        DispatchQueue.global(qos: .utility).async {
            let k = Keychain.get(account: acct)
            DispatchQueue.main.async { self.loadingKey = true; self.apiKey = k; self.loadingKey = false; self.keyLoaded = true; done?() }
        }
    }
    func save() {
        let s = Saved(uin: uin, nick: nick, status: status, sounds: sounds, contacts: contacts, freqEnabled: freqEnabled,
                      freqMode: freqMode, minutes: minutes, demoFirst: demoFirst, aiEnabled: aiEnabled, history: history, apiModel: apiModel, aiProvider: aiProvider.rawValue, aiModels: aiModels, simpleMode: simpleMode, botInit: botInit, botMin: botMin, botMax: botMax, opts: opts, appName: appName, bridgeEnabled: bridgeEnabled, bridgeLast: bridgeLast, autoAway: autoAway, autoAwayMin: autoAwayMin, autoAwayDND: autoAwayDND, hideDemo: hideDemo, aiDraftIMessage: aiDraftIMessage, bridgeAutoAdd: bridgeAutoAdd, showGroups: showGroups, showReceipts: showReceipts, awayTexts: awayTexts, waEnabled: waEnabled, waAutoAdd: waAutoAdd, aiLocal: aiLocal, aiSummary: aiSummary, autoReplyOn: autoReplyOn, autoReplyText: autoReplyText, autoReplyAI: autoReplyAI, autoReplied: autoReplied)
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
    func log(_ uin: String, _ dir: String, _ text: String, _ t: Date = Date(), files: [String]? = nil) {
        history[uin, default: []].append(Msg(dir: dir, text: text, t: t, files: files))
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
    func deliver(to chosen: Contact? = nil, text: String? = nil, files: [String]? = nil) {
        if chosen == nil && quiet { return }                                  // scheduled sample message while Away / DND
        guard status != .offline, let c = chosen ?? contacts.filter({ online.contains($0.uin) && !$0.isLive && !(hideDemo && $0.isDemo) }).randomElement() else { return }
        var t = text ?? ""
        if text == nil { var i: Int; repeat { i = Int.random(in: 0..<dummyMessages.count) } while i == lastMsg; lastMsg = i; t = dummyMessages[i] }
        let m = Msg(dir: "in", text: t, t: Date(), files: files)
        unread[c.uin, default: []].append(m)
        log(c.uin, "in", m.text, m.t, files: files)
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
    /// Sends the waiting attachments of a contact: real iMessage contacts through Messages, everyone else just gets a log line.
    func sendAttachments(_ uin: String) {
        guard let files = attachments.removeValue(forKey: uin), !files.isEmpty else { return }
        if let c = contact(uin), let j = c.waJid {
            guard waEnabled, status != .offline else { return }
            for f in files { WABridge.shared.sendFile(f, to: j) { err in DispatchQueue.main.async { if let err { notice("WhatsApp could not send \(f.lastPathComponent):\n\(err)") } else { self.log(uin, "out", "", files: [f.path]) } } } }
        } else if let c = contact(uin), let h = c.bridge {
            guard bridgeEnabled, status != .offline else { return }
            for f in files { Bridge.sendFile(f, to: h) { err in DispatchQueue.main.async { if let err { notice("Messages could not send \(f.lastPathComponent):\n\(err)") } else { self.log(uin, "out", "", files: [f.path]) } } } }
        } else { for f in files { log(uin, "out", "", files: [f.path]) } }
    }
    func botReply(_ uin: String) {
        if let c = contact(uin), let j = c.waJid {         // a WhatsApp chat: hand the message to the helper, never auto-answer
            guard waEnabled else { notice("WhatsApp is off.\nTurn it on in Preferences > Privacy."); return }
            guard status != .offline else { notice("You are offline."); return }
            guard let last = history[uin]?.last, last.dir == "out" else { return }
            aiDrafts[uin] = nil
            WABridge.shared.send(last.text, to: j) { err in if let err { DispatchQueue.main.async { notice("WhatsApp could not send this message:\n\(err)") } } }
            return
        }
        if let c = contact(uin), let h = c.bridge {       // a real iMessage contact: hand the message to Messages, never auto-answer
            guard bridgeEnabled else { notice("The Messages bridge is off.\nTurn it on in Preferences > Bridge."); return }
            guard status != .offline else { notice("You are offline."); return }
            guard let last = history[uin]?.last, last.dir == "out" else { return }
            aiDrafts[uin] = nil
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
    /// "✓ Delivered" / "✓✓ Read 14:05" under my newest message.
    static func receiptText(_ state: Int, _ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "d MMM HH:mm"
        return state == 2 ? "✓✓ Read " + f.string(from: date) : (state == 1 ? "✓ Delivered" : "Sent")
    }
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
            // Messages marks a message read within seconds when its window is open: only messages that have been shown here for 2 minutes are synced
            guard let h = c.bridge, c.isIM, !c.isGroup, let q = unread[c.uin], !q.isEmpty, q.allSatisfy({ Date().timeIntervalSince($0.t) > 120 }) else { return nil }; return (c.uin, h, q.count)
        }
        // 1:1 chats whose newest message is mine: look up delivered / read
        let wantReceipts = showReceipts ? contacts.compactMap { c -> (String, String)? in
            guard let h = c.bridge, c.isIM, !c.isGroup, history[c.uin]?.last?.dir == "out" else { return nil }; return (c.uin, h) } : []
        DispatchQueue.global(qos: .utility).async {
            let msgs = Bridge.incoming(after: after)
            let states = pending.map { ($0.0, Bridge.unreadAmongLatest(handle: $0.1, n: $0.2)) }
            let rc: [(String, (state: Int, date: Date)?)] = wantReceipts.map { ($0.0, Bridge.receipt(handle: $0.1)) }
            DispatchQueue.main.async {
                self.polling = false
                for (u, r) in rc { if let r { self.receipts[u] = Store.receiptText(r.state, r.date) } else { self.receipts[u] = nil } }
                // read in the Messages app (on this Mac or another device) = read here as well
                var changed = false
                for (u, k) in states { if let cur = self.unread[u]?.count, k < cur { self.unread[u] = k == 0 ? nil : Array(self.unread[u]!.suffix(k)); changed = true } }
                if changed { ICQ.refreshTray() }
                guard let top = msgs.last?.rowid else { return }
                self.bridgeLast = top; self.save()
                var touched: [Contact] = []
                for m in msgs {
                    if m.group {   // group messages only go to the matching group chat, never into someone's 1:1 chat
                        guard self.showGroups, let g = m.chatGuid, let gc = self.contacts.first(where: { $0.bridge == "group:" + g }) else { continue }
                        self.deliver(to: gc, text: self.groupText(m.handle, m.text, mine: false), files: m.files.isEmpty ? nil : m.files)
                        continue
                    }
                    var contact = self.contacts.first(where: { $0.isIM && !$0.isGroup && ($0.bridge.map { Bridge.same($0, m.handle) } ?? false) })
                    if contact == nil, self.bridgeAutoAdd, m.imessage, !m.group, !m.handle.isEmpty {   // a new sender: create the contact (named from your Contacts if possible)
                        contact = self.addBridgeContact(m.handle, handle: m.handle, importRecent: false)
                        if let c = contact { self.nameFromContacts(c) }
                    }
                    if let c = contact { self.deliver(to: c, text: m.text, files: m.files.isEmpty ? nil : m.files); if !touched.contains(c) { touched.append(c) }; self.maybeAutoReply(c, m) }
                }
                touched.forEach { self.prepareDraft(for: $0) }
            }
        }
    }
    /// AI reply draft for an iMessage contact (only if switched on in Preferences > AI Chat): stored as text for the reply window, never sent.
    func prepareDraft(for c: Contact, force: Bool = false) {
        if force && !aiEnabled { notice("Turn on AI Chat in Preferences first."); return }
        guard aiEnabled, !c.isGroup, force || (aiDraftIMessage && c.isLive), !drafting.contains(c.uin) else { return }
        withEngine(retry: { self.prepareDraft(for: c, force: force) }) {
        if force { regen.insert(c.uin) }   // the send window replaces its text with this draft
        drafting.insert(c.uin)
        let hist = history[c.uin] ?? [], key = apiKey, model = apiModel, me = nick
        Task {
            do {
                let text = try await AIChat.draft(contact: c.name, user: me, history: hist, key: key, model: model)
                DispatchQueue.main.async { self.drafting.remove(c.uin); self.aiDrafts[c.uin] = text }
            } catch {
                DispatchQueue.main.async {
                    self.drafting.remove(c.uin)
                    if Date().timeIntervalSince(self.lastDraftError) > 60 { self.lastDraftError = Date(); notice("The AI reply draft for \(c.name) failed:\n\(error.localizedDescription)") }
                }
            }
        }
        }
    }

    // MARK: helper features on top of the engine (on-device model or API)
    /// Runs `run` when text can be generated: with the on-device model, or with the API key (loaded first when needed).
    func withEngine(retry: @escaping () -> Void, run: () -> Void) {
        if aiLocal && LocalAI.available { run(); return }
        if !keyLoaded { loadKeyAsync { retry() }; return }
        guard !apiKey.isEmpty else { return }
        run()
    }
    /// Automatic away reply: only to contacts that were allowed ("Allow auto-reply"), once per 6 hours, only 1:1 iMessage, only for messages that arrived after the status was set.
    func maybeAutoReply(_ c: Contact, _ m: Bridge.Incoming) {
        let now = Date().timeIntervalSince1970
        guard let h = c.bridge, AutoReplyRule.allows(enabled: autoReplyOn, quiet: quiet, contactAllowed: c.autoReply == true, imessage: m.imessage, group: m.group,
                                                   msgDate: m.date, statusSince: statusSince, lastReply: autoReplied[c.uin], now: now) else { return }
        autoReplied[c.uin] = now; save()
        // my own message for this status (edited in the status window) is what people get; otherwise the text from Preferences > Privacy
        var fallback = awayTexts[status.rawValue] ?? autoReplyText
        if !fallback.lowercased().contains("automatic reply") { fallback += " (automatic reply)" }
        let statusText = status.menuLabel, me = nick
        func send(_ t: String) {
            Bridge.send(t, to: h) { err in DispatchQueue.main.async {
                if let err { notice("The automatic reply to \(c.name) could not be sent:\n\(err)") } else { self.log(c.uin, "out", "↩︎ " + t) }
            } }
        }
        if autoReplyAI && aiEnabled {
            withEngine(retry: { self.maybeAutoReply(c, m) }) { [key = apiKey, model = apiModel] in
                Task {
                    let t = (try? await AIChat.awayReply(contact: c.name, user: me, incoming: m.text, status: statusText, key: key, model: model)) ?? fallback
                    DispatchQueue.main.async { send(t) }
                }
            }
        } else { send(fallback) }
    }
    /// "What did I miss": one line per unread iMessage chat.
    func summarizeUnread(manual: Bool = false) {
        let chats = contacts.compactMap { c -> String? in
            guard c.isLive, let q = unread[c.uin], !q.isEmpty else { return nil }
            return "Chat with \(c.name):\n" + q.suffix(8).map { "- " + $0.text }.joined(separator: "\n")
        }
        guard !chats.isEmpty else { if manual { notice("There are no unread iMessages.") }; return }
        guard aiEnabled else { if manual { notice("Turn on AI Chat in Preferences first.") }; return }
        withEngine(retry: { self.summarizeUnread(manual: manual) }) { [key = apiKey, model = apiModel] in
            let text = String(chats.joined(separator: "\n\n").prefix(4000))
            Task {
                do {
                    let s = try await AIChat.summarize(text, key: key, model: model)
                    DispatchQueue.main.async { retroBox("While you were away", s, icon: "info32") }
                } catch { DispatchQueue.main.async { if manual { notice("The summary failed:\n\(error.localizedDescription)") } } }
            }
        }
    }
    /// Contacts that carry their phone number / address as name get the real name from the Contacts app.
    func nameFromContacts(_ c: Contact) {
        guard let h = c.bridge, c.isIM, !c.isGroup else { return }
        Bridge.names(for: [h]) { n in DispatchQueue.main.async {
            if let nm = n[h], let i = self.contacts.firstIndex(where: { $0.uin == c.uin }), self.contacts[i].name == h { self.contacts[i].name = nm; self.save() }
        } }
    }
    @discardableResult func addBridgeContact(_ name: String, handle: String, importRecent: Bool = true) -> Contact? {
        let n = name.trimmingCharacters(in: .whitespaces), h = handle.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !h.isEmpty else { return nil }
        let c = Contact(name: n, uin: Store.newUin(), bridge: h)
        contacts.append(c); online.insert(c.uin); save()
        if importRecent { DispatchQueue.global(qos: .utility).async {      // fill the history with the last 5 iMessages (needs Full Disk Access; silently skipped otherwise)
            let recent = Bridge.recent(handle: h, limit: 5)
            guard !recent.isEmpty else { return }
            DispatchQueue.main.async { self.history[c.uin] = recent.map { Msg(dir: $0.fromMe ? "out" : "in", text: $0.text, t: $0.date, files: $0.files.isEmpty ? nil : $0.files) }; self.save() }
        } }
        return c
    }

    /// A message from the WhatsApp helper: only chats you imported are shown; everything else is dropped.
    func waIncoming(_ m: WAMessage) {
        guard waEnabled else { return }
        // a chat may have been saved under its phone-number form or its LID form: either matches
        var found = contacts.first(where: { $0.bridge == "wa:" + m.jid || (!m.alt.isEmpty && $0.bridge == "wa:" + m.alt) })
        if found == nil, waAutoAdd, !m.group, !m.fromMe, m.jid.hasSuffix("@s.whatsapp.net") { found = addWAContact(m.name.isEmpty ? WAProtocol.number(m.jid) : m.name, jid: m.jid) }
        guard let c = found else { WABridge.shared.ignored = (m.name.isEmpty ? WAProtocol.number(m.jid) : m.name) + (m.group ? " (group)" : ""); return }
        if m.fromMe {   // written on another device: only the history gets it (our own sends are logged when they are made)
            if history[c.uin]?.last(where: { $0.dir == "out" }).map({ $0.text == m.text && Date().timeIntervalSince($0.t) < 60 }) == true { return }
            log(c.uin, "out", m.text, m.date, files: m.files.isEmpty ? nil : m.files); return
        }
        let who = m.name.isEmpty ? WAProtocol.number(m.from.contains("@") ? m.from : m.from + "@s.whatsapp.net") : m.name
        let text = m.group ? (m.text.isEmpty ? "" : who + ": " + m.text) : m.text
        deliver(to: c, text: text, files: m.files.isEmpty ? nil : m.files)
    }
    /// An explicit user action (Forward, Request Chat): writes `text` (and files) to a contact like the send window does.
    func sendText(to uin: String, _ text: String, files: [String] = []) {
        if !text.isEmpty { log(uin, "out", text); Sound.play("msgsent"); botReply(uin) }
        if !files.isEmpty { attachments[uin] = files.map { URL(fileURLWithPath: $0) }; sendAttachments(uin) }
    }
    @discardableResult func addWAContact(_ name: String, jid: String) -> Contact? {
        let key = "wa:" + jid
        guard !contacts.contains(where: { $0.bridge == key }) else { return nil }
        let c = Contact(name: name, uin: Store.newUin(), bridge: key)
        contacts.append(c); online.insert(c.uin); save(); return c
    }
    /// A group chat as a contact (bridge = "group:<guid>"); the last 5 messages are loaded, incoming ones prefixed with the sender.
    @discardableResult func addGroupContact(_ name: String, guid: String) -> Contact? {
        let key = "group:" + guid
        guard !contacts.contains(where: { $0.bridge == key }) else { return nil }
        let c = Contact(name: name, uin: Store.newUin(), bridge: key)
        contacts.append(c); online.insert(c.uin); save()
        DispatchQueue.global(qos: .utility).async {
            let recent = Bridge.recentGroup(guid: guid, limit: 5)
            guard !recent.isEmpty else { return }
            DispatchQueue.main.async {
                self.history[c.uin] = recent.map { Msg(dir: $0.fromMe ? "out" : "in", text: self.groupText($0.from, $0.text, mine: $0.fromMe), t: $0.date, files: $0.files.isEmpty ? nil : $0.files) }; self.save()
            }
        }
        return c
    }
    /// "Sender: text" for group messages (sender named from the contact list, else the handle).
    func groupText(_ handle: String, _ text: String, mine: Bool) -> String {
        if mine || handle.isEmpty { return text }
        let who = contacts.first(where: { $0.isIM && !$0.isGroup && ($0.bridge.map { Bridge.same($0, handle) } ?? false) })?.name ?? handle
        return text.isEmpty ? "" : who + ": " + text
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
        if hold[name] != nil, !Attach.typeSound { return }
        if let h = hold[name], let t = last[name], Date().timeIntervalSince(t) < h { return }
        last[name] = Date()
        if let f = Assets.resource("sounds", name + ".wav"), let snd = NSSound(contentsOfFile: f, byReference: false) { live.append(snd); snd.play(); if live.count > 12 { live.removeFirst() } }
    }
}

/// Guards of the automatic away reply (pure, covered by SelfTest): opt-in, quiet status, allowed contact, 1:1 iMessage only, only messages after the status was set, once per 6 hours.
enum AutoReplyRule {
    static func allows(enabled: Bool, quiet: Bool, contactAllowed: Bool, imessage: Bool, group: Bool, msgDate: Date, statusSince: Date, lastReply: Double?, now: Double) -> Bool {
        guard enabled, quiet, contactAllowed, imessage, !group, msgDate > statusSince else { return false }
        if let l = lastReply, now - l < 6 * 3600 { return false }
        return true
    }
}
