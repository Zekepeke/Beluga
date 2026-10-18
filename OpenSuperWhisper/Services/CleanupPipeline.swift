import Foundation

/// Snapshot of the cleanup settings, taken when a dictation starts.
struct CleanupConfig {
    var enabled: Bool
    var provider: CleanupProvider
    var baseURL: String
    var model: String
    var apiKey: String?
    var reasoningEffort: String
    var timeout: TimeInterval
    var vocabulary: [String]

    static func current(prefs: AppPreferences = .shared) -> CleanupConfig {
        let provider = CleanupProvider(rawValue: prefs.cleanupProvider) ?? .ollama
        let enabled = prefs.cleanupEnabled
        return CleanupConfig(
            enabled: enabled,
            provider: provider,
            baseURL: prefs.cleanupBaseURL,
            model: prefs.cleanupModel,
            // Only touch the Keychain when cleanup will actually run.
            apiKey: enabled ? KeychainStore.get(for: provider) : nil,
            reasoningEffort: prefs.cleanupReasoningEffort,
            timeout: prefs.cleanupTimeoutSeconds,
            vocabulary: prefs.vocabularyWords
        )
    }
}

enum CleanupOutcome: Equatable {
    enum SkipReason: Equatable {
        case disabled, emptyInput, noModel, coolingDown, timeout, rateLimited, failed, rejectedOutput
    }

    case cleaned(String)
    case skipped(reason: SkipReason, text: String)

    /// The text to save and paste.
    var text: String {
        switch self {
        case .cleaned(let text), .skipped(_, let text): return text
        }
    }
}

/// After a rate limit, cleanup is skipped until the cooldown passes. In memory only.
actor CleanupCooldown {
    static let shared = CleanupCooldown()

    private var until: Date?

    func isActive(now: Date) -> Bool {
        guard let until else { return false }
        return now < until
    }

    func set(until: Date) {
        self.until = until
    }
}

enum CleanupPipeline {
    static let defaultCooldown: TimeInterval = 60

    static func makeCleaner(
        provider: CleanupProvider,
        baseURL: String,
        model: String,
        apiKey: String?,
        reasoningEffort: String?,
        session: URLSession = .shared
    ) -> any TextCleaner & ModelListing {
        switch provider {
        case .gemini:
            return GeminiNativeCleaner(baseURL: baseURL, model: model, apiKey: apiKey, session: session)
        case .ollama, .lmStudio, .groq, .custom:
            return OpenAICompatibleCleaner(baseURL: baseURL, model: model, apiKey: apiKey, reasoningEffort: reasoningEffort, session: session)
        }
    }

    static func makeCleaner(config: CleanupConfig, session: URLSession = .shared) -> any TextCleaner & ModelListing {
        makeCleaner(
            provider: config.provider,
            baseURL: config.baseURL,
            model: config.model,
            apiKey: config.apiKey,
            reasoningEffort: config.reasoningEffort,
            session: session
        )
    }

    /// Never throws: any problem returns the raw text so dictation keeps working.
    static func run(
        text: String,
        config: CleanupConfig,
        cleaner: TextCleaner,
        cooldown: CleanupCooldown,
        now: Date = Date()
    ) async -> CleanupOutcome {
        await runReportingFailure(text: text, config: config, cleaner: cleaner, cooldown: cooldown, now: now).outcome
    }

    /// Same as `run`, plus the cleaner's error when one caused the fallback.
    /// Used by the Settings Test button to explain a fallback; dictation ignores it.
    static func runReportingFailure(
        text: String,
        config: CleanupConfig,
        cleaner: TextCleaner,
        cooldown: CleanupCooldown,
        now: Date = Date()
    ) async -> (outcome: CleanupOutcome, failure: CleanupError?) {
        var failure: CleanupError?
        let outcome = await execute(text: text, config: config, cleaner: cleaner, cooldown: cooldown, now: now, failure: &failure)
        return (outcome, failure)
    }

    private static func execute(
        text: String,
        config: CleanupConfig,
        cleaner: TextCleaner,
        cooldown: CleanupCooldown,
        now: Date,
        failure: inout CleanupError?
    ) async -> CleanupOutcome {
        guard config.enabled else { return .skipped(reason: .disabled, text: text) }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .skipped(reason: .emptyInput, text: text)
        }
        guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return skip(.noModel, text)
        }
        guard !(await cooldown.isActive(now: now)) else { return skip(.coolingDown, text) }

        let messages = CleanupPrompt.messages(transcript: text, vocabulary: config.vocabulary)
        let output: String
        do {
            output = try await race(cleaner: cleaner, messages: messages, timeout: config.timeout)
        } catch CleanupError.rateLimited(let retryAfter) {
            await cooldown.set(until: now.addingTimeInterval(retryAfter ?? defaultCooldown))
            return skip(.rateLimited, text)
        } catch CleanupError.timeout {
            return skip(.timeout, text)
        } catch {
            failure = error as? CleanupError
            return skip(.failed, text)
        }

        guard let sanitized = CleanupSanitizer.sanitize(output: output, raw: text) else {
            return skip(.rejectedOutput, text)
        }
        return .cleaned(sanitized)
    }

    private static func race(cleaner: TextCleaner, messages: [CleanupMessage], timeout: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await cleaner.clean(messages: messages) }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(timeout, 0) * 1_000_000_000))
                throw CleanupError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CleanupError.invalidResponse }
            return first
        }
    }

    /// Logs the reason only: never the transcript or the API key.
    private static func skip(_ reason: CleanupOutcome.SkipReason, _ text: String) -> CleanupOutcome {
        print("[Cleanup] skipped: \(reason)")
        return .skipped(reason: reason, text: text)
    }
}
