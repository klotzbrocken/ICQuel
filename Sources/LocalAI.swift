import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device language model (Apple Intelligence, macOS 26+): private and without an API key. Optional engine for drafts,
/// translation, summaries and auto-replies; chatbots keep using the Anthropic API.
enum LocalAI {
    static var status: String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "available"
            case .unavailable(let r): return "\(r)"
            }
        }
        #endif
        return "needs macOS 26 or newer"
    }
    static var available: Bool { status == "available" }
    /// nil = the on-device model cannot be used (the caller falls back to the API).
    static func generate(system: String, prompt: String) async throws -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            return try await LanguageModelSession(instructions: system).respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        return nil
    }
}
