import Foundation
import AppKit
import SQLite3
import Contacts

/// Messages bridge (iMessage via the Messages app of this Mac).
/// Sending goes through AppleScript (needs the one-time Automation permission), receiving reads ~/Library/Messages/chat.db
/// read-only (needs Full Disk Access). Only messages from contacts you explicitly connected are used; nothing else is read or stored.
enum Bridge {
    static var dbPath: String { NSHomeDirectory() + "/Library/Messages/chat.db" }

    enum Access: Equatable { case ok, noFullDiskAccess, missing }

    // MARK: access / reading
    private static func open() -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { sqlite3_close(db); return nil }
        sqlite3_busy_timeout(db, 500)
        return db
    }
    static func checkAccess() -> Access {
        guard FileManager.default.fileExists(atPath: dbPath) || FileManager.default.isReadableFile(atPath: dbPath) else {
            // the file exists but may be hidden by privacy protection: distinguish by trying to open it
            return open() == nil ? (FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Messages") ? .noFullDiskAccess : .missing) : .ok
        }
        guard let db = open() else { return .noFullDiskAccess }
        defer { sqlite3_close(db) }
        var st: OpaquePointer?
        defer { sqlite3_finalize(st) }
        return sqlite3_prepare_v2(db, "SELECT 1 FROM message LIMIT 1", -1, &st, nil) == SQLITE_OK ? .ok : .noFullDiskAccess
    }
    /// Highest message id (metadata only, no content).
    static func maxRowID() -> Int64? {
        guard let db = open() else { return nil }
        defer { sqlite3_close(db) }
        var st: OpaquePointer?
        defer { sqlite3_finalize(st) }
        guard sqlite3_prepare_v2(db, "SELECT MAX(ROWID) FROM message", -1, &st, nil) == SQLITE_OK, sqlite3_step(st) == SQLITE_ROW else { return nil }
        return sqlite3_column_int64(st, 0)
    }

    struct Incoming { var rowid: Int64; var handle: String; var text: String; var date: Date }
    /// Incoming (not from me) messages with an id above `after`; reactions are skipped.
    static func incoming(after: Int64) -> [Incoming] {
        guard let db = open() else { return [] }
        defer { sqlite3_close(db) }
        let sql = """
        SELECT m.ROWID, m.text, m.attributedBody, m.date, h.id FROM message m LEFT JOIN handle h ON m.handle_id = h.ROWID
        WHERE m.ROWID > ?1 AND m.is_from_me = 0 AND (m.associated_message_type IS NULL OR m.associated_message_type = 0) ORDER BY m.ROWID LIMIT 200
        """
        var st: OpaquePointer?
        defer { sqlite3_finalize(st) }
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_int64(st, 1, after)
        var out: [Incoming] = []
        while sqlite3_step(st) == SQLITE_ROW {
            let id = sqlite3_column_int64(st, 0)
            let text = messageText(st, 1, 2)
            let date = Date(timeIntervalSinceReferenceDate: Double(sqlite3_column_int64(st, 3)) / 1_000_000_000)
            let handle = sqlite3_column_text(st, 4).map { String(cString: $0) } ?? ""
            out.append(Incoming(rowid: id, handle: handle, text: text, date: date))
        }
        return out
    }

    /// Newer macOS versions keep the text only inside the `attributedBody` typedstream: "NSString" ... 0x2B <length> <utf8>.
    /// Text of a message row: the `text` column, else the typedstream in `attributedBody`; "[Attachment]" when only an object is left.
    private static func messageText(_ st: OpaquePointer?, _ textCol: Int32, _ bodyCol: Int32) -> String {
        var text = sqlite3_column_text(st, textCol).map { String(cString: $0) } ?? ""
        if text.isEmpty, let p = sqlite3_column_blob(st, bodyCol) { text = decodeAttributedBody(Data(bytes: p, count: Int(sqlite3_column_bytes(st, bodyCol)))) ?? "" }
        text = text.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "[Attachment]" : text
    }
    static func decodeAttributedBody(_ d: Data) -> String? {
        let bytes = [UInt8](d), key = Array("NSString".utf8)
        guard bytes.count > key.count + 6 else { return nil }
        var start = -1
        for i in 0...(bytes.count - key.count) where Array(bytes[i..<i + key.count]) == key { start = i + key.count; break }
        guard start >= 0, let plus = bytes[start...].firstIndex(of: 0x2B), plus + 2 < bytes.count else { return nil }
        var p = plus + 1, len = Int(bytes[p]); p += 1
        if len == 0x81 { guard p + 2 <= bytes.count else { return nil }; len = Int(bytes[p]) | Int(bytes[p + 1]) << 8; p += 2 }
        else if len == 0x82 { guard p + 4 <= bytes.count else { return nil }; len = (0..<4).reduce(0) { $0 | Int(bytes[p + $1]) << (8 * $1) }; p += 4 }
        guard len > 0, p + len <= bytes.count else { return nil }
        return String(data: Data(bytes[p..<p + len]), encoding: .utf8)
    }

    /// Of the newest `n` incoming messages of one handle: how many are still unread in the Messages app.
    static func unreadAmongLatest(handle: String, n: Int) -> Int {
        guard let db = open() else { return n }
        defer { sqlite3_close(db) }
        let sql = """
        SELECT m.is_read, h.id FROM message m JOIN handle h ON m.handle_id = h.ROWID
        WHERE m.is_from_me = 0 AND (m.associated_message_type IS NULL OR m.associated_message_type = 0) AND m.cache_roomnames IS NULL ORDER BY m.ROWID DESC LIMIT 600
        """
        var st: OpaquePointer?
        defer { sqlite3_finalize(st) }
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return n }
        var seen = 0, unread = 0
        while sqlite3_step(st) == SQLITE_ROW, seen < n {
            guard let hid = sqlite3_column_text(st, 1).map({ String(cString: $0) }), same(hid, handle) || hid == handle else { continue }
            seen += 1; if sqlite3_column_int(st, 0) == 0 { unread += 1 }
        }
        return unread
    }
    struct Conversation { var handle: String; var last: String; var date: Date; var count: Int }
    /// The most recent one-to-one conversations (newest first), found in the last few thousand messages.
    static func conversations(limit: Int) -> [Conversation] {
        guard let db = open() else { return [] }
        defer { sqlite3_close(db) }
        let sql = """
        SELECT m.text, m.attributedBody, m.date, h.id FROM message m JOIN handle h ON m.handle_id = h.ROWID
        WHERE (m.associated_message_type IS NULL OR m.associated_message_type = 0) AND m.cache_roomnames IS NULL ORDER BY m.ROWID DESC LIMIT 4000
        """
        var st: OpaquePointer?
        defer { sqlite3_finalize(st) }
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return [] }
        var out: [Conversation] = []
        while sqlite3_step(st) == SQLITE_ROW {
            guard let hid = sqlite3_column_text(st, 3).map({ String(cString: $0) }) else { continue }
            if let i = out.firstIndex(where: { same($0.handle, hid) || $0.handle == hid }) { out[i].count += 1; continue }
            guard out.count < limit else { continue }
            let text = messageText(st, 0, 1)
            out.append(Conversation(handle: hid, last: text, date: Date(timeIntervalSinceReferenceDate: Double(sqlite3_column_int64(st, 2)) / 1_000_000_000), count: 1))
        }
        return out
    }
    /// Names from the Contacts app for phone numbers / e-mail addresses (asks for Contacts access once; without it the handle is shown).
    static func names(for handles: [String], done: @escaping ([String: String]) -> Void) {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { ok, err in
            if !ok { NSLog("Contacts access not granted: \(err?.localizedDescription ?? "denied")") }
            guard ok else { done([:]); return }
            var out: [String: String] = [:]
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            // read the address book once and match by digits / lower-case address (robust against any number format)
            try? store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { c, _ in
                var n = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                if n.isEmpty { n = c.nickname.isEmpty ? c.organizationName : c.nickname }
                guard !n.isEmpty else { return }
                let ids = c.phoneNumbers.map { $0.value.stringValue } + c.emailAddresses.map { $0.value as String }
                for h in handles where out[h] == nil && ids.contains(where: { same($0, h) }) { out[h] = n }
            }
            done(out)
        }
    }
    struct Recent { var fromMe: Bool; var text: String; var date: Date }
    /// The last `limit` messages (both directions) exchanged with one handle, oldest first.
    static func recent(handle: String, limit: Int) -> [Recent] {
        guard let db = open() else { return [] }
        defer { sqlite3_close(db) }
        let sql = """
        SELECT m.text, m.attributedBody, m.date, m.is_from_me, h.id FROM message m LEFT JOIN handle h ON m.handle_id = h.ROWID
        WHERE (m.associated_message_type IS NULL OR m.associated_message_type = 0) AND m.cache_roomnames IS NULL ORDER BY m.ROWID DESC LIMIT 800
        """
        var st: OpaquePointer?
        defer { sqlite3_finalize(st) }
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return [] }
        var out: [Recent] = []
        while sqlite3_step(st) == SQLITE_ROW, out.count < limit {
            guard let hid = sqlite3_column_text(st, 4).map({ String(cString: $0) }), same(hid, handle) else { continue }
            let text = messageText(st, 0, 1)
            out.append(Recent(fromMe: sqlite3_column_int(st, 3) != 0, text: text, date: Date(timeIntervalSinceReferenceDate: Double(sqlite3_column_int64(st, 2)) / 1_000_000_000)))
        }
        return out.reversed()
    }

    // MARK: handles
    /// Phone numbers compare by their digits (country code may be missing), e-mail addresses case-insensitively.
    static func same(_ a: String, _ b: String) -> Bool {
        if a.contains("@") || b.contains("@") { return a.lowercased() == b.lowercased() }
        func core(_ s: String) -> String { String(s.filter(\.isNumber).drop { $0 == "0" }) }   // drop 00 / 0 prefixes
        let x = core(a), y = core(b)
        guard x.count >= 7, y.count >= 7 else { return false }
        return x == y || x.hasSuffix(y) || y.hasSuffix(x)
    }

    // MARK: sending
    private static func lit(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
    static func script(text: String, handle: String, participant: Bool) -> String {
        let body = text.components(separatedBy: "\n").map(lit).joined(separator: " & linefeed & ")
        return """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to \(participant ? "participant" : "buddy") \(lit(handle)) of targetService
            send (\(body)) to targetBuddy
        end tell
        """
    }
    /// Sends through Messages.app. `done` gets an error text or nil.
    static func send(_ text: String, to handle: String, done: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            func run(_ participant: Bool) -> String? {
                var err: NSDictionary?
                NSAppleScript(source: script(text: text, handle: handle, participant: participant))?.executeAndReturnError(&err)
                return err.map { ($0[NSAppleScript.errorMessage] as? String) ?? "AppleScript error \($0[NSAppleScript.errorNumber] ?? "")" }
            }
            done(run(true).flatMap { _ in run(false) })   // newer macOS: "participant", older: "buddy"
        }
    }
    /// Harmless request that makes macOS show the Automation prompt (and list the app under Privacy > Automation).
    static func requestAutomation(done: @escaping (String) -> Void) {
        DispatchQueue.global().async {
            var err: NSDictionary?
            NSAppleScript(source: "tell application \"Messages\" to get name")?.executeAndReturnError(&err)
            let n = err?[NSAppleScript.errorNumber] as? Int
            DispatchQueue.main.async { done(err == nil ? "Messages control is allowed." : (n == -1743 ? "Not allowed yet: enable this app under Privacy & Security > Automation > Messages." : "Messages could not be reached (\(err?[NSAppleScript.errorMessage] as? String ?? "error"))." )) }
        }
    }
    static func openPrivacySettings() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(u) }
    }
}
