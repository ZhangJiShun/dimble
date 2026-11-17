// MenuBarShown.swift
// Whether a display's menu bar is actually down on screen. A full-screen
// app that auto-hides the bar parks WindowServer's "Menubar" window above
// the display's top edge (or takes it off screen), and slides it back down
// when the pointer hits the top. While it is up or still sliding, a click in
// the clock's corner belongs to the app underneath (or to the slide), not to
// the clock. Pure geometry over the window list's entries, so the relay's
// event-tap callback can ask cheaply and tests can pin the rule.

import CoreGraphics

public enum MenuBarShown {
    /// One "Menubar" window entry from the window list.
    public struct Window: Equatable, Sendable {
        public var bounds: CGRect
        public var onScreen: Bool
        public var alpha: Double

        public init(bounds: CGRect, onScreen: Bool, alpha: Double = 1) {
            self.bounds = bounds
            self.onScreen = onScreen
            self.alpha = alpha
        }
    }

    /// Slack for rounding in the window server's bounds.
    static let slack: CGFloat = 1

    /// nil: no Menubar window at all, so the rule cannot judge and the caller
    /// keeps its old behaviour. true: one is fully down on `display`.
    /// false: some exist but none is fully down there (hidden or sliding).
    /// `windows` are the Menubar entries of every display, off-screen ones
    /// included; `display` is in the same top-left global coordinates.
    public static func isShown(on display: CGRect, windows: [Window]) -> Bool? {
        guard !windows.isEmpty else { return nil }
        return windows.contains { window in
            guard window.onScreen, window.alpha > 0.05,
                  window.bounds.height > 0,
                  window.bounds.midX >= display.minX, window.bounds.midX < display.maxX
            else { return false }
            // Fully down: its top edge on the display's top edge. Anything
            // higher is hidden or mid-slide; anything far lower is not the bar.
            return abs(window.bounds.minY - display.minY) <= slack
        }
    }
}
