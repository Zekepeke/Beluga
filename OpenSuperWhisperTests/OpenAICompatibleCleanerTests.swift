import XCTest
@testable import OpenSuperWhisper

final class OpenAICompatibleCleanerTests: XCTestCase {

    private let messages = [
        CleanupMessage(role: "system", content: "sys"),
        CleanupMessage(role: "user", content: "<transcript>\nhi\n</transcript>"),
    ]

    private let okBody = #"{"choices":[{"message":{"role":"assistant","content":"Hi."}}]}"#

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func makeCleaner(
        baseURL: String = "http://localhost:11434/v1",
        apiKey: String? = nil,
        reasoningEffort: String? = nil
    ) -> OpenAICompatibleCleaner {
        OpenAICompatibleCleaner(
            baseURL: baseURL,
            model: "test-model",
            apiKey: apiKey,
            reasoningEffort: reasoningEffort,
            session: StubURLProtocol.makeSession()
        )
    }

    private func cleanError(_ cleaner: OpenAICompatibleCleaner) async -> CleanupError? {
        do {
            _ = try await cleaner.clean(messages: messages)
            return nil
        } catch {
            return error as? CleanupError
        }
    }

    func testClean_postsToChatCompletionsWithJSONBody() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner().clean(messages: messages)

        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(StubURLProtocol.lastJSONBody)
        XCTAssertEqual(body["model"] as? String, "test-model")
        XCTAssertEqual(body["temperature"] as? Double, 0)
        XCTAssertEqual(body["stream"] as? Bool, false)
        let sent = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(sent, [["role": "system", "content": "sys"], ["role": "user", "content": "<transcript>\nhi\n</transcript>"]])
    }

    func testClean_includesReasoningEffortWhenSet() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner(reasoningEffort: "low").clean(messages: messages)

        XCTAssertEqual(StubURLProtocol.lastJSONBody?["reasoning_effort"] as? String, "low")
    }

    func testClean_omitsReasoningEffortWhenEmptyOrNil() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner(reasoningEffort: "").clean(messages: messages)
        XCTAssertNil(StubURLProtocol.lastJSONBody?["reasoning_effort"])

        _ = try await makeCleaner(reasoningEffort: nil).clean(messages: messages)
        XCTAssertNil(StubURLProtocol.lastJSONBody?["reasoning_effort"])
    }

    func testClean_sendsBearerTokenOnlyWithKey() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner(apiKey: "secret").clean(messages: messages)
        XCTAssertEqual(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")

        _ = try await makeCleaner(apiKey: "").clean(messages: messages)
        XCTAssertNil(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"))

        _ = try await makeCleaner(apiKey: nil).clean(messages: messages)
        XCTAssertNil(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testClean_handlesTrailingSlashInBaseURL() async throws {
        StubURLProtocol.respond(body: okBody)

        _ = try await makeCleaner(baseURL: "http://localhost:1234/v1/").clean(messages: messages)

        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.absoluteString, "http://localhost:1234/v1/chat/completions")
    }

    func testClean_returnsFirstChoiceContent() async throws {
        StubURLProtocol.respond(body: #"{"choices":[{"message":{"content":"First."}},{"message":{"content":"Second."}}]}"#)

        let result = try await makeCleaner().clean(messages: messages)

        XCTAssertEqual(result, "First.")
    }

    func testClean_status429_isRateLimitedWithRetryAfter() async {
        StubURLProtocol.respond(status: 429, headers: ["Retry-After": "12"], body: "{}")

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .rateLimited(retryAfter: 12))
    }

    func testClean_status429_withoutRetryAfterHeader() async {
        StubURLProtocol.respond(status: 429, body: "{}")

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .rateLimited(retryAfter: nil))
    }

    func testClean_status500_withArrayShapedErrorBody_isHTTPError() async {
        StubURLProtocol.respond(status: 500, body: #"[{"error":{"code":500,"message":"boom"}}]"#)

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .http(status: 500))
    }

    func testClean_status401_isHTTPError() async {
        StubURLProtocol.respond(status: 401, body: "not json at all")

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .http(status: 401))
    }

    func testClean_malformed2xxBody_isInvalidResponse() async {
        StubURLProtocol.respond(body: "<html>proxy login</html>")
        let notJSON = await cleanError(makeCleaner())
        XCTAssertEqual(notJSON, .invalidResponse)

        StubURLProtocol.respond(body: #"{"choices":[]}"#)
        let noChoices = await cleanError(makeCleaner())
        XCTAssertEqual(noChoices, .invalidResponse)

        StubURLProtocol.respond(body: #"{"choices":[{"message":{"content":null}}]}"#)
        let nullContent = await cleanError(makeCleaner())
        XCTAssertEqual(nullContent, .invalidResponse)
    }

    func testClean_connectionFailure_isNetworkError() async {
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }

        let error = await cleanError(makeCleaner())

        guard case .network = error else { return XCTFail("expected .network, got \(String(describing: error))") }
    }

    func testClean_urlTimeout_isTimeoutError() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }

        let error = await cleanError(makeCleaner())

        XCTAssertEqual(error, .timeout)
    }

    func testListModels_parsesStripsModelsPrefixAndSorts() async throws {
        StubURLProtocol.respond(body: #"{"data":[{"id":"models/gemini-b"},{"id":"openai/gpt-oss-20b"},{"id":"models/gemini-a"}]}"#)

        let ids = try await makeCleaner(apiKey: "secret").listModels()

        XCTAssertEqual(ids, ["gemini-a", "gemini-b", "openai/gpt-oss-20b"])
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.absoluteString, "http://localhost:11434/v1/models")
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
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
