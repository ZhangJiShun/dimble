import CoreGraphics
import Testing
@testable import PelmetCore

struct HoverRevealTests {
    private let band = CGRect(x: 0, y: 960, width: 1600, height: 40)

    @Test func iconTargetIncludesPaddingButNotTheEmptyStrip() throws {
        let button = CGRect(x: 1000, y: 960, width: 32, height: 40)
        let target = try #require(HoverRevealGeometry.iconTarget(button: button, sourceBand: band, targetBand: band))
        #expect(target.contains(CGPoint(x: 1001, y: 980)))
        #expect(!target.contains(CGPoint(x: 999, y: 980)))
        #expect(!target.contains(CGPoint(x: 1033, y: 980)))
    }

    @Test func targetFollowsButtonReflowAndOtherDisplayOrigins() throws {
        let secondary = CGRect(x: -1920, y: 600, width: 1920, height: 30)
        let button = CGRect(x: 1000, y: 960, width: 32, height: 40)
        let target = try #require(HoverRevealGeometry.iconTarget(button: button, sourceBand: band, targetBand: secondary))
        #expect(target == CGRect(x: -600, y: 600, width: 32, height: 30))
        let moved = try #require(HoverRevealGeometry.iconTarget(
            button: button.offsetBy(dx: -80, dy: 0), sourceBand: band, targetBand: band))
        #expect(!moved.contains(CGPoint(x: 1010, y: 980)))
        #expect(moved.contains(CGPoint(x: 930, y: 980)))
    }

    @Test func undrawnOrOverflowedIconHasNoTarget() {
        #expect(HoverRevealGeometry.iconTarget(button: nil, sourceBand: band, targetBand: band) == nil)
        #expect(HoverRevealGeometry.iconTarget(button: CGRect(x: 4800, y: 960, width: 32, height: 40),
                                             sourceBand: band, targetBand: band) == nil)
        #expect(HoverRevealGeometry.iconTarget(button: CGRect(x: 1000, y: 500, width: 32, height: 40),
                                             sourceBand: band, targetBand: band) == nil)
        #expect(HoverRevealGeometry.iconTarget(button: CGRect(x: 1000, y: 960, width: 32, height: 40),
                                             sourceBand: band, targetBand: .zero) == nil)
    }

    @Test func leavingAndReenteringCancelsThePreviousDwell() throws {
        var hover = HoverDwellState()
        let entered = hover.update(inTarget: true, inBand: true, scope: .iconOnly)
        #expect(entered)
        let firstTicket = hover.arm()
        let first = try #require(firstTicket)
        #expect(hover.allowsReveal(first))
        let left = hover.update(inTarget: false, inBand: true, scope: .iconOnly)
        #expect(!left)
        #expect(!hover.allowsReveal(first))
        let reentered = hover.update(inTarget: true, inBand: true, scope: .iconOnly)
        #expect(reentered)
        let secondTicket = hover.arm()
        let second = try #require(secondTicket)
        #expect(!hover.allowsReveal(first))
        #expect(hover.allowsReveal(second))
    }

    @Test func clickToCloseWaitsForIconExitInsteadOfFullBandExit() throws {
        var hover = HoverDwellState()
        _ = hover.update(inTarget: true, inBand: true, scope: .iconOnly)
        let armed = hover.arm()
        let token = try #require(armed)
        hover.suppress(inBand: true)
        #expect(!hover.allowsReveal(token))
        let suppressed = hover.arm()
        #expect(suppressed == nil)
        _ = hover.update(inTarget: false, inBand: true, scope: .iconOnly)
        _ = hover.update(inTarget: true, inBand: true, scope: .iconOnly)
        let rearmed = hover.arm()
        #expect(rearmed != nil)
    }

    @Test func broadModeKeepsItsExistingSuppressionUntilBandExit() {
        var hover = HoverDwellState()
        _ = hover.update(inTarget: true, inBand: true, scope: .menuBarArea)
        hover.suppress(inBand: true)
        _ = hover.update(inTarget: false, inBand: true, scope: .menuBarArea)
        _ = hover.update(inTarget: true, inBand: true, scope: .menuBarArea)
        let suppressed = hover.arm()
        #expect(suppressed == nil)
        _ = hover.update(inTarget: false, inBand: false, scope: .menuBarArea)
        _ = hover.update(inTarget: true, inBand: true, scope: .menuBarArea)
        let rearmed = hover.arm()
        #expect(rearmed != nil)
    }

    @Test func settingsOrDisplayChangeInvalidatesQueuedDwell() throws {
        var hover = HoverDwellState()
        _ = hover.update(inTarget: true, inBand: true, scope: .iconOnly)
        let armed = hover.arm()
        let token = try #require(armed)
        hover.resetTarget()
        #expect(!hover.allowsReveal(token))
        let cancelled = hover.arm()
        #expect(cancelled == nil)
        hover.suppress(inBand: false)
        _ = hover.update(inTarget: true, inBand: true, scope: .iconOnly)
        let rearmed = hover.arm()
        #expect(rearmed != nil)
    }
}
