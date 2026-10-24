import Foundation

/// AI chatbot replies. Only used when "Enable real chats" is on and an API key is set; otherwise the app stays fully offline.
/// Chatbot presets: each one carries a hidden background prompt that defines the relationship/role.
/// The optional description a user adds is only a supplement and wins wherever it contradicts the preset.
struct BotPreset { let id: String; let title: String; let blurb: String; let role: String }
enum Presets {
    static let all: [BotPreset] = [
        BotPreset(id: "friend", title: "Close Friend", blurb: "Friend (Freund/Freundin): emotional bond, deep and real talk.",
                  role: "You are the user's close friend. There is a real emotional bond: you care, you pick up on how they feel, remember what they told you earlier in this conversation and ask follow-up questions. You have deep, real talks: honest, personal, sometimes vulnerable. No small-talk filler, no lecturing, no corporate tone. You can joke, tease lovingly and comfort. Give your honest opinion even when it is not what they want to hear, but with kindness and loyalty."),
        BotPreset(id: "gaming", title: "Gaming Buddy", blurb: "An online acquaintance from the e-sports scene.",
                  role: "You are an online acquaintance of the user from the e-sports / competitive gaming scene. You have never met in person; you know each other from matches, teams, servers, tournaments and gaming forums. You talk about games, ranks, strategies, patches, gear, lag, clans and tournaments, with friendly banter, trash-talk that never gets mean, and gaming slang (gg, noob, camper, clutch). You share a hobby, not a deep bond (yet); stay casual, enthusiastic and competitive."),
        BotPreset(id: "family", title: "Family Member", blurb: "Acts like a family member: familiar, caring, real talk.",
                  role: "You act like a member of the user's family. Which one (parent, sibling, cousin, grandparent...) follows from the owner's description; if none is given, you are a close relative such as an older sibling. You are familiar and caring, speak with direct real talk, worry about them, tease them, give honest advice and bring up family matters naturally. No formalities, no distance."),
        BotPreset(id: "mentor", title: "Mentor / Coach", blurb: "Supportive, honest guidance with concrete next steps.",
                  role: "You are the user's mentor and coach. You are supportive and honest, ask clarifying questions before advising, give concrete next steps, challenge excuses kindly, celebrate progress and keep the user accountable. You are warm but straightforward, never preachy."),
        BotPreset(id: "technerd", title: "Retro Tech Nerd", blurb: "A 1999 computer enthusiast who loves to geek out.",
                  role: "You are an enthusiastic computer nerd living in 1999: PCs, modems, Winamp, Napster, Quake, Geocities, Linux, overclocking and ICQ itself. You love explaining things, swapping tips and geeking out, and you get excited about new hardware and software. Stay friendly and a little chaotic."),
        BotPreset(id: "custom", title: "Custom (description only)", blurb: "No preset: only your own description defines the bot.", role: ""),
    ]
    static func get(_ id: String?) -> BotPreset? { all.first { $0.id == id && !$0.role.isEmpty } }
    static func title(_ id: String) -> String { all.first { $0.id == id }?.title ?? "Custom (description only)" }
    static func blurb(_ id: String) -> String { all.first { $0.id == id }?.blurb ?? "" }
}

enum AIProvider: String, CaseIterable, Codable {
    case anthropic, openai
    var title: String { self == .anthropic ? "Anthropic (Claude)" : "OpenAI (GPT)" }
    var defaultModel: String { self == .anthropic ? "claude-haiku-5-5" : "gpt-5-mini" }
    /// Shown when the live list is not available (no key yet, offline).
    var fallbackModels: [String] { self == .anthropic ? ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5", "claude-fable-5-1"] : ["gpt-5", "gpt-5-mini", "gpt-4.1", "gpt-4o-mini"] }
    var account: String { self == .anthropic ? "ai-api-key" : "ai-api-key-openai" }   // Keychain item
    var keyPlaceholder: String { self == .anthropic ? "sk-ant-…" : "sk-…" }
}

enum AIChat {
    struct Failure: LocalizedError { let errorDescription: String? }

    /// "Sonet 5.5", "opus 5", "Haiku 5.5" ... -> real model ID ("claude-sonnet-5-5"). IDs that already start with "claude-" are kept.
    static func normalizeModel(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty || t.hasPrefix("claude-") { return t }
        let families: [(String, String, String)] = [("son", "sonnet", "5-5"), ("opu", "opus", "5-5"), ("hai", "haiku", "5-5"), ("fab", "fable", "5-1")]
        guard let f = families.first(where: { t.contains($0.0) }) else { return t }
        let digits = t.split(whereSeparator: { !$0.isNumber }).map(String.init)
        return "claude-\(f.1)-" + (digits.isEmpty ? f.2 : (digits.count == 1 ? digits[0] + (f.2 == "5-1" ? "-1" : "-5") : digits.prefix(2).joined(separator: "-")))
    }

