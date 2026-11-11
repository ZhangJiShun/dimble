// PointerMoveTap.swift
// The band monitor's pointer feed, off AppKit. A global NSEvent monitor
// hands EVERY mouse move to the main thread as an NSEvent — event record,
// object, run-loop pass — before the monitor can see the pointer is nowhere
// near the bar, which is nearly always (perf audit 2026-10-02: ~6 context
// switches and 0.24ms a move with the geometry already cached, ~2.5% CPU
// under a moving mouse). A listen-only CG tap on its own thread reads the
// location straight off the event, keeps the main thread out of it while
// the pointer is off the bar, and wakes it only for a move that is in the
// band, leaves it, or crosses to another display — the three things the
// band monitor acts on. Those moves run the same `pointerMoved` as before.
//
// A tap needs Accessibility (Pelmet's one hard requirement); should it
// still fail, the monitor falls back to the NSEvent monitors.

import AppKit

nonisolated final class PointerMoveTap: @unchecked Sendable {
    /// A display as the tap sees it: CG global bounds (top-left origin) and
    /// the y below which the pointer is in the menu bar band.
    struct Display {
        let bounds: CGRect
        let bandMaxY: CGFloat
    }

    private let lock = NSLock()
    private var displays: [Display] = []
    private var lastDisplay: Int?
    private var lastInBand = false
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private let onInterest: @MainActor () -> Void

    init(onInterest: @escaping @MainActor () -> Void) {
        self.onInterest = onInterest
    }

    /// The band monitor's screen geometry, pushed on every rebuild. The
    /// next move after an update always reaches the main thread (the
    /// display index is reset), so a crossing is never lost to a reshuffle.
    func update(displays: [Display]) {
        lock.withLock {
            self.displays = displays
            lastDisplay = nil
        }
    }

    /// False when the tap could not be created.
    func start() -> Bool {
        let mask = CGEventMask(1) << CGEventType.mouseMoved.rawValue
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<PointerMoveTap>.fromOpaque(userInfo).takeUnretainedValue()
                return tap.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else { return false }
        lock.withLock { self.tap = tap }
        // The thread owns this one tap; CFMachPort is not Sendable.
        nonisolated(unsafe) let owned = tap
        let thread = Thread { [weak self] in
            guard let self else { return }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, owned, 0)
            let runLoop = CFRunLoopGetCurrent()
            // Publish and attach under the lock, so a `stop()` that already
            // ran leaves nothing running.
            let alive: Bool = self.lock.withLock {
                guard self.tap === owned else { return false }
                tapSource = source
                tapRunLoop = runLoop
                CFRunLoopAddSource(runLoop, source, .commonModes)
                return true
            }
            guard alive else { return }
            CGEvent.tapEnable(tap: owned, enable: true)
            CFRunLoopRun()
        }
        thread.qualityOfService = .userInteractive
        thread.name = "pelmet.pointer-tap"
        thread.start()
        return true
    }

    /// A tap the system dropped (Accessibility revoked and granted again,
    /// a silent invalidation) stays a non-nil object that hears nothing.
    /// Rebuild it when it is no longer valid and enabled.
    func reviveIfDead() {
        guard let tap = currentTap, !CFMachPortIsValid(tap) || !CGEvent.tapIsEnabled(tap: tap) else { return }
        stop()
        _ = start()
    }

    private var currentTap: CFMachPort? { lock.withLock { tap } }

    func stop() {
        // Handles taken and cleared under the lock: a thread that has not
        // reached its run loop yet finds the tap gone and never starts.
        let (tap, source, runLoop) = lock.withLock {
            defer { self.tap = nil; tapSource = nil; tapRunLoop = nil }
            return (self.tap, tapSource, tapRunLoop)
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoop, let source {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopStop(runLoop)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = currentTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let point = event.location
        let interesting: Bool = lock.withLock {
            let display = displays.firstIndex { $0.bounds.contains(point) }
            let inBand = display.map { point.y < displays[$0].bandMaxY } ?? false
            let crossed = display != lastDisplay
            let wasInBand = lastInBand
            lastDisplay = display
            lastInBand = inBand
            return crossed || inBand || wasInBand
        }
        if interesting {
            let onInterest = onInterest
            DispatchQueue.main.async { MainActor.assumeIsolated { onInterest() } }
        }
        return Unmanaged.passUnretained(event)
    }
}
