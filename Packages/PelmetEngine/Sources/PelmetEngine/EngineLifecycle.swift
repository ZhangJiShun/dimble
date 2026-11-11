// EngineLifecycle.swift
// Pure gate for the engine's start/stop window: engine-side `started`/`stopped`
// decide whether a late `setModel` (or any converge) may still run.

enum EngineLifecycle {
    /// Engine-side: `start()` sets started; `stop()` sets stopped and leaves
    /// started true so a second start is a no-op. Work only while started && !stopped.
    static func engineAcceptsWork(started: Bool, stopped: Bool) -> Bool {
        started && !stopped
    }
}
