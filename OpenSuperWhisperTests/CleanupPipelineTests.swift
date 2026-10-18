import XCTest
@testable import OpenSuperWhisper

private final class FakeCleaner: TextCleaner, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [[CleanupMessage]] = []
    var behavior: @Sendable ([CleanupMessage]) async throws -> String

    init(_ behavior: @escaping @Sendable ([CleanupMessage]) async throws -> String = { _ in "Cleaned." }) {
        self.behavior = behavior
    }

    var calls: [[CleanupMessage]] {
        lock.lock(); defer { lock.unlock() }
        return _calls
    }

    private func record(_ messages: [CleanupMessage]) {
        lock.lock(); defer { lock.unlock() }
        _calls.append(messages)
    }

    func clean(messages: [CleanupMessage]) async throws -> String {
        record(messages)
        return try await behavior(messages)
    }
}

final class CleanupPipelineTests: XCTestCase {

    private let raw = "um so the meeting is tuesday no wait wednesday"

    private func config(
        enabled: Bool = true,
        model: String = "test-model",
        timeout: TimeInterval = 2,
        vocabulary: [String] = []
    ) -> CleanupConfig {
        CleanupConfig(
            enabled: enabled,
            provider: .ollama,
            baseURL: "http://localhost:11434/v1",
            model: model,
            apiKey: nil,
            reasoningEffort: "",
            timeout: timeout,
            vocabulary: vocabulary
        )
    }

    private func run(
        _ text: String? = nil,
        config: CleanupConfig? = nil,
        cleaner: TextCleaner,
        cooldown: CleanupCooldown = CleanupCooldown(),
        now: Date = Date()
    ) async -> CleanupOutcome {
        await CleanupPipeline.run(
            text: text ?? raw,
            config: config ?? self.config(),
            cleaner: cleaner,
            cooldown: cooldown,
            now: now
        )
    }

    func testRun_disabled_skipsWithoutCallingCleaner() async {
        let cleaner = FakeCleaner()

        let outcome = await run(config: config(enabled: false), cleaner: cleaner)

        XCTAssertEqual(outcome, .skipped(reason: .disabled, text: raw))
        XCTAssertTrue(cleaner.calls.isEmpty)
    }

    func testRun_emptyInput_returnsUntouchedWithoutCallingCleaner() async {
        let cleaner = FakeCleaner()

        let empty = await run("", cleaner: cleaner)
        let blank = await run("  \n", cleaner: cleaner)

        XCTAssertEqual(empty, .skipped(reason: .emptyInput, text: ""))
        XCTAssertEqual(empty.text, "")
        XCTAssertEqual(blank.text, "  \n")
        XCTAssertTrue(cleaner.calls.isEmpty)
    }

    func testRun_noModel_skipsWithoutCallingCleaner() async {
        let cleaner = FakeCleaner()

        let outcome = await run(config: config(model: "  "), cleaner: cleaner)

        XCTAssertEqual(outcome, .skipped(reason: .noModel, text: raw))
        XCTAssertTrue(cleaner.calls.isEmpty)
    }

    func testRun_success_returnsSanitizedText() async {
        let cleaner = FakeCleaner { _ in "<think>hmm</think>\n\"The meeting is Wednesday.\"" }

        let outcome = await run(cleaner: cleaner)

        XCTAssertEqual(outcome, .cleaned("The meeting is Wednesday."))
        XCTAssertEqual(outcome.text, "The meeting is Wednesday.")
    }

    func testRun_sendsPromptWithTranscriptAndVocabulary() async {
        let cleaner = FakeCleaner()

        _ = await run(config: config(vocabulary: ["WezTerm"]), cleaner: cleaner)

        let sent = cleaner.calls.first
        XCTAssertEqual(sent, CleanupPrompt.messages(transcript: raw, vocabulary: ["WezTerm"]))
    }

    func testRun_cleanerThrows_returnsRaw() async {
        let errors: [CleanupError] = [.http(status: 500), .invalidResponse, .network("offline")]
        for error in errors {
            let cleaner = FakeCleaner { _ in throw error }

            let outcome = await run(cleaner: cleaner)

            XCTAssertEqual(outcome, .skipped(reason: .failed, text: raw), "\(error)")
        }
    }

    func testRunReportingFailure_httpError_carriesStatusAndFallsBackToRaw() async {
        let cleaner = FakeCleaner { _ in throw CleanupError.http(status: 404) }

        let result = await CleanupPipeline.runReportingFailure(
            text: raw, config: config(), cleaner: cleaner, cooldown: CleanupCooldown()
        )

        XCTAssertEqual(result.outcome, .skipped(reason: .failed, text: raw))
        XCTAssertEqual(result.failure, .http(status: 404))
    }

    func testRunReportingFailure_noFailureOnSuccessOrNonErrorSkips() async {
        let ok = await CleanupPipeline.runReportingFailure(
            text: raw, config: config(), cleaner: FakeCleaner(), cooldown: CleanupCooldown()
        )
        XCTAssertEqual(ok.outcome, .cleaned("Cleaned."))
        XCTAssertNil(ok.failure)

        let rejected = await CleanupPipeline.runReportingFailure(
            text: raw, config: config(), cleaner: FakeCleaner { _ in "  " }, cooldown: CleanupCooldown()
        )
        XCTAssertEqual(rejected.outcome, .skipped(reason: .rejectedOutput, text: raw))
        XCTAssertNil(rejected.failure)
    }

