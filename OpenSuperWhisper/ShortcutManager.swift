import AppKit
import Combine
import ApplicationServices
import Carbon
import Cocoa
import Foundation
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let toggleRecord = Self("toggleRecord", initial: .init(.backtick, modifiers: .option))
    static let escape = Self("escape", initial: .init(.escape))
}

@MainActor
class ShortcutManager {
    static let shared = ShortcutManager()

    private var triggerPermissions: PermissionsManager?
    private var permissionSubscription: AnyCancellable?
    private var activeVm: IndicatorViewModel?
    private var holdWorkItem: DispatchWorkItem?
    private let holdThreshold: TimeInterval = 0.3
    private var holdMode = false
    private var useModifierOnlyHotkey = false
    private var useMouseButtonHotkey = false

    init(registerShortcuts: Bool = true) {
        guard registerShortcuts else { return }
        Log.hotkey.info("ShortcutManager init")

        setupKeyboardShortcuts()
        setupRecordingTrigger()
        let permissions = PermissionsManager()
        triggerPermissions = permissions
        observeTriggerPermissions(permissions.$isAccessibilityPermissionGranted
            .combineLatest(permissions.$isInputMonitoringPermissionGranted)
            .map { ($0 ? 1 : 0) | ($1 ? 2 : 0) }
            .eraseToAnyPublisher()) { [weak self] in self?.setupRecordingTrigger() }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: .hotkeySettingsChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(indicatorWindowDidHide),
            name: .indicatorWindowDidHide,
            object: nil
        )
    }
    
    func observeTriggerPermissions(_ publisher: AnyPublisher<Int, Never>, reconfigure: @escaping () -> Void) {
        permissionSubscription = publisher
            .removeDuplicates()
            .dropFirst()
            .sink { _ in reconfigure() }
    }

    @objc private func indicatorWindowDidHide() {
        activeVm = nil
        holdMode = false
    }
    
    @objc private func hotkeySettingsChanged() {
        setupRecordingTrigger()
    }
    
    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .toggleRecord) { [weak self] in
            self?.handleKeyDown()
        }

        KeyboardShortcuts.onKeyUp(for: .toggleRecord) { [weak self] in
            self?.handleKeyUp()
        }

        KeyboardShortcuts.onKeyUp(for: .escape) { [weak self] in
            Task { @MainActor in
                self?.handleEscape()
            }
        }
        KeyboardShortcuts.disable(.escape)
    }
    
    func handleEscape() {
        // Esc closes the main window's search field first; it must not also cancel a recording.
        guard SearchEscapeGuard.shared.shouldCancelRecording() else { return }
        if IndicatorWindowManager.shared.requestCancel() {
            activeVm = nil
        }
    }

    private func setupRecordingTrigger() {
        let modifierKey = ModifierKey(rawValue: AppPreferences.shared.modifierOnlyHotkey) ?? .none
        let mouseButton = MouseButton(rawValue: AppPreferences.shared.mouseButtonHotkey) ?? .none

        // The three trigger modes are mutually exclusive. Tear all of them down
        // first, then enable exactly one. A configured mouse button takes priority
        // over a modifier key, which takes priority over the regular shortcut.
        ModifierKeyMonitor.shared.stop()
        MouseButtonMonitor.shared.stop()

        if mouseButton != .none {
            useMouseButtonHotkey = true
            useModifierOnlyHotkey = false
            KeyboardShortcuts.disable(.toggleRecord)

            MouseButtonMonitor.shared.onButtonDown = { [weak self] in
                self?.handleKeyDown()
            }

            MouseButtonMonitor.shared.onButtonUp = { [weak self] in
                self?.handleKeyUp()
            }

            MouseButtonMonitor.shared.start(mouseButton: mouseButton)
            Log.hotkey.info("trigger: mouse button \(mouseButton.displayName, privacy: .public)")
        } else if modifierKey != .none {
            useMouseButtonHotkey = false
            useModifierOnlyHotkey = true
            KeyboardShortcuts.disable(.toggleRecord)

            ModifierKeyMonitor.shared.onKeyDown = { [weak self] in
                self?.handleKeyDown()
            }

            ModifierKeyMonitor.shared.onKeyUp = { [weak self] in
                self?.handleKeyUp()
            }

            ModifierKeyMonitor.shared.start(modifierKey: modifierKey)
            Log.hotkey.info("trigger: modifier key \(modifierKey.displayName, privacy: .public)")
        } else {
            useMouseButtonHotkey = false
            useModifierOnlyHotkey = false
            KeyboardShortcuts.enable(.toggleRecord)
            Log.hotkey.info("trigger: keyboard shortcut")
        }
    }
    
    private func handleKeyDown() {
        holdWorkItem?.cancel()
        holdMode = false
        
        let session = RecordingSessionController.shared
        if session.hasSession {
            Log.hotkey.info("record trigger pressed, stopping active session")
            session.requestStop()
            return
        }
        guard activeVm == nil else { return }
        Log.hotkey.info("record trigger pressed")
        activeVm = IndicatorWindowManager.shared.beginDictation()
        if AppPreferences.shared.holdToRecord && session.isCapturing {
            let workItem = DispatchWorkItem { [weak self] in self?.holdMode = true }
            holdWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)
        }
    }

    private func handleKeyUp() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        
        let holdToRecordEnabled = AppPreferences.shared.holdToRecord
        
        Task { @MainActor in
            if holdToRecordEnabled && self.holdMode && self.activeVm != nil {
                IndicatorWindowManager.shared.stopRecording()
            }
            self.holdMode = false
        }
    }
}
