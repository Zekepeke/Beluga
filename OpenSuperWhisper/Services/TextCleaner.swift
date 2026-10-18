import Foundation

struct CleanupMessage: Codable, Equatable {
    var role: String
    var content: String
}

protocol TextCleaner: Sendable {
    func clean(messages: [CleanupMessage]) async throws -> String
}

/// Backends that can list the models they serve (used by Settings, not by dictation).
protocol ModelListing: Sendable {
    func listModels() async throws -> [String]
}

enum CleanupError: Error, Equatable {
    case rateLimited(retryAfter: TimeInterval?)
    case http(status: Int)
    case invalidResponse
    case network(String)
    case timeout
}
