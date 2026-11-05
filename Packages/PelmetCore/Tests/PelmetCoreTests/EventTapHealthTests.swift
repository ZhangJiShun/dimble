import Testing
@testable import PelmetCore

struct EventTapHealthTests {
    @Test func aMissingTapIsStartedByArmNotRebuilt() {
        #expect(!EventTapHealth.needsRebuild(tapExists: false, isValid: false))
        #expect(!EventTapHealth.needsRebuild(tapExists: false, isValid: true))
    }

    @Test func aValidTapIsTheIdleDisabledState() {
        #expect(!EventTapHealth.needsRebuild(tapExists: true, isValid: true))
    }

    @Test func anInvalidPortIsRebuilt() {
        #expect(EventTapHealth.needsRebuild(tapExists: true, isValid: false))
    }
}
