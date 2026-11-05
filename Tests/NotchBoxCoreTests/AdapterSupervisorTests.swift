import Foundation
import Testing
@testable import NotchBoxCore

struct AdapterSupervisorTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func longRunsBackOffWithIncreasingDelays() {
        var supervisor = AdapterSupervisor()
        var delays: [TimeInterval] = []
        var now = t0
        for _ in 0..<6 {
            supervisor.processStarted(at: now)
            now += 10
            delays.append(supervisor.processExited(at: now))
        }
        #expect(delays == [1, 2, 5, 10, 30, 30])
        #expect(!supervisor.isDegraded)
    }

    @Test func threeQuickExitsEnterDegradedMode() {
        var supervisor = AdapterSupervisor()
        supervisor.processStarted(at: t0)
        #expect(supervisor.processExited(at: at(1)) == 1)
        supervisor.processStarted(at: at(2))
        #expect(supervisor.processExited(at: at(3)) == 2)
        #expect(!supervisor.isDegraded)
        supervisor.processStarted(at: at(5))
        #expect(supervisor.processExited(at: at(6)) == 60)
        #expect(supervisor.isDegraded)
    }

    @Test func longRunBreaksTheQuickExitStreak() {
        var supervisor = AdapterSupervisor()
        supervisor.processStarted(at: t0)
        _ = supervisor.processExited(at: at(1))
        supervisor.processStarted(at: at(2))
        _ = supervisor.processExited(at: at(3))
        supervisor.processStarted(at: at(10))
        _ = supervisor.processExited(at: at(30))
        supervisor.processStarted(at: at(40))
        _ = supervisor.processExited(at: at(41))
        #expect(!supervisor.isDegraded)
    }

    @Test func launchFailuresWithoutStartCountAsQuickExits() {
        var supervisor = AdapterSupervisor()
        _ = supervisor.processExited(at: t0)
        _ = supervisor.processExited(at: at(1))
        _ = supervisor.processExited(at: at(2))
        #expect(supervisor.isDegraded)
    }

    @Test func outputResetsDegradedModeAndDelays() {
        var supervisor = AdapterSupervisor()
        for i in 0..<3 {
            supervisor.processStarted(at: at(Double(i)))
            _ = supervisor.processExited(at: at(Double(i) + 0.5))
        }
        #expect(supervisor.isDegraded)
        supervisor.processStarted(at: at(100))
        supervisor.receivedOutput()
        #expect(!supervisor.isDegraded)
        #expect(supervisor.processExited(at: at(200)) == 1)
    }

    @Test func quickExitsKeepCountingAfterOutput() {
        var supervisor = AdapterSupervisor()
        var delays: [TimeInterval] = []
        for i in 0..<3 {
            let start = at(Double(i) * 10)
            supervisor.processStarted(at: start)
            supervisor.receivedOutput()
            delays.append(supervisor.processExited(at: start.addingTimeInterval(1)))
        }
        // Output resets the backoff, so the first two restarts wait 1 s; the third quick exit degrades.
        #expect(delays == [1, 1, 60])
        #expect(supervisor.isDegraded)
    }
}