    func testRun_cleanerTimeoutError_isReportedAsTimeout() async {
        let cleaner = FakeCleaner { _ in throw CleanupError.timeout }

        let outcome = await run(cleaner: cleaner)

        XCTAssertEqual(outcome, .skipped(reason: .timeout, text: raw))
    }

    func testRun_slowCleanerPastTimeout_returnsRaw() async {
        let cleaner = FakeCleaner { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return "Too late."
        }

        let started = Date()
        let outcome = await run(config: config(timeout: 0.05), cleaner: cleaner)

        XCTAssertEqual(outcome, .skipped(reason: .timeout, text: raw))
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testRun_rateLimited_returnsRawAndStartsCooldown() async {
        let limited = FakeCleaner { _ in throw CleanupError.rateLimited(retryAfter: 30) }
        let cooldown = CleanupCooldown()
        let now = Date()

        let first = await run(cleaner: limited, cooldown: cooldown, now: now)
        XCTAssertEqual(first, .skipped(reason: .rateLimited, text: raw))
        XCTAssertEqual(limited.calls.count, 1)

        let healthy = FakeCleaner()
        let during = await run(cleaner: healthy, cooldown: cooldown, now: now.addingTimeInterval(10))
        XCTAssertEqual(during, .skipped(reason: .coolingDown, text: raw))
        XCTAssertTrue(healthy.calls.isEmpty)

        let after = await run(cleaner: healthy, cooldown: cooldown, now: now.addingTimeInterval(31))
        XCTAssertEqual(after, .cleaned("Cleaned."))
        XCTAssertEqual(healthy.calls.count, 1)
    }

    func testRun_rateLimitedWithoutRetryAfter_coolsDownForSixtySeconds() async {
        let limited = FakeCleaner { _ in throw CleanupError.rateLimited(retryAfter: nil) }
        let cooldown = CleanupCooldown()
        let now = Date()

        _ = await run(cleaner: limited, cooldown: cooldown, now: now)

        let active = await cooldown.isActive(now: now.addingTimeInterval(59))
        let expired = await cooldown.isActive(now: now.addingTimeInterval(61))
        XCTAssertTrue(active)
        XCTAssertFalse(expired)
    }

    func testRun_sanitizerRejects_returnsRaw() async {
        let runaway = String(repeating: "I am answering your question at length. ", count: 20)
        let cleaner = FakeCleaner { _ in runaway }

        let outcome = await run(cleaner: cleaner)

        XCTAssertEqual(outcome, .skipped(reason: .rejectedOutput, text: raw))
    }

    func testRun_emptyModelOutput_returnsRaw() async {
        let cleaner = FakeCleaner { _ in "  " }

        let outcome = await run(cleaner: cleaner)

        XCTAssertEqual(outcome, .skipped(reason: .rejectedOutput, text: raw))
    }

    func testCooldown_isInactiveUntilSet() async {
        let cooldown = CleanupCooldown()
        let now = Date()

        let before = await cooldown.isActive(now: now)
        await cooldown.set(until: now.addingTimeInterval(5))
        let during = await cooldown.isActive(now: now)

        XCTAssertFalse(before)
        XCTAssertTrue(during)
    }
}

final class CleanupProviderTests: XCTestCase {

    func testPresets_matchPlan() {
        XCTAssertEqual(CleanupProvider.ollama.defaultBaseURL, "http://localhost:11434/v1")
        XCTAssertEqual(CleanupProvider.lmStudio.defaultBaseURL, "http://localhost:1234/v1")
        XCTAssertEqual(CleanupProvider.groq.defaultBaseURL, "https://api.groq.com/openai/v1")
        XCTAssertEqual(CleanupProvider.gemini.defaultBaseURL, "https://generativelanguage.googleapis.com/v1beta")
        XCTAssertEqual(CleanupProvider.custom.defaultBaseURL, "")

        XCTAssertEqual(CleanupProvider.allCases.filter(\.requiresAPIKey), [.groq, .gemini])
        XCTAssertEqual(CleanupProvider.allCases.filter(\.isLocal), [.ollama, .lmStudio])
        XCTAssertEqual(CleanupProvider.groq.defaultReasoningEffort, "low")
        XCTAssertEqual(CleanupProvider.allCases.filter { $0.defaultReasoningEffort.isEmpty }.count, 4)
        XCTAssertEqual(CleanupProvider.allCases.filter { !$0.supportsReasoningEffort }, [.gemini])
    }

    func testMakeCleaner_geminiUsesNativeBackend() {
        let cleaner = CleanupPipeline.makeCleaner(
            provider: .gemini, baseURL: CleanupProvider.gemini.defaultBaseURL,
            model: "m", apiKey: "k", reasoningEffort: ""
        )

        XCTAssertTrue(cleaner is GeminiNativeCleaner)
    }

    func testMakeCleaner_otherProvidersUseOpenAICompatibleBackend() {
        for provider in CleanupProvider.allCases where provider != .gemini {
            let cleaner = CleanupPipeline.makeCleaner(
                provider: provider, baseURL: "http://example.test/v1",
                model: "m", apiKey: nil, reasoningEffort: ""
            )

            XCTAssertTrue(cleaner is OpenAICompatibleCleaner, "\(provider)")
        }
    }
}