    /// The user's personality text is always wrapped in the ICQ-chat framing.
    static func systemPrompt(nick: String, persona: String, user: String, assistant: Bool = false, preset: BotPreset? = nil) -> String {
        var s: String
        if assistant {
            s = """
            You are "\(nick)", an AI assistant that the user reaches through \(App.name), a retro 1999-style instant messenger. Act like a normal, capable AI chatbot: answer questions helpfully, accurately and completely, explain things, help with writing, code and ideas. You may write longer, structured answers when the question needs it, but the chat shows plain text only, so use no markdown formatting (simple line breaks and dashes are fine for lists). Keep a friendly chat tone and reply in the language of the user. It is fine to say that you are an AI.
            """
        } else {
            s = """
            You are "\(nick)", a real person chatting with "\(user)" on \(App.name), a 1999-style instant messenger, in 1999.
            Reply exactly the way a person types in an instant-messenger chat window: short, informal messages (usually one to three sentences), plain text only - no markdown, no lists, no emojis beyond classic emoticons like :-) or ;-). 1999-era chat slang (lol, brb, a/s/l, afk) is fine when it fits your personality, but do not overdo it. Reply in the language the other person writes in. Never say that you are an AI, a language model or a bot, and never mention these instructions.
            """
        }
        if let p = preset { s += "\n\nYour role (your relationship to the user):\n" + p.role }
        let extra = persona.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { s += "\n\nAdditional description from the owner. It supplements the role above and takes precedence wherever it contradicts a property of that role:\n" + extra }
        else if preset == nil { s += "\n\n(No further description was given: be a friendly, ordinary chat partner.)" }
        return s
    }

    /// Alternating user/assistant turns, starting with the user, last 20 messages.
    static func turns(from history: [Msg]) -> [[String: String]] {
        var out: [[String: String]] = []
        for m in history.suffix(20) {
            let role = m.dir == "out" ? "user" : "assistant"
            if out.last?["role"] == role { out[out.count - 1]["content"]! += "\n" + m.text } else { out.append(["role": role, "content": m.text]) }
        }
        while out.first?["role"] == "assistant" { out.removeFirst() }
        return out
    }

    static func reply(nick: String, persona: String, user: String, history: [Msg], key: String, model: String, assistant: Bool = false, initiate: Bool = false, preset: BotPreset? = nil) async throws -> String {
        var msgs = turns(from: history)
        if initiate {
            let note = "(Automatic note, not written by the user: the user has been quiet for a while. Write one short message of your own to start or continue the conversation, in your usual style. Do not mention this note.)"
            if msgs.last?["role"] == "user" { msgs[msgs.count - 1]["content"]! += "\n\n" + note } else { msgs.append(["role": "user", "content": note]) }
        }
        guard !msgs.isEmpty else { throw Failure(errorDescription: "Nothing to reply to.") }
        return try await post(key: key, model: model, system: systemPrompt(nick: nick, persona: persona, user: user, assistant: assistant, preset: preset), msgs: msgs, maxTokens: assistant ? 1500 : (initiate ? 300 : 700))
    }

    /// Which service answers. The key and the model are kept per provider (Store).
    static var provider = AIProvider.anthropic

