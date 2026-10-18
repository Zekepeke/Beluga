import XCTest
@testable import OpenSuperWhisper

final class GeminiNativeCleanerTests: XCTestCase {

    private let base = "https://generativelanguage.googleapis.com/v1beta"

    private let messages = [
        CleanupMessage(role: "system", content: "sys"),
        CleanupMessage(role: "user", content: "<transcript>\nfew shot\n</transcript>"),
        CleanupMessage(role: "assistant", content: "Few shot."),
        CleanupMessage(role: "user", content: "<transcript>\nhi\n</transcript>"),
    ]

    private let okBody = #"{"candidates":[{"content":{"role":"model","parts":[{"text":"Hi."}]},"finishReason":"STOP"}]}"#

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func makeCleaner(
        baseURL: String? = nil,
        apiKey: String? = "key"
    ) -> GeminiNativeCleaner {
        GeminiNativeCleaner(
            baseURL: baseURL ?? base,
            model: "gemini-3.5-flash-lite",
            apiKey: apiKey,
            session: StubURLProtocol.makeSession()
        )
    }

    private func cleanError(_ cleaner: GeminiNativeCleaner) async -> CleanupError? {
        do {
            _ = try await cleaner.clean(messages: messages)
            return nil
        } catch {
            return error as? CleanupError
        }
    }

