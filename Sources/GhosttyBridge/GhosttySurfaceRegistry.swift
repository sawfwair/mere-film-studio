import Foundation
import GhosttyKit
import SwiftUI

@MainActor
final class GhosttySurfaceRegistry {
    static let shared = GhosttySurfaceRegistry()

    private final class Entry {
        weak var view: GhosttySurfaceView?

        init(_ view: GhosttySurfaceView) {
            self.view = view
        }
    }

    private var entries: [UInt: Entry] = [:]

    func register(_ view: GhosttySurfaceView) {
        // Sweep entries whose views have deallocated so restarts don't
        // accumulate dead slots for the life of the app.
        entries = entries.filter { $0.value.view != nil }
        entries[UInt(bitPattern: Unmanaged.passUnretained(view).toOpaque())] = Entry(view)
    }

    func liveView(address: UInt) -> GhosttySurfaceView? {
        entries[address]?.view
    }
}
