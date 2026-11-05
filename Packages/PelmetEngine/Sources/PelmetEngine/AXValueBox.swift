// AXValueBox.swift
// Unbox an AX attribute that is supposed to be an AXValue. CopyAttribute can
// hand back some other CF type mid agent restart; a bare `as! AXValue` then
// crashes. Guard on AXValueGetTypeID first.

import ApplicationServices
import CoreGraphics

public enum AXValueBox {
    public static func cgPoint(from value: CFTypeRef?) -> CGPoint? {
        guard let ax = boxed(value) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(ax, .cgPoint, &point) else { return nil }
        return point
    }

    public static func cgSize(from value: CFTypeRef?) -> CGSize? {
        guard let ax = boxed(value) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(ax, .cgSize, &size) else { return nil }
        return size
    }

    public static func cgRect(from value: CFTypeRef?) -> CGRect? {
        guard let ax = boxed(value) else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(ax, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func boxed(_ value: CFTypeRef?) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}
