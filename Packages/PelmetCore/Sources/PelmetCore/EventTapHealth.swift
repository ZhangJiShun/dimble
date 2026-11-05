// EventTapHealth.swift
// HoverTypingTap / BarDragRedirect idle disabled. Rebuild only when a port
// object still exists but is no longer valid (Accessibility revoke).

import Foundation

public enum EventTapHealth {
    /// Session taps that idle disabled (HoverTypingTap, BarDragRedirect).
    /// Rebuild only when a port object still exists but is no longer valid
    /// (Accessibility revoke / silent drop). A nil tap is started by `arm()`,
    /// not rebuilt. A valid-but-disabled tap is the idle state.
    public static func needsRebuild(tapExists: Bool, isValid: Bool) -> Bool {
        tapExists && !isValid
    }
}
