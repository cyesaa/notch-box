import Foundation
import Testing
@testable import NotchBoxCore

struct NotchStateMachineTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// A machine that is open (hovered past the open delay) with the given media.
    func openMachine(media: NotchStateMachine.Media) -> NotchStateMachine {
        var machine = NotchStateMachine()
        machine.setMedia(media, at: t0)
        machine.setHovering(true, at: t0)
        machine.tick(at: at(0.1))
        return machine
    }

    @Test func startsIdle() {
        let machine = NotchStateMachine()
        #expect(machine.displayState == .idle)
        #expect(machine.nextDeadline == nil)
    }

    @Test func playingShowsMini() {
        var machine = NotchStateMachine()
        machine.setMedia(.playing, at: t0)
        #expect(machine.displayState == .mini)
    }

    @Test func hoverOpensAfterDelayWhenNothingPlaying() {
        var machine = NotchStateMachine()
        machine.setHovering(true, at: t0)
        #expect(machine.displayState == .idle)
        #expect(machine.nextDeadline == at(0.1))
        machine.tick(at: at(0.05))
        #expect(machine.displayState == .idle)
        machine.tick(at: at(0.1))
        #expect(machine.displayState == .expandedEmpty)
    }

    @Test func hoverOpensFullPlayerWhenPlaying() {
        let machine = openMachine(media: .playing)
        #expect(machine.displayState == .expanded)
    }

    @Test func shortHoverDoesNotOpen() {
        var machine = NotchStateMachine()
        machine.setHovering(true, at: t0)
        machine.setHovering(false, at: at(0.05))
        #expect(machine.nextDeadline == nil)
        machine.tick(at: at(0.2))
        #expect(machine.displayState == .idle)
    }

    @Test func closesAfterDelayWhenHoverEnds() {
        var machine = openMachine(media: .playing)
        machine.setHovering(false, at: at(1))
        #expect(machine.displayState == .expanded)
        #expect(machine.nextDeadline == at(1.3))
        machine.tick(at: at(1.2))
        #expect(machine.displayState == .expanded)
        machine.tick(at: at(1.3))
        #expect(machine.displayState == .mini)
    }

    @Test func returningWithinCloseDelayKeepsItOpen() {
        var machine = openMachine(media: .playing)
        machine.setHovering(false, at: at(1))
        machine.setHovering(true, at: at(1.2))
        machine.tick(at: at(1.5))
        #expect(machine.displayState == .expanded)
        #expect(machine.nextDeadline == nil)
    }

    @Test func mediaStoppingWhileOpenSwitchesToEmpty() {
        var machine = openMachine(media: .playing)
        machine.setMedia(.nothing, at: at(2))
        #expect(machine.displayState == .expandedEmpty)
    }

    @Test func pausedMiniTimesOutAfterFiveMinutes() {
        var machine = NotchStateMachine()
        machine.setMedia(.playing, at: t0)
        machine.setMedia(.paused, at: at(10))
        #expect(machine.displayState == .mini)
        #expect(machine.nextDeadline == at(310))
        machine.tick(at: at(309))
        #expect(machine.displayState == .mini)
        machine.tick(at: at(310))
        #expect(machine.displayState == .idle)
        #expect(machine.nextDeadline == nil)
    }

    @Test func repeatedPausedUpdatesKeepTheOriginalPauseTime() {
        var machine = NotchStateMachine()
        machine.setMedia(.paused, at: t0)
        machine.setMedia(.paused, at: at(200))
        machine.tick(at: at(300))
        #expect(machine.displayState == .idle)
    }

    @Test func hoverAfterPauseTimeoutStillShowsPlayer() {
        var machine = NotchStateMachine()
        machine.setMedia(.paused, at: t0)
        machine.tick(at: at(300))
        machine.setHovering(true, at: at(400))
        machine.tick(at: at(400.1))
        #expect(machine.displayState == .expanded)
    }

    @Test func resumingAfterTimeoutShowsMiniAgain() {
        var machine = NotchStateMachine()
        machine.setMedia(.paused, at: t0)
        machine.tick(at: at(300))
        machine.setMedia(.playing, at: at(500))
        #expect(machine.displayState == .mini)
    }

    @Test func unavailableHidesMiniButOpensPlayer() {
        var machine = NotchStateMachine()
        machine.setMedia(.unavailable, at: t0)
        #expect(machine.displayState == .idle)
        machine.setHovering(true, at: t0)
        machine.tick(at: at(0.1))
        #expect(machine.displayState == .expanded)
    }
}
