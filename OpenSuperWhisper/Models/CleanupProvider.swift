import Foundation

enum CleanupProvider: String, Codable, CaseIterable, Identifiable {
    case ollama
    case lmStudio
    case groq
    case gemini
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        case .groq: return "Groq"
        case .gemini: return "Gemini"
        case .custom: return "Custom"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama: return "http://localhost:11434/v1"
        case .lmStudio: return "http://localhost:1234/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .custom: return ""
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .groq, .gemini: return true
        case .ollama, .lmStudio, .custom: return false
        }
    }

    var isLocal: Bool {
        switch self {
        case .ollama, .lmStudio: return true
        case .groq, .gemini, .custom: return false
        }
    }

    var supportsReasoningEffort: Bool {
        self != .gemini
    }

    /// Empty means the field is omitted from the request.
    var defaultReasoningEffort: String {
        self == .groq ? "low" : ""
    }
}
