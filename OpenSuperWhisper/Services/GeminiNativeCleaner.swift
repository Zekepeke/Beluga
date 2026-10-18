import Foundation

/// Talks to Gemini's native `generateContent` API (not the OpenAI-compatible shim),
/// so system prompts and model listing use Gemini's own fields.
struct GeminiNativeCleaner: TextCleaner, ModelListing {
    let baseURL: String
    let model: String
    let apiKey: String?
    let session: URLSession

    init(baseURL: String, model: String, apiKey: String?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.session = session
    }

    private struct Part: Codable { let text: String }

    private struct Content: Encodable {
        let role: String
        let parts: [Part]
    }

    private struct SystemInstruction: Encodable { let parts: [Part] }

    private struct GenerationConfig: Encodable { let temperature: Double }

    private struct RequestBody: Encodable {
        let systemInstruction: SystemInstruction?
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct GenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct ResponseContent: Decodable {
                struct ResponsePart: Decodable {
                    let text: String?
                    let thought: Bool?
                }
                let parts: [ResponsePart]?
            }
            let content: ResponseContent?
        }
        let candidates: [Candidate]?
    }

    private struct ModelsResponse: Decodable {
        struct Entry: Decodable {
            let name: String
            let supportedGenerationMethods: [String]?
        }
        let models: [Entry]
        let nextPageToken: String?
    }

    private static let maxModelPages = 10

    func clean(messages: [CleanupMessage]) async throws -> String {
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        var request = URLRequest(url: try CleanupHTTP.url(base: baseURL, path: "/models/\(encodedModel):generateContent"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(to: &request)

        let system = messages.filter { $0.role == "system" }.map(\.content).joined(separator: "\n\n")
        let contents = messages
            .filter { $0.role != "system" }
            .map { Content(role: $0.role == "assistant" ? "model" : "user", parts: [Part(text: $0.content)]) }

        request.httpBody = try JSONEncoder().encode(RequestBody(
            systemInstruction: system.isEmpty ? nil : SystemInstruction(parts: [Part(text: system)]),
            contents: contents,
            generationConfig: GenerationConfig(temperature: 0)
        ))

        let data = try await CleanupHTTP.perform(request, session: session)
        let decoded = try CleanupHTTP.decode(GenerateResponse.self, from: data)

        // Blocked or truncated generations come back as 200 without candidate text.
        let text = (decoded.candidates?.first?.content?.parts ?? [])
            .filter { $0.thought != true }
            .compactMap(\.text)
            .joined()
        guard !text.isEmpty else { throw CleanupError.invalidResponse }
        return text
    }

    func listModels() async throws -> [String] {
        var ids: [String] = []
        var pageToken: String?

        for _ in 0..<Self.maxModelPages {
            var components = URLComponents(url: try CleanupHTTP.url(base: baseURL, path: "/models"), resolvingAgainstBaseURL: false)
            var query = [URLQueryItem(name: "pageSize", value: "1000")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components?.queryItems = query
            guard let url = components?.url else { throw CleanupError.network("Invalid base URL") }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            applyAuthorization(to: &request)

            let data = try await CleanupHTTP.perform(request, session: session)
            let page = try CleanupHTTP.decode(ModelsResponse.self, from: data)
            ids += page.models
                .filter { $0.supportedGenerationMethods?.contains("generateContent") ?? false }
                .map { CleanupHTTP.stripModelsPrefix($0.name) }

            guard let next = page.nextPageToken, !next.isEmpty else { break }
            pageToken = next
        }
        return ids.sorted()
    }

    private func applyAuthorization(to request: inout URLRequest) {
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        }
    }
}
