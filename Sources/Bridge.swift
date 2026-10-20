import Foundation
import AppKit
import SQLite3

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
            var text = sqlite3_column_text(st, 1).map { String(cString: $0) } ?? ""
            if text.isEmpty, let p = sqlite3_column_blob(st, 2) { text = decodeAttributedBody(Data(bytes: p, count: Int(sqlite3_column_bytes(st, 2)))) ?? "" }
            text = text.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { text = "[Attachment]" }
            let date = Date(timeIntervalSinceReferenceDate: Double(sqlite3_column_int64(st, 3)) / 1_000_000_000)
            let handle = sqlite3_column_text(st, 4).map { String(cString: $0) } ?? ""
            out.append(Incoming(rowid: id, handle: handle, text: text, date: date))
        }
        return out
    }

    /// Newer macOS versions keep the text only inside the `attributedBody` typedstream: "NSString" ... 0x2B <length> <utf8>.
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
