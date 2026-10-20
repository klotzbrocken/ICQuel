import SwiftUI
import AppKit

/// First-start assistant: ID + nickname (visual only), optional Messages bridge, optional AI chat + first bot.
struct SetupView: View {
    static let size = CGSize(width: 500, height: 460)
    @State private var step = Int(ProcessInfo.processInfo.environment["ICQ_STEP"] ?? "") ?? 0   // self-test only
    @State private var uin = Store.shared.uin
    @State private var nick = Store.shared.nick
    @State private var bridge = ProcessInfo.processInfo.environment["ICQ_STEP"] != nil
    @State private var bridgeName = ""
    @State private var bridgeHandle = ""
    @State private var bridgeMsg = ""
    @State private var ai = ProcessInfo.processInfo.environment["ICQ_STEP"] != nil
    @State private var key = ""
    @State private var botName = ""
    @State private var preset = "friend"
    @State private var persona = ""
    private let s = Store.shared
    private var steps: Int { 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(["Welcome to \(App.name)", "Messages bridge (optional)", "AI chat (optional)"][step]).font(rf(15, bold: true)).foregroundColor(.ink)
            Text("Step \(step + 1) of \(steps)").font(rf(10)).foregroundColor(.hint)
            ScrollView { VStack(alignment: .leading, spacing: 8) { switch step { case 0: page0; case 1: page1; default: page2 } }.frame(maxWidth: .infinity, alignment: .leading).padding(2) }
            HStack {
                if step > 0 { RButton(title: "< Back") { step -= 1 } }
                Spacer()
                if step < steps - 1 { RButton(title: "Next >", isDefault: true) { step += 1 } } else { RButton(title: "Finish", isDefault: true, action: finish) }
            }
        }.padding(14).foregroundColor(.ink).frame(width: SetupView.size.width, height: SetupView.size.height, alignment: .topLeading)
    }

    // MARK: pages
    @ViewBuilder var page0: some View {
        Text("Choose any ID and nickname. They are only shown inside this app: no account is created and nothing is sent anywhere.").fixedSize(horizontal: false, vertical: true)
        Text("ID number (leave empty for a random one):"); RField(text: $uin)
        Text("Nickname:"); RField(text: $nick)
        Text("You can change both later in Preferences.").foregroundColor(.hint)
    }
    @ViewBuilder var page1: some View {
        Text("Show your real iMessage conversations as contacts, like an old-school messenger. Only the people you add are read; nothing else is read, stored or sent.").fixedSize(horizontal: false, vertical: true)
        RRadio(title: "Yes, enable the bridge", on: bridge) { bridge = true }
        RRadio(title: "No, not now", on: !bridge) { bridge = false }
        if bridge {
            RGroup(title: "Permissions (macOS asks you, this app cannot grant them itself)") {
                Text("1. Receiving: Full Disk Access. Click the button, then drag the app from Finder into the list (or use +), switch it on and restart the app.").fixedSize(horizontal: false, vertical: true)
                HStack { RButton(title: "Full Disk Access…", minWidth: 130) { _ = Bridge.checkAccess(); Bridge.openPrivacySettings() }
                    RButton(title: "Show app in Finder", minWidth: 120) { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) } }
                Text("2. Sending: Automation for Messages. Click the button and allow the macOS prompt.").fixedSize(horizontal: false, vertical: true)
                RButton(title: "Allow Messages control", minWidth: 150) { Bridge.requestAutomation { bridgeMsg = $0 } }
                if !bridgeMsg.isEmpty { Text(bridgeMsg).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true) }
            }
            RGroup(title: "First iMessage contact (optional)") {
                HStack { RField(placeholder: "Name", text: $bridgeName).frame(width: 120); RField(placeholder: "Phone number or e-mail", text: $bridgeHandle) }
            }
            Text("More contacts can be added in Preferences > Bridge.").foregroundColor(.hint)
        }
    }
    @ViewBuilder var page2: some View {
        Text("AI chatbots appear as contacts that are always online and answer like chat friends. They need an Anthropic API key; messages then go to the Anthropic API.").fixedSize(horizontal: false, vertical: true)
        RRadio(title: "Yes, enable AI chat", on: ai) { ai = true }
        RRadio(title: "No, use sample messages only", on: !ai) { ai = false }
        if ai {
            RGroup(title: "API key") { RField(placeholder: "API key", text: $key, secure: true); Text("Stored in your macOS keychain.").foregroundColor(.hint) }
            RGroup(title: "Create your first chatbot") {
                Text("Nickname:"); RField(text: $botName)
                Text("Preset:")
                RButton(title: Presets.title(preset) + "   ▾", minWidth: 200) { popRMenu(Presets.all.map { p in RMItem(title: p.title, checked: p.id == preset, fn: { preset = p.id }) }) }
                Text(Presets.blurb(preset)).foregroundColor(.hint).fixedSize(horizontal: false, vertical: true)
                Text("Additional description (optional):"); RText(text: $persona).frame(height: 60)
            }
        }
    }

    // MARK: finish
    func finish() {
        let digits = uin.filter(\.isNumber); s.uin = digits.isEmpty ? Store.newUin() : digits
        let n = nick.trimmingCharacters(in: .whitespaces); s.nick = n.isEmpty ? App.name + s.uin : n
        s.bridgeEnabled = bridge
        if bridge, !bridgeHandle.trimmingCharacters(in: .whitespaces).isEmpty { _ = s.addBridgeContact(bridgeName, handle: bridgeHandle) }
        if ai {
            let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !k.isEmpty { s.apiKey = k; s.keyLoaded = true; s.aiEnabled = true }
            let b = botName.trimmingCharacters(in: .whitespaces)
            if !b.isEmpty { s.addBot(b, persona: persona, preset: preset) }
        }
        s.save(); WinMgr.shared.close("wizard"); ICQ.connecting()
    }
}
