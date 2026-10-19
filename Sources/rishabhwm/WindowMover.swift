import Foundation
import os
import RishabhWMCore

/// Runs Accessibility window moves off the main thread.
///
/// Every AX call is a blocking round trip to the window's app. Each app gets its own serial queue,
/// so apps move their windows in parallel, a slow or hung app never delays the others (or the next
/// hotkey), and one window's moves still happen in order. If a newer move for a window is queued
/// before an older one runs, the older one is dropped: rapid workspace switching only applies the
/// latest layout.
final class WindowMover {
    private var queues: [pid_t: DispatchQueue] = [:]
    /// Newest ticket per window; read from the app queues, written from the main thread.
    private let latest = OSAllocatedUnfairLock(initialState: [WindowID: UInt64]())
    private var nextTicket: UInt64 = 0

    /// Queues `work` for `window`, superseding any of its moves that haven't run yet.
    func move(_ window: TrackedWindow, _ work: @escaping () -> Void) {
        nextTicket += 1
        let ticket = nextTicket
        let id = window.id
        latest.withLock { $0[id] = ticket }
        queue(for: window.pid).async { [latest] in
            guard latest.withLock({ $0[id] == ticket }) else { return }
            work()
        }
    }

    /// Queues `work` after every move already queued for `pid`. Never dropped.
    func after(_ pid: pid_t, _ work: @escaping () -> Void) {
        queue(for: pid).async(execute: work)
    }

    /// Drops the window's pending moves (it closed or left the home desktop).
    func cancel(_ id: WindowID) {
        latest.withLock { $0[id] = nil }
    }

    func removeApp(_ pid: pid_t) {
        queues[pid] = nil
    }

    /// Blocks until every queued move has run. Used before quitting.
    func drain() {
        queues.values.forEach { $0.sync {} }
    }

    private func queue(for pid: pid_t) -> DispatchQueue {
        if let queue = queues[pid] { return queue }
        let queue = DispatchQueue(label: "rishabhwm.ax.\(pid)", qos: .userInteractive)
        queues[pid] = queue
        return queue
    }
}