    func testClean_postsToGenerateContentWithKeyHeader() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner().clean(messages: messages)

        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "\(base)/models/gemini-3.5-flash-lite:generateContent")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "key")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testClean_keepsAPIKeyOutOfTheURL() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner(apiKey: "secret-key-123").clean(messages: messages)

        let url = try XCTUnwrap(StubURLProtocol.lastRequest?.url)
        XCTAssertFalse(url.absoluteString.contains("secret-key-123"))
        XCTAssertNil(url.query)
    }

    func testClean_omitsKeyHeaderWithoutKey() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner(apiKey: "").clean(messages: messages)
        XCTAssertNil(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "x-goog-api-key"))

        _ = try await makeCleaner(apiKey: nil).clean(messages: messages)
        XCTAssertNil(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "x-goog-api-key"))
    }

    func testClean_mapsMessagesToSystemInstructionAndContents() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner().clean(messages: messages)

        let body = try XCTUnwrap(StubURLProtocol.lastJSONBody)
        let system = try XCTUnwrap(body["systemInstruction"] as? [String: Any])
        let systemParts = try XCTUnwrap(system["parts"] as? [[String: String]])
        XCTAssertEqual(systemParts, [["text": "sys"]])

        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.map { $0["role"] as? String }, ["user", "model", "user"])
        let texts = contents.map { ($0["parts"] as? [[String: String]])?.first?["text"] }
        XCTAssertEqual(texts, ["<transcript>\nfew shot\n</transcript>", "Few shot.", "<transcript>\nhi\n</transcript>"])
    }

    func testClean_joinsMultipleSystemMessagesWithBlankLine() async throws {
        StubURLProtocol.respond(body: okBody)
        let withTwoSystems = [
            CleanupMessage(role: "system", content: "first"),
            CleanupMessage(role: "system", content: "second"),
            CleanupMessage(role: "user", content: "hi"),
        ]

        _ = try await makeCleaner().clean(messages: withTwoSystems)

        let body = try XCTUnwrap(StubURLProtocol.lastJSONBody)
        let system = try XCTUnwrap(body["systemInstruction"] as? [String: Any])
        let parts = try XCTUnwrap(system["parts"] as? [[String: String]])
        XCTAssertEqual(parts, [["text": "first\n\nsecond"]])
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.count, 1)
    }

    func testClean_sendsTemperatureZero() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner().clean(messages: messages)

        let config = try XCTUnwrap(StubURLProtocol.lastJSONBody?["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["temperature"] as? Double, 0)
    }

    func testClean_sendsNoReasoningSetting() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner().clean(messages: messages)

        let config = try XCTUnwrap(StubURLProtocol.lastJSONBody?["generationConfig"] as? [String: Any])
        XCTAssertEqual(Set(config.keys), ["temperature"])
    }

    func testClean_handlesTrailingSlashInBaseURL() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner(baseURL: base + "/").clean(messages: messages)

        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.absoluteString, "\(base)/models/gemini-3.5-flash-lite:generateContent")
    }

    func testClean_returnsCandidateText() async throws {
        StubURLProtocol.respond(body: okBody)

        let result = try await makeCleaner().clean(messages: messages)

        XCTAssertEqual(result, "Hi.")
    }

    func testClean_joinsMultiplePartsAndSkipsThoughtParts() async throws {
        StubURLProtocol.respond(body: #"{"candidates":[{"content":{"parts":[{"text":"hidden","thought":true},{"text":"Hello, "},{"text":"world."}]}}]}"#)

        let result = try await makeCleaner().clean(messages: messages)

        XCTAssertEqual(result, "Hello, world.")
    }

    func testClean_status429_isRateLimitedWithRetryAfter() async {
        StubURLProtocol.respond(status: 429, headers: ["Retry-After": "12"], body: "[]")

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .rateLimited(retryAfter: 12))
    }

    func testClean_status401_withArrayShapedErrorBody_isHTTPError() async {
        StubURLProtocol.respond(status: 401, body: #"[{"error":{"code":401,"status":"UNAUTHENTICATED"}}]"#)

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .http(status: 401))
    }

    func testClean_status500_withArrayShapedErrorBody_isHTTPError() async {
        StubURLProtocol.respond(status: 500, body: #"[{"error":{"code":500,"message":"boom"}}]"#)

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .http(status: 500))
    }

    func testClean_malformed2xxBody_isInvalidResponse() async {
        StubURLProtocol.respond(body: "<html>proxy login</html>")
        let notJSON = await cleanError(makeCleaner())
        XCTAssertEqual(notJSON, .invalidResponse)

        // Blocked prompts come back as 200 with feedback and no candidates.
        StubURLProtocol.respond(body: #"{"promptFeedback":{"blockReason":"SAFETY"}}"#)
        let blocked = await cleanError(makeCleaner())
        XCTAssertEqual(blocked, .invalidResponse)

        StubURLProtocol.respond(body: #"{"candidates":[{"finishReason":"SAFETY"}]}"#)
        let noContent = await cleanError(makeCleaner())
        XCTAssertEqual(noContent, .invalidResponse)
    }

    func testClean_connectionFailure_isNetworkError() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        let error = await cleanError(makeCleaner())

        guard case .network = error else { return XCTFail("expected .network, got \(String(describing: error))") }
    }

    func testListModels_keepsGenerateContentModelsStripsPrefixAndSorts() async throws {
        StubURLProtocol.respond(body: """
        {"models":[
          {"name":"models/gemini-3.5-flash-lite","supportedGenerationMethods":["generateContent","countTokens"]},
          {"name":"models/text-embedding-004","supportedGenerationMethods":["embedContent"]},
          {"name":"models/gemini-3.5-flash","supportedGenerationMethods":["generateContent"]},
          {"name":"models/no-methods-field"}
        ]}
        """)

        let ids = try await makeCleaner().listModels()

        XCTAssertEqual(ids, ["gemini-3.5-flash", "gemini-3.5-flash-lite"])
        let url = try XCTUnwrap(StubURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.path, "/v1beta/models")
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "x-goog-api-key"), "key")
    }

    func testListModels_followsNextPageToken() async throws {
        StubURLProtocol.handler = { request in
            let isSecondPage = request.url?.query?.contains("pageToken=abc") ?? false
            let body = isSecondPage
                ? #"{"models":[{"name":"models/b","supportedGenerationMethods":["generateContent"]}]}"#
                : #"{"models":[{"name":"models/a","supportedGenerationMethods":["generateContent"]}],"nextPageToken":"abc"}"#
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let ids = try await makeCleaner().listModels()

        XCTAssertEqual(ids, ["a", "b"])
        XCTAssertEqual(StubURLProtocol.captured.count, 2)
    }

    func testListModels_malformedBody_isInvalidResponse() async {
        StubURLProtocol.respond(body: #"{"nope":true}"#)

        do {
            _ = try await makeCleaner().listModels()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? CleanupError, .invalidResponse)
        }
    }
}
