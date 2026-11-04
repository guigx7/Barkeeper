import AppKit

/// Moves menu bar items by synthesizing the system's ⌘-drag.
///
/// A move session: cover the bar with a still image, reveal every section (dividers shrink to a
/// small visible chevron so they can be used as drop targets), hide the cursor, drag each item,
/// verify its new position from the WindowServer, retry if needed, then restore everything.
@MainActor
final class Mover {
    enum Destination: CustomStringConvertible {
        case leftOf(CGWindowID)
        case rightOf(CGWindowID)

        var target: CGWindowID {
            switch self {
            case .leftOf(let id), .rightOf(let id): id
            }
        }

        var description: String {
            switch self {
            case .leftOf(let id): "left of \(id)"
            case .rightOf(let id): "right of \(id)"
            }
        }
    }

    struct Move {
        let item: MenuBarItem
        let destination: Destination
    }

    enum MoveError: Error, CustomStringConvertible {
        case busy, windowGone, offScreen, timedOut

        var description: String {
            switch self {
            case .busy: "another move is in progress"
            case .windowGone: "item window disappeared"
            case .offScreen: "item is off screen even with every section revealed"
            case .timedOut: "item did not reach its destination"
            }
        }
    }

    private let hider: Hider
    private let cover = CoverWindow()
    private(set) var isMoving = false

    static let maxAttempts = 3
    static let settleTimeout: Duration = .milliseconds(600)

    init(hider: Hider) {
        self.hider = hider
    }

    /// Runs the moves in order inside one session. Returns the error for each failed move.
    @discardableResult
    func perform(_ moves: [Move], on display: DisplayInfo) async -> [(Move, MoveError)] {
        guard !isMoving else { return moves.map { ($0, .busy) } }
        guard !moves.isEmpty else { return [] }
        isMoving = true
        defer { isMoving = false }

        let started = ContinuousClock.now
        let savedCursor = EventSynth.cursorLocation
        let savedState = hider.state
        cover.show(on: display)
        hider.revealForMove()
        EventSynth.hideCursor()
        try? await Task.sleep(for: .milliseconds(120))

        var failures: [(Move, MoveError)] = []
        for move in moves {
            do {
                try await perform(move, display: display)
            } catch let error as MoveError {
                Log.menuBar.error("Move \(move.item.identity.description, privacy: .public) \(move.destination.description, privacy: .public) failed: \(error.description, privacy: .public)")
                failures.append((move, error))
            } catch {}
        }

        EventSynth.warpCursor(to: savedCursor)
        EventSynth.showCursor()
        hider.restoreAfterMove(savedState)
        try? await Task.sleep(for: .milliseconds(150))
        cover.close()
        Log.menuBar.info("Move session: \(moves.count - failures.count)/\(moves.count) ok in \(started.duration(to: .now), privacy: .public)")
        return failures
    }

    private func perform(_ move: Move, display: DisplayInfo) async throws {
        for attempt in 1...Self.maxAttempts {
            guard let (item, target) = frames(move) else { throw MoveError.windowGone }
            if satisfied(item: item, target: target, move.destination) { return }
            guard item.maxX > display.bounds.minX, target.maxX > display.bounds.minX else { throw MoveError.offScreen }

            let start = CGPoint(x: item.midX, y: item.midY)
            let end = switch move.destination {
            case .leftOf: CGPoint(x: target.minX, y: target.midY)
            case .rightOf: CGPoint(x: target.maxX, y: target.midY)
            }
            Log.menuBar.info("Move \(move.item.identity.description, privacy: .public) \(move.destination.description, privacy: .public) attempt \(attempt): \(Int(start.x)) → \(Int(end.x))")
            await EventSynth.commandDrag(from: start, to: end)

            let deadline = ContinuousClock.now + Self.settleTimeout
            while ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(30))
                guard let (item, target) = frames(move) else { throw MoveError.windowGone }
                if satisfied(item: item, target: target, move.destination) { return }
            }
        }
        throw MoveError.timedOut
    }

    private func frames(_ move: Move) -> (CGRect, CGRect)? {
        let infos = WindowServer.windows(ids: [move.item.windowID, move.destination.target])
        guard let item = infos.first(where: { $0.windowID == move.item.windowID })?.frame,
              let target = infos.first(where: { $0.windowID == move.destination.target })?.frame else { return nil }
        return (item, target)
    }

    private func satisfied(item: CGRect, target: CGRect, _ destination: Destination) -> Bool {
        switch destination {
        case .leftOf: abs(item.maxX - target.minX) < 2
        case .rightOf: abs(item.minX - target.maxX) < 2
        }
    }
}
