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
}
