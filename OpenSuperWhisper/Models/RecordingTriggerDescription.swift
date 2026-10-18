import Foundation

/// Short label for the recording trigger that is active right now.
/// Same precedence as `ShortcutManager.setupRecordingTrigger`: a mouse button wins over a
/// single modifier key, which wins over the regular key combination.
enum RecordingTriggerDescription {
    static func describe(mouseButton: MouseButton, modifierKey: ModifierKey, keyCombination: String?) -> String {
        if mouseButton != .none { return mouseButton.shortSymbol }
        if modifierKey != .none { return modifierKey.shortSymbol }
        return keyCombination ?? ""
    }
}
