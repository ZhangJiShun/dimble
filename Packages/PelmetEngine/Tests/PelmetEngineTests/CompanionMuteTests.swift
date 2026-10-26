import Testing
@testable import PelmetEngine

@Suite struct CompanionMuteTests {
    @Test func startsUnmuted() {
        #expect(!CompanionMute().isMuted)
    }

    @Test func oneOperationMutesForItsDuration() {
        var mute = CompanionMute()
        mute.enter()
        #expect(mute.isMuted)
        mute.leave()
        #expect(!mute.isMuted)
    }

    // A press and a show rule both inside converge: the one that finishes
    // first must not unmute the one still going.
    @Test func overlappingOperationsStayMutedUntilTheLastLeaves() {
        var mute = CompanionMute()
        mute.enter()   // reveal(items:)
        mute.enter()   // setRuleShown
        mute.leave()   // the reveal finishes first
        #expect(mute.isMuted)
        mute.leave()
        #expect(!mute.isMuted)
    }

    @Test func anExtraLeaveNeverGoesNegative() {
        var mute = CompanionMute()
        mute.leave()
        mute.enter()
        #expect(mute.isMuted)
        mute.leave()
        #expect(!mute.isMuted)
    }
}
