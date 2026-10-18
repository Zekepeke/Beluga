import CoreGraphics

/// One setting (or one tightly bound group, like the trigger mode and its picker) from the Settings UI.
/// The sidebar sections list these so a test can prove nothing was lost or duplicated when the
/// seven tabs became six sections.
enum SettingsItem: String, CaseIterable {
    // Recording
    case triggerMode, keyboardShortcut, modifierKey, mouseButton
    case holdToRecord, playSoundOnRecordStart, escCancelWithoutConfirmation, startHiddenInMenuBar
    case copyToClipboard, autoPaste
    // Models
    case engine, whisperModels, parakeetModels, modelsFolder
    // Transcription
    case language, asianAutocorrect, showTimestamps, suppressBlankAudio, addSpaceAfterSentence
    case initialPrompt, transcriptionsFolder, historyDiskUsage, autoDeleteRecordings, retentionDays
    // Transcription > Advanced
    case beamSearch, beamSize, temperature, noSpeechThreshold, debugMode
    // Vocabulary
    case vocabularyWords, textReplacements
    // AI Cleanup
    case cleanupEnabled, cleanupProvider, cleanupBaseURL, cleanupAPIKey, cleanupModel
    case cleanupReasoningEffort, cleanupTimeout, cleanupTest
    // Appearance
    case indicatorColor, indicatorSize, indicatorBackground, accentColor, cardColor
    case windowBackground, windowColor, tintStrength, resetAppearance
}

/// The six sidebar sections (design/DESIGN.md), in sidebar order.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, models, transcription, vocabulary, aiCleanup, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .models: return "Models"
        case .transcription: return "Transcription"
        case .vocabulary: return "Vocabulary"
        case .aiCleanup: return "AI Cleanup"
        case .appearance: return "Appearance"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .models: return "cube"
        case .transcription: return "waveform"
        case .vocabulary: return "character.book.closed"
        case .aiCleanup: return "sparkles"
        case .appearance: return "paintbrush"
        }
    }

    /// Settings shown in the Advanced disclosure at the bottom of Transcription.
    var advancedItems: [SettingsItem] {
        self == .transcription ? [.beamSearch, .beamSize, .temperature, .noSpeechThreshold, .debugMode] : []
    }

    /// Everything the section holds, including its Advanced disclosure.
    var items: [SettingsItem] {
        switch self {
        case .general:
            return [.triggerMode, .keyboardShortcut, .modifierKey, .mouseButton,
                    .holdToRecord, .playSoundOnRecordStart, .escCancelWithoutConfirmation,
                    .copyToClipboard, .autoPaste, .startHiddenInMenuBar]
        case .models:
            return [.engine, .whisperModels, .parakeetModels, .modelsFolder]
        case .transcription:
            return [.language, .asianAutocorrect, .showTimestamps, .suppressBlankAudio, .addSpaceAfterSentence,
                    .initialPrompt, .transcriptionsFolder, .historyDiskUsage, .autoDeleteRecordings, .retentionDays]
                + advancedItems
        case .vocabulary:
            return [.vocabularyWords, .textReplacements]
        case .aiCleanup:
            return [.cleanupEnabled, .cleanupProvider, .cleanupBaseURL, .cleanupAPIKey, .cleanupModel,
                    .cleanupReasoningEffort, .cleanupTimeout, .cleanupTest]
        case .appearance:
            return [.indicatorColor, .indicatorSize, .indicatorBackground, .accentColor, .cardColor,
                    .windowBackground, .windowColor, .tintStrength, .resetAppearance]
        }
    }

    static func section(for item: SettingsItem) -> SettingsSection? {
        allCases.first { $0.items.contains(item) }
    }
}

enum SettingsWindowMetrics {
    /// Clamps a proposed content size to the minimum. Windows may be larger, never smaller.
    static func clampedContentSize(_ proposed: CGSize) -> CGSize {
        CGSize(width: max(proposed.width, minSize.width), height: max(proposed.height, minSize.height))
    }

    static let defaultSize = CGSize(width: 820, height: 600)
    /// The window can grow but never shrink below its default size, so the sidebar always fits.
    static let minSize = defaultSize
    static let sidebarWidth: CGFloat = 190
}
