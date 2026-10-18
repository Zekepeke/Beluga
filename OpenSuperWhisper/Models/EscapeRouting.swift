import AppKit
import Foundation

/// Esc is both the search field's close key and the global "cancel recording" hotkey.
/// The hotkey fires on key up, after the search field has already handled the key down and
/// lost focus, so the main window records when the search consumed an Esc press.
enum EscapeRouting {
    /// How long after a search-handled Esc the matching key up is still treated as consumed.
    static let consumeWindow: TimeInterval = 0.6

    static func shouldCancelRecording(searchFieldFocused: Bool, searchConsumedAt: Date?, now: Date) -> Bool {
        if searchFieldFocused { return false }
        if let consumed = searchConsumedAt, now.timeIntervalSince(consumed) < consumeWindow { return false }
        return true
    }
}

@MainActor
final class SearchEscapeGuard {
    static let shared = SearchEscapeGuard()
    /// Set by the main window while its search field has keyboard focus.
    var isSearchFieldFocused = false
    private var consumedAt: Date?

    func searchHandledEscape(at date: Date = Date()) {
        consumedAt = date
    }

    /// Called by the Esc recording-cancel handler. Consumes a pending search Esc.
    func shouldCancelRecording(now: Date = Date()) -> Bool {
        let focused = isSearchFieldFocused && NSApp.isActive
        let allowed = EscapeRouting.shouldCancelRecording(searchFieldFocused: focused, searchConsumedAt: consumedAt, now: now)
        if consumedAt != nil, !allowed { consumedAt = nil }
        return allowed
    }
}

/// Whether a mouse-down closes the (empty) search field. Pure so the edge cases are testable.
enum SearchClickRule {
    /// A click this soon after opening is the opening click (or its echo) and never closes.
    static let openingGrace: TimeInterval = 0.3

    static func shouldClose(
        isOpen: Bool,
        queryIsEmpty: Bool,
        point: CGPoint,
        fieldFrame: CGRect,
        iconFrame: CGRect,
        secondsSinceOpened: TimeInterval
    ) -> Bool {
        guard isOpen, queryIsEmpty else { return false }
        // The field has not been laid out yet, so there is nothing to be "outside" of.
        guard !fieldFrame.isEmpty else { return false }
        guard secondsSinceOpened >= openingGrace else { return false }
        if iconFrame.contains(point) { return false }
        return !fieldFrame.contains(point)
    }
}
