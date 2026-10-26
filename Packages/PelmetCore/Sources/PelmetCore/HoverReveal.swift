import CoreGraphics

public enum HoverRevealGeometry {
    /// Cocoa screen coordinates. Menu bars repeat at the same right inset;
    /// clip the live button's clickable bounds to the destination's band.
    /// No drawn button means no target, never a fallback to empty space.
    public static func iconTarget(button: CGRect?, sourceBand: CGRect, targetBand: CGRect) -> CGRect? {
        guard let button, !button.isEmpty, !sourceBand.isEmpty, !targetBand.isEmpty,
              button.minX >= sourceBand.minX, button.maxX <= sourceBand.maxX,
              button.intersects(sourceBand) else { return nil }
        let projected = button.offsetBy(dx: targetBand.maxX - sourceBand.maxX,
                                        dy: targetBand.maxY - sourceBand.maxY)
        let clipped = projected.intersection(targetBand)
        return clipped.isEmpty || clipped.isNull ? nil : clipped
    }
}

/// The dwell's lifetime, independent of a run loop. A cancelled timer may
/// already have queued its main-actor task; its ticket must expire too.
public struct HoverDwellState: Sendable {
    public private(set) var isInside = false
    public private(set) var isSuppressed = false
    private var generation: UInt = 0

    public init() {}

    /// True only on entry. Holding rehide off still uses the whole band.
    @discardableResult
    public mutating func update(inTarget: Bool, inBand: Bool, scope: HoverRevealScope) -> Bool {
        let entered = inTarget && !isInside
        if isInside && !inTarget { generation &+= 1 }
        isInside = inTarget
        if !inBand || (scope == .iconOnly && !inTarget) { isSuppressed = false }
        return entered
    }

    public mutating func arm() -> UInt? {
        guard isInside, !isSuppressed else { return nil }
        generation &+= 1
        return generation
    }

    public func allowsReveal(_ ticket: UInt) -> Bool {
        isInside && !isSuppressed && generation == ticket
    }

    public mutating func suppress(inBand: Bool) {
        guard inBand else { return }
        isSuppressed = true
        generation &+= 1
    }

    public mutating func resetTarget() {
        isInside = false
        generation &+= 1
    }
}
