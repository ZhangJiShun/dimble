import Testing
@testable import PelmetEngine

@Suite struct EngineLifecycleTests {
    @Test func engineRejectsWorkBeforeStart() {
        #expect(!EngineLifecycle.engineAcceptsWork(started: false, stopped: false))
    }

    @Test func engineAcceptsWorkWhileRunning() {
        #expect(EngineLifecycle.engineAcceptsWork(started: true, stopped: false))
    }

    @Test func engineRejectsWorkAfterStopWhileStartedStaysTrue() {
        #expect(!EngineLifecycle.engineAcceptsWork(started: true, stopped: true))
    }

    @Test func engineRejectsWorkWhenStoppedWithoutHavingStarted() {
        #expect(!EngineLifecycle.engineAcceptsWork(started: false, stopped: true))
    }
}
