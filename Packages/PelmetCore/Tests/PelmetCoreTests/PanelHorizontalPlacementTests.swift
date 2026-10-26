import CoreGraphics
import Testing
@testable import PelmetCore

struct PanelHorizontalPlacementTests {
    @Test func centresUnderTheAnchorWhenItFits() {
        let p = PanelHorizontalPlacement.glassLeft(anchor: 500, width: 200, minX: 0, maxX: 1000)
        #expect(p.x == 400 && p.centered)
    }

    @Test func anEdgePushesItInAndLosesTheCentre() {
        let right = PanelHorizontalPlacement.glassLeft(anchor: 950, width: 200, minX: 0, maxX: 1000)
        #expect(right.x == 800 && !right.centered)
        let left = PanelHorizontalPlacement.glassLeft(anchor: 50, width: 200, minX: 8, maxX: 1000)
        #expect(left.x == 8 && !left.centered)
        let wide = PanelHorizontalPlacement.glassLeft(anchor: 500, width: 2000, minX: 8, maxX: 1000)
        #expect(wide.x == 8 && !wide.centered)
    }

    @Test func gripAsksForTheRightWidth() {
        // Centred on 500, the pointer at 400 means a panel 200 wide.
        #expect(PanelHorizontalPlacement.dragDistance(pointerX: 400, anchor: 500, rightEdge: 700) == 200)
        // Pushed against the right edge, the distance is from that edge.
        #expect(PanelHorizontalPlacement.dragDistance(pointerX: 400, anchor: nil, rightEdge: 700) == 300)
    }

    // The chevron's centre is known: the answer follows the pointer wherever
    // an edge pushes the panel, and does not depend on the panel's own width.
    @Test func gripWithAnAnchorIsStableAtEveryEdge() {
        // Room on both sides: half the width from the anchor.
        #expect(PanelHorizontalPlacement.dragDistance(pointerX: 400, anchor: 500, maxX: 900) == 200)
        // Centring would run over the right edge (anchor 500 + 300 > 700):
        // that edge holds, the width is the distance to it.
        #expect(PanelHorizontalPlacement.dragDistance(pointerX: 300, anchor: 500, maxX: 700) == 400)
        // Past that point the right edge keeps holding: 290 asks for 410.
        #expect(PanelHorizontalPlacement.dragDistance(pointerX: 290, anchor: 500, maxX: 700) == 410)
    }

    // Pushed by the left edge, a drag to the right shrinks the panel by the
    // same amount whatever width it has now: no feedback through its right edge.
    @Test func leftPushedDragDoesNotChaseItsOwnRightEdge() {
        let anchor: CGFloat = 200, minX: CGFloat = 8, maxX: CGFloat = 1000
        // Wide enough to be pushed (wanted left 200 - 250 < 8), pointer at the edge.
        let pushed = PanelHorizontalPlacement.glassLeft(anchor: anchor, width: 500, minX: minX, maxX: maxX)
        #expect(pushed.x == minX && !pushed.centered)
        // The pointer 40pt in from the left edge asks for a width that depends
        // on the pointer alone (the old right-edge reading gave the panel's
        // current width less 40, so every step asked for less than the last).
        let pointer = minX + 40
        let asked = PanelHorizontalPlacement.dragDistance(pointerX: pointer, anchor: anchor, maxX: maxX)
        #expect(asked == 2 * (anchor - pointer))
        // That width centres, so the panel's left edge ends on the pointer.
        let settled = PanelHorizontalPlacement.glassLeft(anchor: anchor, width: asked, minX: minX, maxX: maxX)
        #expect(settled.centered && settled.x == pointer)
    }
}
