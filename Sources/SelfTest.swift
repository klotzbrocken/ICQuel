#if DEBUG
import AppKit

/// Debug builds only: `ICQ_SELFTEST=1 <app>/Contents/MacOS/ICQuel` (tools/test.sh) runs these checks against the real code, prints a summary and exits non-zero on any failure.
enum SelfTest {
    static var failures = 0, checks = 0
    static func check(_ ok: Bool, _ what: String, line: Int = #line) {
        checks += 1
        if !ok { failures += 1; print("FAIL (SelfTest.swift:\(line)): \(what)") }
    }
    static func run() {
        bridge(); options(); autoReply(); ai()
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
