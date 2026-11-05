import Foundation
import Testing
@testable import NotchBoxCore

struct AdapterHealthMonitorTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    let interval = AdapterHealthMonitor.checkInterval
    let timeout = AdapterHealthMonitor.checkTimeout

    /// A monitor whose launch check has finished at t0 + 1.
    func checkedMonitor(passed: Bool) -> AdapterHealthMonitor {
        var monitor = AdapterHealthMonitor()
        _ = monitor.requestCheck(at: t0)
        monitor.checkFinished(passed: passed, at: at(1))
        return monitor
    }

    @Test func intervalIsThirtyMinutesAndTimeoutThirtySeconds() {
        #expect(AdapterHealthMonitor.checkInterval == 30 * 60)
        #expect(AdapterHealthMonitor.checkTimeout == 30)
    }

    @Test func startsHealthyWithNothingScheduled() {
        let monitor = AdapterHealthMonitor()
        #expect(!monitor.isFailing)
        #expect(!monitor.isChecking)
        #expect(monitor.nextDeadline == nil)
    }

    @Test func requestStartsACheck() {
        var monitor = AdapterHealthMonitor()
        #expect(monitor.requestCheck(at: t0) == .startCheck)
        #expect(monitor.isChecking)
        #expect(monitor.nextDeadline == at(timeout))
    }

    @Test func requestWhileCheckingIsIgnored() {
        var monitor = AdapterHealthMonitor()
        _ = monitor.requestCheck(at: t0)
        #expect(monitor.requestCheck(at: at(5)) == nil)
        #expect(monitor.nextDeadline == at(timeout))
    }

    @Test func passingCheckSchedulesTheNextOneAfterTheInterval() {
        let monitor = checkedMonitor(passed: true)
        #expect(!monitor.isFailing)
        #expect(!monitor.isChecking)
        #expect(monitor.nextDeadline == at(1 + interval))
    }

    @Test func failingCheckMarksFailingAndStillSchedulesTheNextOne() {
        let monitor = checkedMonitor(passed: false)
        #expect(monitor.isFailing)
        #expect(monitor.nextDeadline == at(1 + interval))
    }

    @Test func tickStartsTheScheduledCheckOnlyWhenDue() {
        var monitor = checkedMonitor(passed: true)
        #expect(monitor.tick(at: at(interval)) == nil)
        #expect(monitor.tick(at: at(1 + interval)) == .startCheck)
        #expect(monitor.isChecking)
    }

    @Test func tickWithinAMillisecondOfTheDeadlineStartsTheCheck() {
        var monitor = checkedMonitor(passed: true)
        #expect(monitor.tick(at: at(1 + interval - 0.0005)) == .startCheck)
    }

    @Test func requestBeforeTheIntervalChecksAtOnce() {
        var monitor = checkedMonitor(passed: true)
        #expect(monitor.requestCheck(at: at(60)) == .startCheck)
        #expect(monitor.nextDeadline == at(60 + timeout))
    }

    @Test func passingCheckClearsFailing() {
        var monitor = checkedMonitor(passed: false)
        _ = monitor.requestCheck(at: at(60))
        monitor.checkFinished(passed: true, at: at(61))
        #expect(!monitor.isFailing)
    }

    @Test func failingStaysUntilTheNextCheckWhileItRuns() {
        var monitor = checkedMonitor(passed: false)
        _ = monitor.requestCheck(at: at(60))
        #expect(monitor.isFailing)
    }

    @Test func checkThatTakesTooLongIsStoppedAndCountsAsFailed() {
        var monitor = AdapterHealthMonitor()
        _ = monitor.requestCheck(at: t0)
        #expect(monitor.tick(at: at(timeout - 1)) == nil)
        #expect(monitor.tick(at: at(timeout)) == .stopCheck)
        #expect(monitor.isFailing)
        #expect(!monitor.isChecking)
        #expect(monitor.nextDeadline == at(timeout + interval))
    }

    @Test func resultAfterATimeoutIsIgnored() {
        var monitor = AdapterHealthMonitor()
        _ = monitor.requestCheck(at: t0)
        _ = monitor.tick(at: at(timeout))
        monitor.checkFinished(passed: true, at: at(timeout + 1))
        #expect(monitor.isFailing)
        #expect(monitor.nextDeadline == at(timeout + interval))
    }

    @Test func trackInfoClearsFailing() {
        var monitor = checkedMonitor(passed: false)
        monitor.receivedTrackInfo()
        #expect(!monitor.isFailing)
        #expect(monitor.nextDeadline == at(1 + interval))
    }

    @Test func failingOverridesTheStreamStateWithUnavailable() {
        let failing = checkedMonitor(passed: false)
        #expect(failing.state(from: .nothing) == .unavailable)
        #expect(failing.state(from: .unavailable) == .unavailable)
        let healthy = checkedMonitor(passed: true)
        #expect(healthy.state(from: .nothing) == .nothing)
        #expect(healthy.state(from: .unavailable) == .unavailable)
    }

    @Test func cancelForgetsTheRunningCheckAndTheSchedule() {
        var monitor = checkedMonitor(passed: false)
        _ = monitor.requestCheck(at: at(60))
        monitor.cancel()
        #expect(!monitor.isChecking)
        #expect(monitor.nextDeadline == nil)
        #expect(monitor.isFailing)
        monitor.checkFinished(passed: true, at: at(61))
        #expect(monitor.isFailing)
    }
}
