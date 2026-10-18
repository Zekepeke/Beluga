import Foundation

/// Talks to any server that speaks the OpenAI `/chat/completions` format
/// (Ollama, LM Studio, Groq, custom endpoints).
struct OpenAICompatibleCleaner: TextCleaner, ModelListing {
    let baseURL: String
    let model: String
    let apiKey: String?
    let reasoningEffort: String?
    let session: URLSession

    init(baseURL: String, model: String, apiKey: String?, reasoningEffort: String?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.reasoningEffort = reasoningEffort
        self.session = session
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [CleanupMessage]
        let temperature: Double
        let stream: Bool
        let reasoning_effort: String?
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct ModelsResponse: Decodable {
        struct Entry: Decodable { let id: String }
        let data: [Entry]
    }

    func clean(messages: [CleanupMessage]) async throws -> String {
        var request = URLRequest(url: try CleanupHTTP.url(base: baseURL, path: "/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(to: &request)

        let effort = reasoningEffort?.trimmingCharacters(in: .whitespaces)
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: model,
            messages: messages,
            temperature: 0,
            stream: false,
            reasoning_effort: (effort?.isEmpty ?? true) ? nil : effort
        ))

        let data = try await CleanupHTTP.perform(request, session: session)
        let decoded = try CleanupHTTP.decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else { throw CleanupError.invalidResponse }
        return content
    }

    func listModels() async throws -> [String] {
        var request = URLRequest(url: try CleanupHTTP.url(base: baseURL, path: "/models"))
        request.httpMethod = "GET"
        applyAuthorization(to: &request)

        let data = try await CleanupHTTP.perform(request, session: session)
        let decoded = try CleanupHTTP.decode(ModelsResponse.self, from: data)
        return decoded.data.map { CleanupHTTP.stripModelsPrefix($0.id) }.sorted()
    }

    private func applyAuthorization(to request: inout URLRequest) {
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }
}
