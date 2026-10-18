import Foundation

/// Request plumbing shared by the cleanup backends.
enum CleanupHTTP {

    /// `base` + `path`, tolerating trailing slashes on the base.
    static func url(base: String, path: String) throws -> URL {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed + path), url.scheme != nil, url.host != nil else {
            throw CleanupError.network("Invalid base URL")
        }
        return url
    }

    /// Decides the outcome by HTTP status first: error bodies differ between
    /// providers (Gemini returns JSON arrays), so they are never decoded.
    static func perform(_ request: URLRequest, session: URLSession) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code == .timedOut {
            throw CleanupError.timeout
        } catch {
            throw CleanupError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw CleanupError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return data
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0.trimmingCharacters(in: .whitespaces)) }
            throw CleanupError.rateLimited(retryAfter: retryAfter)
        default:
            throw CleanupError.http(status: http.statusCode)
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw CleanupError.invalidResponse
        }
    }

    static func stripModelsPrefix(_ id: String) -> String {
        id.hasPrefix("models/") ? String(id.dropFirst("models/".count)) : id
    }
}
