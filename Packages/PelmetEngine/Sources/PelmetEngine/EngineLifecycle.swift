// EngineLifecycle.swift
// Pure gates for the engine's start/stop window. App-side `engineStarted`
// and engine-side `started`/`stopped` decide whether a late `setModel`
// (or any converge) may still run.

enum EngineLifecycle {
    /// App-side: `engineStarted` is the gate. False before boot and after
    /// `beginTermination`. Late Tasks must not call `setModel`.
    static func appAcceptsSetModel(engineStarted: Bool) -> Bool { engineStarted }

    /// Boot must not raise `engineStarted` once quit has begun: `stop()` can
    /// land in the middle of `bootEngine`'s awaits, and the next line would
    /// otherwise mark the engine running again.
    static func appMayMarkStarted(terminating: Bool) -> Bool { !terminating }

    /// Engine-side: `start()` sets started; `stop()` sets stopped and leaves
    /// started true so a second start is a no-op. Work only while started && !stopped.
    static func engineAcceptsWork(started: Bool, stopped: Bool) -> Bool {
        started && !stopped
    }
}
