import SwiftUI

/// "Find" / "ICQ White Pages": one search over contacts and all stored messages.
struct FindHit: Identifiable {
    let id = UUID(); let uin: String; let title: String; let detail: String; let date: Date?
}
enum Finder {
    /// Contacts first (name, number, address, notes), then messages (newest first, at most 60). At least 2 characters.
    static func search(_ query: String, contacts: [Contact], history: [String: [Msg]]) -> [FindHit] {
        let t = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard t.count >= 2 else { return [] }
        func has(_ x: String?) -> Bool { x?.lowercased().contains(t) ?? false }
        var out = contacts.filter { has($0.name) || has($0.uin) || has($0.email) || has($0.phone) || has($0.notes) || (!$0.isGroup && has($0.bridge)) }
            .map { FindHit(uin: $0.uin, title: $0.name, detail: "Contact" + ($0.bridge.map { $0.hasPrefix("group:") ? " · group" : " · " + $0 } ?? " · " + $0.uin), date: nil) }
        var msgs: [FindHit] = []
        for c in contacts { for m in (history[c.uin] ?? []) where m.text.lowercased().contains(t) {
            msgs.append(FindHit(uin: c.uin, title: c.name, detail: (m.dir == "out" ? "Me: " : "") + m.text.replacingOccurrences(of: "\n", with: " "), date: m.t))
        } }
        out += msgs.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }.prefix(60)
        return out
    }
    /// Chats with messages, newest activity first.
    static func active(contacts: [Contact], history: [String: [Msg]]) -> [(Contact, Msg)] {
        contacts.compactMap { c in history[c.uin]?.last.map { (c, $0) } }.sorted { $0.1.t > $1.1.t }
    }
}

struct FindView: View {
    @ObservedObject var s = Store.shared
    @State private var q = ""
    static let size = CGSize(width: 440, height: 420)
    var body: some View {
        let hits = Finder.search(q, contacts: s.contacts, history: s.history)
        VStack(alignment: .leading, spacing: 8) {
            Text("Search all contacts and messages:")
            RField(placeholder: "Name, number or text", text: $q)
            Sunken { ScrollView { VStack(alignment: .leading, spacing: 4) {
                if q.trimmingCharacters(in: .whitespaces).count < 2 { Text("Type at least two characters.").foregroundColor(.hint) }
                else if hits.isEmpty { Text("Nothing found.").foregroundColor(.hint) }
                ForEach(hits) { h in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(h.title + (h.date.map { "  (" + stamp($0) + ")" } ?? "")).font(rf(bold: true))
                        Text(h.detail).font(rf(10)).foregroundColor(.hint).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2).contentShape(Rectangle()).onTapGesture { ICQ.openSend(h.uin) }
                }
            }.frame(maxWidth: .infinity, alignment: .topLeading).padding(6) } }
            HStack { Text("Click a result to open the chat.").foregroundColor(.hint); Spacer(); RButton(title: "Close", isDefault: true) { WinMgr.shared.close("find") } }
        }.padding(12).frame(width: FindView.size.width, height: FindView.size.height, alignment: .topLeading)
    }
}

struct ActiveListView: View {
    @ObservedObject var s = Store.shared
    static let size = CGSize(width: 380, height: 380)
    var body: some View {
        let rows = Finder.active(contacts: s.contacts, history: s.history)
        VStack(alignment: .leading, spacing: 8) {
            Text("Your chats, most recent first:")
            Sunken { ScrollView { VStack(alignment: .leading, spacing: 4) {
                if rows.isEmpty { Text("No chats yet.").foregroundColor(.hint) }
                ForEach(rows, id: \.0.uin) { c, m in
                    let unread = !(s.unread[c.uin] ?? []).isEmpty
                    VStack(alignment: .leading, spacing: 0) {
                        Text(c.name + "  (" + stamp(m.t) + ")" + (unread ? "  ✉" : "")).font(rf(bold: true))
                        Text((m.dir == "out" ? "Me: " : "") + (m.text.isEmpty && !(m.files ?? []).isEmpty ? "📎 attachment" : m.text)).font(rf(10)).foregroundColor(.hint).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2).contentShape(Rectangle())
                        .onTapGesture { if unread { ICQ.openIncoming(c.uin) } else { ICQ.openSend(c.uin) } }
                }
            }.frame(maxWidth: .infinity, alignment: .topLeading).padding(6) } }
            HStack { Spacer(); RButton(title: "Close", isDefault: true) { WinMgr.shared.close("active") } }
        }.padding(12).frame(width: ActiveListView.size.width, height: ActiveListView.size.height, alignment: .topLeading)
    }
}
