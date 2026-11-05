import Testing
@testable import PelmetEngine

@Suite struct EngineLifecycleTests {
    @Test func appRejectsSetModelWhenEngineHasNotStarted() {
        #expect(!EngineLifecycle.appAcceptsSetModel(engineStarted: false))
    }

    @Test func appAcceptsSetModelOnceEngineHasStarted() {
        #expect(EngineLifecycle.appAcceptsSetModel(engineStarted: true))
    }

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

    @Test func bootMustNotMarkStartedOnceQuitHasBegun() {
        #expect(EngineLifecycle.appMayMarkStarted(terminating: false))
        #expect(!EngineLifecycle.appMayMarkStarted(terminating: true))
    }
}
