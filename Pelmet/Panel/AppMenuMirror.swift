// AppMenuMirror.swift
// A panel tile's right-click shows the app's own menu beside the tile, not
// under the app's real icon far off on the bar (2026-11-17).
//
// Most status items keep their NSMenu attached, and the app's AX tree lists
// it with the menu shut and the icon concealed: titles, the ✓ mark, key
// equivalents, enabled state, separators, submenus. Dimble builds the same
// menu from that tree and pops it up at the pointer; a pick sends AXPress to
// the matching item, which runs it without the real menu ever opening —
// nothing on the bar moves, nothing flashes. An item that draws its own
// panel or builds its menu on the click (WeChat, Tokei, Mole) lists none,
// and the caller falls back to clicking the real icon.
//
// Item images are not on AX, so the copy is text only. A menu an app fills
// in `menuNeedsUpdate` reads as it was the last time it opened.

import AppKit
import ApplicationServices
import PelmetCore
import PelmetEngine

@MainActor
enum AppMenuMirror {
    /// AX calls here run on the main thread: each one is capped well under
    /// the 6 s default (AGENTS.md §6).
    private static let timeout: Float = 0.4
    /// Deeper than any real status menu; a cycle in a broken tree stops here.
    private static let maxDepth = 4

    /// The app's own menu for `key`'s icon, rebuilt; nil when there is no
    /// attached menu to copy (the caller clicks the real icon instead).
    /// `picked` runs after an item was pressed.
    static func menu(for key: ItemID, bundle: String, picked: @escaping @MainActor () -> Void) -> NSMenu? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
            return nil
        }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, timeout)
        guard let barValue = attribute(element, "AXExtrasMenuBar") else { return nil }
        let bar = barValue as! AXUIElement
        let icons = children(bar)
        guard let icon = pickIcon(icons, for: key) else {
            PelmetLog.log("menu mirror: \(key.rawValue) — \(icons.count) icon(s), none picked")
            return nil
        }
        guard let source = children(icon).first(where: { role($0) == kAXMenuRole }) else {
            PelmetLog.log("menu mirror: \(key.rawValue) — no attached menu, real click")
            return nil
        }
        let started = Date()
        let built = build(source, depth: 0, picked: picked)
        let real = built.items.filter { !$0.isSeparatorItem }
        guard !real.isEmpty else {
            PelmetLog.log("menu mirror: \(key.rawValue) — attached menu is empty, real click")
            return nil
        }
        PelmetLog.log("menu mirror: \(key.rawValue) — \(real.count) item(s) read in \(Int(-started.timeIntervalSinceNow * 1000))ms")
        return built
    }

    /// The icon `key` stands for: the only one, or the one whose title or
    /// description is the key's title.
    private static func pickIcon(_ icons: [AXUIElement], for key: ItemID) -> AXUIElement? {
        if icons.count == 1 { return icons[0] }
        guard case .status(_, let title) = key.parsed else { return nil }
        return icons.first {
            string($0, kAXTitleAttribute) == title
                || string($0, kAXDescriptionAttribute) == title
                || string($0, kAXIdentifierAttribute) == title
        }
    }

    private static func build(_ source: AXUIElement, depth: Int, picked: @escaping @MainActor () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for element in children(source) where role(element) == kAXMenuItemRole {
            let title = string(element, kAXTitleAttribute)
            let enabled = (attribute(element, kAXEnabledAttribute) as? Bool) ?? true
            // AppKit lists a separator as an untitled, disabled item.
            if title.isEmpty, !enabled {
                if menu.items.last.map({ !$0.isSeparatorItem }) == true { menu.addItem(.separator()) }
                continue
            }
            let item = AppMenuMirrorItem(title: title, element: element, picked: picked)
            item.isEnabled = enabled
            if !string(element, "AXMenuItemMarkChar").isEmpty { item.state = .on }
            let key = string(element, "AXMenuItemCmdChar")
            if !key.isEmpty {
                item.keyEquivalent = key.lowercased()
                item.keyEquivalentModifierMask = modifiers(attribute(element, "AXMenuItemCmdModifiers") as? Int ?? 0)
                    .union(key != key.lowercased() ? .shift : [])
            }
            if depth < maxDepth, let sub = children(element).first(where: { role($0) == kAXMenuRole }) {
                let submenu = build(sub, depth: depth + 1, picked: picked)
                submenu.title = title
                item.submenu = submenu
                item.action = nil
            }
            menu.addItem(item)
        }
        if menu.items.last?.isSeparatorItem == true { menu.removeItem(at: menu.items.count - 1) }
        return menu
    }

    /// `AXMenuItemCmdModifiers`: ⌘ unless bit 3, plus ⇧ (bit 0), ⌥ (bit 1), ⌃ (bit 2).
    private static func modifiers(_ raw: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = raw & 8 == 0 ? [.command] : []
        if raw & 1 != 0 { flags.insert(.shift) }
        if raw & 2 != 0 { flags.insert(.option) }
        if raw & 4 != 0 { flags.insert(.control) }
        return flags
    }

    // MARK: - AX

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        let list = (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
        // The cap set on the app element is not inherited by the elements it hands out.
        for child in list { AXUIElementSetMessagingTimeout(child, timeout) }
        return list
    }

    private static func role(_ element: AXUIElement) -> String { string(element, kAXRoleAttribute) }

    private static func string(_ element: AXUIElement, _ name: String) -> String {
        (attribute(element, name) as? String) ?? ""
    }
}

/// One copied item: a pick presses the app's own item over AX.
nonisolated final class AppMenuMirrorItem: NSMenuItem {
    private let element: AXUIElement
    private let picked: @MainActor () -> Void

    init(title: String, element: AXUIElement, picked: @escaping @MainActor () -> Void) {
        self.element = element
        self.picked = picked
        super.init(title: title, action: #selector(press), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    @objc private func press() {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        PelmetLog.log("menu mirror: picked '\(title)' — AXPress \(result == .success ? "ok" : "failed (\(result.rawValue))")")
        let picked = self.picked
        MainActor.assumeIsolated { picked() }
    }
}

