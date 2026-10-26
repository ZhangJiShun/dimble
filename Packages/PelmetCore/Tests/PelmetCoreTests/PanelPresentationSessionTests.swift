import Testing
@testable import PelmetCore

struct PanelPresentationSessionTests {
    private let a = PanelTile.item(.bundleKey("app.a"))
    private let b = PanelTile.item(.bundleKey("app.b"))

    private func model(_ tiles: [PanelTile]) -> PanelModel {
        PanelModel(sections: [.init(kind: .hidden, tiles: tiles, isFolded: false)], bestMatch: nil)
    }

    @Test func backgroundDiscoveryDoesNotInsertOrReorderTilesInAnOpenPanel() {
        var session = PanelPresentationSession<String, String>()
        let first = session.stabilize(model([a]), context: "normal")
        let later = session.stabilize(model([b, a]), context: "normal")
        #expect(first == model([a]))
        #expect(later == first)
        session.reset()
        let reopened = session.stabilize(model([b, a]), context: "normal")
        #expect(reopened == model([b, a]))
    }

    @Test func realPictureReplacesAStandInOnceThenStaysPut() {
        var session = PanelPresentationSession<String, String>()
        _ = session.stabilize(model([a]), context: "normal")
        let initial = session.image(for: a, proposed: "gray fallback")
        let stillStandIn = session.image(for: a, proposed: "another fallback")
        let upgraded = session.image(for: a, proposed: "fresh menu glyph", isFinal: true)
        let held = session.image(for: a, proposed: "newer glyph", isFinal: true)
        #expect(initial == "gray fallback")
        #expect(stillStandIn == initial)
        #expect(upgraded == "fresh menu glyph")
        #expect(held == upgraded)
        session.reset()
        _ = session.stabilize(model([a]), context: "normal")
        #expect(session.image(for: a, proposed: "newer glyph", isFinal: true) == "newer glyph")
    }

    @Test func aTileKnownToBeGoneLeavesTheOpenPanel() {
        var session = PanelPresentationSession<String, String>()
        _ = session.stabilize(model([a, b]), context: "normal")
        session.forget([b])
        let later = session.stabilize(model([a, b]), context: "normal")
        #expect(later == model([a]))
    }

    @Test func disappearanceDoesNotShrinkTheOpenPanel() {
        var session = PanelPresentationSession<String, String>()
        _ = session.stabilize(model([a, b]), context: "normal")
        let duringCapture = session.stabilize(model([a]), context: "normal")
        #expect(duringCapture == model([a, b]))
    }

    @Test func deliberateSearchOrLayoutChangeGetsFreshContent() {
        var session = PanelPresentationSession<String, String>()
        _ = session.stabilize(model([a]), context: "normal")
        _ = session.image(for: a, proposed: "old")
        let search = session.stabilize(model([b]), context: "search:b")
        #expect(search == model([b]))
        let cleared = session.stabilize(model([a, b]), context: "normal")
        #expect(cleared == model([a, b]))
        let image = session.image(for: a, proposed: "new")
        #expect(image == "new")
    }

    @Test func draggingCanReorderAndTheNewOrderBecomesTheNextSnapshot() {
        var session = PanelPresentationSession<String, String>()
        _ = session.stabilize(model([a, b]), context: "normal")
        let editing = session.stabilize(model([b, a]), context: "normal", editing: true)
        let settled = session.stabilize(model([b, a]), context: "normal")
        #expect(editing == model([b, a]))
        #expect(settled == editing)
    }

    @Test func savedOrderStaysTheSameAcrossDifferentObservedMenuBarLayouts() {
        let launcher = ItemID.status(bundle: PelmetBundle.fallbackID, title: ExtraItemSpec(kind: .appLauncher).itemTitle)
        let first = ItemID.bundleKey("first"), second = ItemID.bundleKey("second")
        let saved = [first, second, launcher]
        let roster = Roster(members: Dictionary(uniqueKeysWithValues: saved.map { ($0, Section.hidden) }))
        let left = PanelModel.build(roster: roster, items: [launcher, first, second], drawnOrder: [.hidden: saved])
        let right = PanelModel.build(roster: roster, items: [first, second, launcher], drawnOrder: [.hidden: saved])
        #expect(left.section(.hidden)?.tiles == saved.map(PanelTile.item))
        #expect(right == left)
    }
}
