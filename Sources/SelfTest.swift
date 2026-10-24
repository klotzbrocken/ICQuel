#if DEBUG
import AppKit
import SQLite3

/// Debug builds only: `ICQ_SELFTEST=1 <app>/Contents/MacOS/ICQuel` (tools/test.sh) runs these checks against the real code, prints a summary and exits non-zero on any failure.
enum SelfTest {
    static var failures = 0, checks = 0
    static func check(_ ok: Bool, _ what: String, line: Int = #line) {
        checks += 1
        if !ok { failures += 1; print("FAIL (SelfTest.swift:\(line)): \(what)") }
    }
    static func run() {
        bridge(); options(); autoReply(); ai(); giphy(); chatDB(); features()
        print("selftest: \(checks) checks, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }

    static func bridge() {
        check(Bridge.same("+49 151 1234567", "0151 1234567"), "phone numbers match across prefixes")
        check(Bridge.same("A@B.de", "a@b.de"), "e-mail match is case-insensitive")
        check(!Bridge.same("+49 151 1234567", "+49 151 7654321"), "different numbers differ")
        check(!Bridge.same("123", "123"), "too short numbers never match")
        // typedstream: "NSString" + 0x01 0x94 0x84 0x01 0x2B <len> <utf8>
        var d = Data("streamtyped".utf8) + Data("NSString".utf8) + Data([0x01, 0x94, 0x84, 0x01, 0x2B, 5]) + Data("Hallo".utf8)
        check(Bridge.decodeAttributedBody(d) == "Hallo", "attributedBody short string")
        let long = String(repeating: "x", count: 300)
        d = Data("NSString".utf8) + Data([0x01, 0x94, 0x84, 0x01, 0x2B, 0x81, 0x2C, 0x01]) + Data(long.utf8)
        check(Bridge.decodeAttributedBody(d) == long, "attributedBody long string (2-byte length)")
        check(Bridge.decodeAttributedBody(Data([1, 2, 3])) == nil, "garbage is rejected")
    }

    static func options() {
        var o = MainOpts(); o.showIMessage = false; o.mOffline = false
        let back = try? JSONDecoder().decode(MainOpts.self, from: JSONEncoder().encode(o))
        check(back == o, "MainOpts survives a JSON round trip")
        let old = try? JSONDecoder().decode(MainOpts.self, from: Data("{\"tabs\":false}".utf8))
        check(old?.tabs == false && old?.showOffline == true, "older stores keep new defaults")
    }

    static func ai() {
        let msgs = [["role": "user", "content": "hi"]]
        let a = try! AIChat.request(provider: .anthropic, key: "K", model: "sonnet 5.5", system: "SYS", msgs: msgs, maxTokens: 100)
        let ab = try! JSONSerialization.jsonObject(with: a.httpBody!) as! [String: Any]
        check(a.url?.host == "api.anthropic.com" && a.value(forHTTPHeaderField: "x-api-key") == "K", "anthropic request target and key header")
        check(ab["model"] as? String == "claude-sonnet-5-5" && ab["system"] as? String == "SYS" && ab["max_tokens"] as? Int == 100, "anthropic body")
        let o = try! AIChat.request(provider: .openai, key: "K", model: " gpt-5-mini ", system: "SYS", msgs: msgs, maxTokens: 100)
        let ob = try! JSONSerialization.jsonObject(with: o.httpBody!) as! [String: Any]
        check(o.url?.host == "api.openai.com" && o.value(forHTTPHeaderField: "Authorization") == "Bearer K", "openai request target and bearer header")
        check(ob["model"] as? String == "gpt-5-mini" && (ob["messages"] as? [[String: String]])?.first?["role"] == "system" && (ob["max_completion_tokens"] as? Int ?? 0) >= 800, "openai body: system message first, room for reasoning")
        func d(_ j: String) -> Data { Data(j.utf8) }
        check((try? AIChat.parse(provider: .anthropic, data: d(#"{"content":[{"type":"text","text":"Hello"}],"stop_reason":"end_turn"}"#), status: 200)) == "Hello", "anthropic reply parsed")
        check((try? AIChat.parse(provider: .openai, data: d(#"{"choices":[{"message":{"content":" Hi there "},"finish_reason":"stop"}]}"#), status: 200)) == "Hi there", "openai reply parsed")
        check((try? AIChat.parse(provider: .openai, data: d(#"{"choices":[{"message":{"content":"One. Two. Thr"},"finish_reason":"length"}]}"#), status: 200)) == "One. Two.", "cut-off reply trimmed to the last sentence")
        check((try? AIChat.parse(provider: .openai, data: d(#"{"choices":[{"message":{"content":""},"finish_reason":"length"}]}"#), status: 200)) == nil, "empty reasoning reply is an error")
        do { _ = try AIChat.parse(provider: .openai, data: d(#"{"error":{"message":"Incorrect API key"}}"#), status: 401); check(false, "401 must throw") }
        catch { check(error.localizedDescription.contains("Incorrect API key") && error.localizedDescription.contains("Privacy"), "401 shows provider message and hint") }
        let om = AIChat.parseModels(provider: .openai, data: d(#"{"data":[{"id":"gpt-5"},{"id":"gpt-5-mini"},{"id":"text-embedding-3-small"},{"id":"whisper-1"},{"id":"o3"},{"id":"gpt-4o-audio-preview"},{"id":"dall-e-3"}]}"#))
        check(om == ["o3", "gpt-5-mini", "gpt-5"], "openai model list keeps chat models only, sorted: \(om)")
        let am = AIChat.parseModels(provider: .anthropic, data: d(#"{"data":[{"id":"claude-sonnet-5-5"},{"id":"claude-haiku-5-5"}]}"#))
        check(am == ["claude-sonnet-5-5", "claude-haiku-5-5"], "anthropic model list")
        check(AIProvider.allCases.map(\.account).count == Set(AIProvider.allCases.map(\.account)).count, "each provider has its own Keychain item")
    }

    static func giphy() {
        let ok = Data(#"{"data":[{"id":"abc","images":{"fixed_width_small":{"url":"https://m.giphy.com/t.gif"},"downsized":{"url":"https://m.giphy.com/d.gif"}}},{"id":"bad","images":{}}],"meta":{"status":200}}"#.utf8)
        let hits = try? Attach.parseHits(ok)
        check(hits?.count == 1 && hits?.first?.id == "abc" && hits?.first?.full.lastPathComponent == "d.gif", "giphy hits parsed, incomplete entries skipped")
        do { _ = try Attach.parseHits(Data(#"{"data":[],"meta":{"status":429,"msg":"Too Many Requests"}}"#.utf8)); check(false, "429 must throw") }
        catch { check(error.localizedDescription.contains("Too Many Requests"), "giphy API error text is passed on") }
    }

    /// A small fixture with the tables of Messages' chat.db: attachments, group chats, receipts.
    static func chatDB() {
        let path = NSTemporaryDirectory() + "selftest-chat.db"; try? FileManager.default.removeItem(atPath: path)
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { check(false, "fixture db opens"); return }
        let sql = """
        CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
        CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, display_name TEXT, chat_identifier TEXT, style INTEGER);
        CREATE TABLE message (ROWID INTEGER PRIMARY KEY, text TEXT, attributedBody BLOB, date INTEGER, handle_id INTEGER, service TEXT, cache_roomnames TEXT, is_from_me INTEGER,
            associated_message_type INTEGER, is_read INTEGER, is_delivered INTEGER, date_delivered INTEGER, date_read INTEGER);
        CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
        CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER);
        CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, filename TEXT);
        CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);
        INSERT INTO handle VALUES (1, '+491511234567'), (2, '+491517654321');
        INSERT INTO chat VALUES (1, 'iMessage;-;+491511234567', NULL, '+491511234567', 45), (2, 'iMessage;+;chat999', 'Team', 'chat999', 43), (3, 'iMessage;+;chat888', NULL, 'chat888', 43);
        INSERT INTO chat_handle_join VALUES (3, 1), (3, 2);
        INSERT INTO message VALUES (1, 'hi', NULL, 1000000000, 1, 'iMessage', NULL, 0, 0, 0, 0, 0, 0);
        INSERT INTO message VALUES (2, NULL, NULL, 2000000000, 1, 'iMessage', NULL, 0, 0, 0, 0, 0, 0);
        INSERT INTO message VALUES (3, 'yo', NULL, 3000000000, 2, 'iMessage', 'chat999', 0, 0, 0, 0, 0, 0);
        INSERT INTO message VALUES (4, 'on my way', NULL, 4000000000, 1, 'iMessage', NULL, 1, 0, 1, 1, 4100000000, 4200000000);
        INSERT INTO message VALUES (5, 'later', NULL, 5000000000, 1, 'iMessage', NULL, 1, 0, 1, 1, 5100000000, 0);
        INSERT INTO message VALUES (6, 'anyone?', NULL, 6000000000, 1, 'iMessage', 'chat888', 0, 0, 0, 0, 0, 0);
        INSERT INTO chat_message_join VALUES (1, 1), (1, 2), (2, 3), (1, 4), (1, 5), (3, 6);
        INSERT INTO attachment VALUES (1, '~/Pictures/selftest.png');
        INSERT INTO message_attachment_join VALUES (2, 1);
        """
        check(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "fixture db created")
        sqlite3_close(db)
        Bridge.dbOverride = path; defer { Bridge.dbOverride = nil; try? FileManager.default.removeItem(atPath: path) }

        check(Bridge.checkAccess() == .ok, "fixture db is readable")
        let inc = Bridge.incoming(after: 0)
        check(inc.map(\.rowid) == [1, 2, 3, 6], "incoming skips my own messages: \(inc.map(\.rowid))")
        check(inc.first(where: { $0.rowid == 2 })?.text == "" && inc.first(where: { $0.rowid == 2 })?.files == [NSHomeDirectory() + "/Pictures/selftest.png"], "attachment-only message: no placeholder text, path expanded")
        let g = inc.first(where: { $0.rowid == 3 })
        check(g?.group == true && g?.chatGuid == "iMessage;+;chat999", "group message carries its chat guid")
        check(inc.first(where: { $0.rowid == 1 })?.group == false && inc.first(where: { $0.rowid == 1 })?.chatGuid == "iMessage;-;+491511234567", "1:1 message is not a group")

        let rec = Bridge.recent(handle: "+49 151 1234567", limit: 10)
        check(rec.map(\.text) == ["hi", "", "on my way", "later"], "recent 1:1 history excludes groups: \(rec.map(\.text))")
        check(rec[1].files.count == 1 && rec[2].fromMe, "recent keeps attachments and direction")

        let groups = Bridge.groups(limit: 5)
        check(groups.map(\.name) == ["+491511234567, +491517654321", "Team"], "groups newest first, unnamed group named after participants: \(groups.map(\.name))")
        let rg = Bridge.recentGroup(guid: "iMessage;+;chat999", limit: 5)
        check(rg.count == 1 && rg[0].text == "yo" && rg[0].from == "+491517654321" && !rg[0].fromMe, "group history with sender")

        let r = Bridge.receipt(handle: "+491511234567")
        check(r?.state == 1, "newest message delivered but not read -> state 1: \(String(describing: r))")
        check(Store.receiptText(2, Date(timeIntervalSinceReferenceDate: 4)).hasPrefix("✓✓ Read") && Store.receiptText(1, Date()) == "✓ Delivered", "receipt wording")

        check(Bridge.script(text: "a\"b", handle: "group:iMessage;+;chat999", participant: true).contains("chat id \"iMessage;+;chat999\""), "group messages are sent to the chat id")
        check(!Bridge.script(text: "x", handle: "+4915", participant: true).contains("chat id"), "1:1 messages are sent to the buddy")
    }

    static func features() {
        let a = Contact(name: "Anna", uin: "1", notes: "met at the LAN party"), b = Contact(name: "Team", uin: "2", bridge: "group:iMessage;+;chat1"), c = Contact(name: "Ben", uin: "3", bridge: "+491511234567")
        let now = Date()
        let h: [String: [Msg]] = ["1": [Msg(dir: "in", text: "Pizza tonight?", t: now.addingTimeInterval(-60)), Msg(dir: "out", text: "yes, pizza!", t: now)],
                                  "3": [Msg(dir: "in", text: "see you", t: now.addingTimeInterval(-3600))]]
        check(Finder.search("a", contacts: [a, b, c], history: h).isEmpty, "one character does not search")
        let hits = Finder.search("PIZZA", contacts: [a, b, c], history: h)
        check(hits.map(\.uin) == ["1", "1"] && hits[0].detail.hasPrefix("Me:"), "message search is case-insensitive, newest first: \(hits.map(\.detail))")
        check(Finder.search("lan party", contacts: [a, b, c], history: h).first?.title == "Anna", "contact notes are searchable")
        check(Finder.search("491511", contacts: [a, b, c], history: h).first?.uin == "3", "search by phone number")
        check(Finder.search("chat1", contacts: [a, b, c], history: h).isEmpty, "group chat ids are not searchable")
        check(Finder.active(contacts: [a, b, c], history: h).map { $0.0.uin } == ["1", "3"], "active list: newest chat first, chats without messages left out")
        check(b.isGroup && b.callTarget == nil && b.mailAddr == nil && !c.isGroup && c.callTarget == "+491511234567", "groups have no FaceTime/mail target")
        check((try? JSONDecoder().decode(Contact.self, from: JSONEncoder().encode(a)))?.notes == "met at the LAN party", "contact notes survive saving")
        check(ICQ.randoms.count >= 6 && Set(ICQ.randoms.map(\.0)).count == ICQ.randoms.count && ICQ.randoms.allSatisfy { Presets.get($0.1) != nil }, "random chat personas are unique and use real presets")
        let st = Store.shared
        check(st.awayText(.away) == Store.defaultAway["away"], "default away message")
        st.awayTexts["away"] = "Back at 5"; check(st.awayText(.away) == "Back at 5", "own away message wins"); st.awayTexts["away"] = nil
        st.sounds = true; st.showGroups = false
        check(st.groupText("+4915", "hi", mine: true) == "hi" && st.groupText("+4915", "hi", mine: false) == "+4915: hi" && st.groupText("+4915", "", mine: false) == "", "group text gets a sender prefix")
    }

    static func autoReply() {
        let now = 1_000_000.0, since = Date(timeIntervalSince1970: now - 600), after = Date(timeIntervalSince1970: now - 60)
        func ok(enabled: Bool = true, quiet: Bool = true, allowed: Bool = true, im: Bool = true, group: Bool = false, date: Date? = nil, last: Double? = nil) -> Bool {
            AutoReplyRule.allows(enabled: enabled, quiet: quiet, contactAllowed: allowed, imessage: im, group: group, msgDate: date ?? after, statusSince: since, lastReply: last, now: now)
        }
        check(ok(), "all guards satisfied sends")
        check(!ok(enabled: false), "off by default")
        check(!ok(quiet: false), "only while Away/N/A/Occupied/DND")
        check(!ok(allowed: false), "only contacts marked Allow auto-reply")
        check(!ok(im: false), "no SMS")
        check(!ok(group: true), "no group chats")
        check(!ok(date: since.addingTimeInterval(-5)), "no messages from before the status was set")
        check(!ok(last: now - 3600), "once per 6 hours")
        check(ok(last: now - 7 * 3600), "again after 6 hours")
    }
}
#endif
