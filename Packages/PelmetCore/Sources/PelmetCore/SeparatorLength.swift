// SeparatorLength.swift
// What a host writes onto a separator's NSStatusItem.length. Spacers take
// `width`; glyphs size themselves (`variableLength` = -1). Kept in Core so
// a leftover spacer width is overwritten on a style switch, without AppKit.

import Foundation

extension SeparatorSpec {
    /// Length a host writes onto the status item. `nil` means variableLength
    /// (the glyph sizes itself). Spacers use `width`.
    public var hostedLength: Double? {
        style == .space ? width : nil
    }
}

public enum SeparatorLength {
    /// NSStatusItem.variableLength is -1. Kept here so Core tests don't import AppKit.
    public static let variable: Double = -1

    /// What `shownLength` / helper configure should apply. `hostedLength` nil → variable.
    public static func appliedLength(hostedLength: Double?) -> Double {
        hostedLength ?? variable
    }

    /// Style switch: a leftover spacer width must be overwritten when the new
    /// spec's hostedLength is nil, and spacers must write `width` even if the
    /// item already has some length.
    public static func needsLengthWrite(currentLength: Double, hostedLength: Double?) -> Bool {
        appliedLength(hostedLength: hostedLength) != currentLength
    }
}