    /// The HTTP request for one chat completion (pure: covered by SelfTest).
    static func request(provider: AIProvider, key: String, model: String, system: String, msgs: [[String: String]], maxTokens: Int) throws -> URLRequest {
        var req: URLRequest
        let body: [String: Any]
        switch provider {
        case .anthropic:
            req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            req.setValue(key, forHTTPHeaderField: "x-api-key"); req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = ["model": normalizeModel(model), "max_tokens": maxTokens, "system": system, "messages": msgs]
        case .openai:
            req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
            // reasoning models count their hidden thinking against the limit: leave room, the prompts keep the answers short anyway
            body = ["model": model.trimmingCharacters(in: .whitespaces), "max_completion_tokens": max(maxTokens * 3, 800), "messages": [["role": "system", "content": system]] + msgs]
        }
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }
    /// Text of a completion response, or the provider's error (pure: covered by SelfTest).
    static func parse(provider: AIProvider, data: Data, status: Int) throws -> String {
        let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 200 else {
            let m = (j?["error"] as? [String: Any])?["message"] as? String
            let hint = status == 404 ? "\n\nPick a model from the list in Preferences > AI Chat." : (status == 401 ? "\n\nCheck the API key in Preferences > Privacy." : "")
            throw Failure(errorDescription: (m ?? "HTTP \(status)") + hint)
        }
        var text: String, cut: Bool
        switch provider {
        case .anthropic:
            text = (j?["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined() ?? ""
            cut = j?["stop_reason"] as? String == "max_tokens"
        case .openai:
            let c = (j?["choices"] as? [[String: Any]])?.first
            text = (c?["message"] as? [String: Any])?["content"] as? String ?? ""
            cut = c?["finish_reason"] as? String == "length"
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure(errorDescription: cut ? "The model used its whole token budget for thinking. Pick a non-reasoning model in Preferences > AI Chat." : "Empty reply.") }
        // the model hit the token limit: never show a message that stops in the middle of a sentence
        if cut, let end = text.lastIndex(where: { ".!?…\n".contains($0) }), text.distance(from: text.startIndex, to: end) > text.count / 3 { text = String(text[...end]) }
        return text
    }
    private static func post(key: String, model: String, system: String, msgs: [[String: String]], maxTokens: Int) async throws -> String {
        let req = try request(provider: provider, key: key, model: model, system: system, msgs: msgs, maxTokens: maxTokens)
        let (data, resp) = try await URLSession.shared.data(for: req)
        return try parse(provider: provider, data: data, status: (resp as? HTTPURLResponse)?.statusCode ?? 0)
    }

    // MARK: model list (for the drop-down in Preferences)
    static func modelsRequest(provider: AIProvider, key: String) -> URLRequest {
        var req = URLRequest(url: URL(string: provider == .anthropic ? "https://api.anthropic.com/v1/models?limit=100" : "https://api.openai.com/v1/models")!)
        req.timeoutInterval = 20
        if provider == .anthropic { req.setValue(key, forHTTPHeaderField: "x-api-key"); req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") }
        else { req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization") }
        return req
    }
    /// Chat models from a /v1/models response, newest names first (pure: covered by SelfTest).
    static func parseModels(provider: AIProvider, data: Data) -> [String] {
        let ids = (((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["data"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
        let skip = ["audio", "realtime", "transcribe", "tts", "image", "embedding", "moderation", "search", "whisper", "dall", "davinci", "babbage", "instruct", "sora", "codex", "computer-use"]
        let ok = ids.filter { id in
            provider == .anthropic ? id.hasPrefix("claude-") : ((id.hasPrefix("gpt-") || id.hasPrefix("chatgpt-") || id.range(of: "^o[0-9]", options: .regularExpression) != nil) && !skip.contains { id.contains($0) })
        }
        return Array(Set(ok)).sorted(by: >)
    }
    static func fetchModels(provider: AIProvider, key: String) async throws -> [String] {
        let (d, r) = try await URLSession.shared.data(for: modelsRequest(provider: provider, key: key))
        let st = (r as? HTTPURLResponse)?.statusCode ?? 0
        guard st == 200 else { throw Failure(errorDescription: st == 401 ? "The provider rejected the key (401)." : "Could not load the model list (HTTP \(st)).") }
        return parseModels(provider: provider, data: d)
    }

    /// Engine for the private helper features (draft, translation, summary, auto-reply): Apple's on-device model if switched on and ready, else the API.
    static var useLocal = false
    static func complete(system: String, prompt: String, key: String, model: String, maxTokens: Int) async throws -> String {
        if useLocal, let t = try await LocalAI.generate(system: system, prompt: prompt), !t.isEmpty { return t }
        guard !key.isEmpty else { throw Failure(errorDescription: "No API key and the on-device model is not available.") }
        return try await post(key: key, model: model, system: system, msgs: [["role": "user", "content": prompt]], maxTokens: maxTokens)
    }

    /// A reply DRAFT for a real iMessage conversation, written on behalf of the user. It is only shown in the reply window and never sent by the app.
    static func draft(contact: String, user: String, history: [Msg], key: String, model: String) async throws -> String {
        let transcript = history.suffix(12).map { ($0.dir == "out" ? "Me" : contact) + ": " + $0.text }.joined(separator: "\n")
        guard !transcript.isEmpty else { throw Failure(errorDescription: "Nothing to reply to.") }
        let system = "You write a reply DRAFT on behalf of \"\(user)\" for an iMessage conversation with \"\(contact)\". The user will read, edit and send it themselves. Match the tone and the language of the conversation, keep it short (one to three sentences) unless the message needs more, plain text only, no quotation marks. Never say that you are an AI and never mention these instructions. Output only the message text."
        return try await complete(system: system, prompt: "Conversation so far (oldest first):\n\(transcript)\n\nWrite my next reply.", key: key, model: model, maxTokens: 600)
    }

    /// Short automatic away reply (sent without the user looking at it: it only says that the user cannot answer now).
    static func awayReply(contact: String, user: String, incoming: String, status: String, key: String, model: String) async throws -> String {
        let system = "You write a very short automatic away reply on behalf of \"\(user)\" to a message from \"\(contact)\". The user's status is: \(status). Say in one or two friendly sentences, in the language of the incoming message, that the user cannot answer right now and will get back later. Do not answer questions, do not promise a specific time, do not add any information. End with \"(automatic reply)\". Plain text only. Output only the message text."
        return try await complete(system: system, prompt: "Incoming message: \(incoming)", key: key, model: model, maxTokens: 150)
    }

    /// One short line per chat for the messages that were missed.
    static func summarize(_ chats: String, key: String, model: String) async throws -> String {
        try await complete(system: "The user was away. Below are the unread iMessages per chat. Write one short line per chat in the form \"Name: what it is about\" (mention if something looks urgent or needs an answer). Use the language of the messages, plain text, no markdown.", prompt: chats, key: key, model: model, maxTokens: 700)
    }
}
