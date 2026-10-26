// CompanionMute.swift
// The "item-only change, leave the extras alone" flag as a count. Several
// item-only operations can be inside `converge()` at once (it suspends), and
// a bare Bool let the first to finish switch the mute off under the others.

struct CompanionMute: Equatable, Sendable {
    private(set) var depth = 0

    var isMuted: Bool { depth > 0 }

    mutating func enter() { depth += 1 }

    mutating func leave() { depth = max(0, depth - 1) }
}
