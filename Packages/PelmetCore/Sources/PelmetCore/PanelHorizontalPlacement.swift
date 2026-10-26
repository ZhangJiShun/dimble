// PanelHorizontalPlacement.swift
// Where the panel's glass sits sideways: centred under the chevron, pushed
// in by the display's edges when it won't fit. Pure, so the real panel and
// the Settings preview agree.

import CoreGraphics

public enum PanelHorizontalPlacement {
    /// The glass's left edge for a panel `width` wide centred on `anchor`,
    /// kept between `minX` and `maxX`. `centered` is false when an edge
    /// pushed it, so the chevron is no longer over its middle.
    public static func glassLeft(anchor: CGFloat, width: CGFloat, minX: CGFloat, maxX: CGFloat)
        -> (x: CGFloat, centered: Bool)
    {
        let wanted = anchor - width / 2
        let highest = maxX - width
        guard highest >= minX else { return (minX, false) }
        if wanted < minX { return (minX, false) }
        if wanted > highest { return (highest, false) }
        return (wanted, true)
    }

    /// The width the column grip's pointer asks for. Centred, both edges
    /// move as the panel widens, so the pointer is half the width from the
    /// anchor; pushed by an edge, the right edge stays put.
    public static func dragDistance(pointerX: CGFloat, anchor: CGFloat?, rightEdge: CGFloat) -> CGFloat {
        if let anchor { return 2 * (anchor - pointerX) }
        return rightEdge - pointerX
    }
}
