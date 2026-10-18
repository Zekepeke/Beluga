import XCTest
@testable import OpenSuperWhisper

/// The Settings sidebar must keep every setting from the old seven-tab layout reachable,
/// each in exactly one place.
final class SettingsSectionTests: XCTestCase {

    /// What each of today's seven tabs holds, written out by hand from the old SettingsView.
    private let legacyTabs: [(name: String, items: [SettingsItem])] = [
        ("Shortcuts", [.triggerMode, .keyboardShortcut, .modifierKey, .mouseButton,
                       .holdToRecord, .playSoundOnRecordStart, .escCancelWithoutConfirmation, .startHiddenInMenuBar]),
        ("Model", [.engine, .whisperModels, .parakeetModels, .modelsFolder]),
        ("Transcription", [.language, .asianAutocorrect, .showTimestamps, .suppressBlankAudio, .addSpaceAfterSentence,
                           .copyToClipboard, .autoPaste, .initialPrompt, .transcriptionsFolder,
                           .historyDiskUsage, .autoDeleteRecordings, .retentionDays]),
        ("Advanced", [.beamSearch, .beamSize, .temperature, .noSpeechThreshold, .debugMode]),
        ("Vocabulary", [.vocabularyWords, .textReplacements]),
        ("AI Cleanup", [.cleanupEnabled, .cleanupProvider, .cleanupBaseURL, .cleanupAPIKey, .cleanupModel,
                        .cleanupReasoningEffort, .cleanupTimeout, .cleanupTest]),
        ("Appearance", [.indicatorColor, .indicatorSize, .indicatorBackground, .accentColor,
                        .windowBackground, .windowColor, .tintStrength, .resetAppearance]),
    ]

    private var allSectionItems: [SettingsItem] {
        SettingsSection.allCases.flatMap { $0.items }
    }

    func testSections_areTheSixFromTheDesign_inOrder() {
        XCTAssertEqual(SettingsSection.allCases, [.general, .models, .transcription, .vocabulary, .aiCleanup, .appearance])
        XCTAssertEqual(SettingsSection.allCases.map(\.title),
                       ["General", "Models", "Transcription", "Vocabulary", "AI Cleanup", "Appearance"])
    }

    func testVocabularyAndAICleanup_sitNextToEachOther() {
        let all = SettingsSection.allCases
        let vocabulary = all.firstIndex(of: .vocabulary)!
        XCTAssertEqual(all.firstIndex(of: .aiCleanup), vocabulary + 1)
    }

    func testEverySectionHasAnIconAndId() {
        for section in SettingsSection.allCases {
            XCTAssertFalse(section.systemImage.isEmpty, section.title)
            XCTAssertEqual(section.id, section.rawValue)
        }
    }

    func testEveryLegacySetting_mapsToExactlyOneSection() {
        for tab in legacyTabs {
            for item in tab.items {
                let owners = SettingsSection.allCases.filter { $0.items.contains(item) }
                XCTAssertEqual(owners.count, 1, "\(item) from the \(tab.name) tab is in \(owners.count) sections")
                XCTAssertEqual(SettingsSection.section(for: item), owners.first, "\(item)")
            }
        }
    }

    func testNoSettingAppearsTwice() {
        let items = allSectionItems
        XCTAssertEqual(items.count, Set(items).count)
    }

    func testEveryItem_isInSomeSection() {
        for item in SettingsItem.allCases {
            XCTAssertTrue(allSectionItems.contains(item), "\(item) is not reachable")
        }
    }

    func testSections_holdNothingBeyondTheOldTabsAndTheCardColor() {
        let legacy = Set(legacyTabs.flatMap(\.items))
        let extras = Set(allSectionItems).subtracting(legacy)
        // Clipboard settings were in the Transcription tab and are in the legacy list; the card color is new in 3a.
        XCTAssertEqual(extras, [.cardColor])
    }

    func testClipboardAndPaste_moveToGeneral() {
        XCTAssertEqual(SettingsSection.section(for: .copyToClipboard), .general)
        XCTAssertEqual(SettingsSection.section(for: .autoPaste), .general)
        XCTAssertFalse(SettingsSection.transcription.items.contains(.copyToClipboard))
    }

    func testAdvancedSettings_liveInTheTranscriptionDisclosure() {
        let advanced: [SettingsItem] = [.beamSearch, .beamSize, .temperature, .noSpeechThreshold, .debugMode]
        XCTAssertEqual(SettingsSection.transcription.advancedItems, advanced)
        for item in advanced {
            XCTAssertEqual(SettingsSection.section(for: item), .transcription)
            XCTAssertTrue(SettingsSection.transcription.items.contains(item))
        }
        for section in SettingsSection.allCases where section != .transcription {
            XCTAssertTrue(section.advancedItems.isEmpty, section.title)
        }
    }

    func testGeneralSection_holdsTheOldShortcutsTab_plusClipboard() {
        let expected: Set<SettingsItem> = Set(legacyTabs[0].items + [.copyToClipboard, .autoPaste])
        XCTAssertEqual(Set(SettingsSection.general.items), expected)
    }

    func testOtherSections_keepTheirOldTabsContents() {
        XCTAssertEqual(Set(SettingsSection.models.items), Set(legacyTabs[1].items))
        XCTAssertEqual(Set(SettingsSection.vocabulary.items), Set(legacyTabs[4].items))
        XCTAssertEqual(Set(SettingsSection.aiCleanup.items), Set(legacyTabs[5].items))
        XCTAssertEqual(Set(SettingsSection.appearance.items), Set(legacyTabs[6].items + [.cardColor]))
    }

    func testTranscriptionSection_isOldTranscriptionMinusClipboardPlusAdvanced() {
        let old = Set(legacyTabs[2].items).subtracting([.copyToClipboard, .autoPaste])
        XCTAssertEqual(Set(SettingsSection.transcription.items), old.union(legacyTabs[3].items))
    }

    // MARK: - Window metrics

    func testWindowMetrics_matchTheDesign() {
        XCTAssertEqual(SettingsWindowMetrics.defaultSize, CGSize(width: 820, height: 600))
        XCTAssertEqual(SettingsWindowMetrics.sidebarWidth, 190)
    }

    func testMinimumSize_equalsTheDefaultSize() {
        XCTAssertEqual(SettingsWindowMetrics.minSize, SettingsWindowMetrics.defaultSize)
    }

    func testClampedContentSize_growsButNeverShrinksBelowTheMinimum() {
        XCTAssertEqual(SettingsWindowMetrics.clampedContentSize(CGSize(width: 300, height: 200)), CGSize(width: 820, height: 600))
        XCTAssertEqual(SettingsWindowMetrics.clampedContentSize(CGSize(width: 1000, height: 200)), CGSize(width: 1000, height: 600))
        XCTAssertEqual(SettingsWindowMetrics.clampedContentSize(CGSize(width: 300, height: 900)), CGSize(width: 820, height: 900))
        XCTAssertEqual(SettingsWindowMetrics.clampedContentSize(CGSize(width: 1400, height: 1000)), CGSize(width: 1400, height: 1000))
    }
}
