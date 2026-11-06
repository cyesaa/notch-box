import Foundation
import Testing
@testable import NotchBoxCore

struct AudioSpectrumTests {
    let rate = 48_000.0

    func sine(_ frequency: Double, amplitude: Float = 0.5, count: Int = 1024) -> [Float] {
        (0..<count).map { amplitude * Float(sin(2 * .pi * frequency * Double($0) / rate)) }
    }

    @Test func silenceGivesZeroLevels() {
        let levels = AudioSpectrum.bandLevels(samples: Array(repeating: 0, count: 1024), sampleRate: rate, bandCount: 5)
        #expect(levels == Array(repeating: 0, count: 5))
    }

    @Test func tooFewSamplesGiveZeroLevels() {
        #expect(AudioSpectrum.bandLevels(samples: sine(100, count: 100), sampleRate: rate, bandCount: 4) == [0, 0, 0, 0])
    }

    @Test func bassToneLightsTheFirstBand() {
        let levels = AudioSpectrum.bandLevels(samples: sine(100), sampleRate: rate, bandCount: 5)
        #expect(levels.count == 5)
        #expect(levels[0] > 0.7)
        #expect(levels[4] < 0.2)
    }

    @Test func trebleToneLightsTheLastBand() {
        let levels = AudioSpectrum.bandLevels(samples: sine(8_000), sampleRate: rate, bandCount: 5)
        #expect(levels.max() == levels[4])
        #expect(levels[0] < 0.2)
    }

    @Test func quieterSoundGivesLowerLevels() {
        let loud = AudioSpectrum.bandLevels(samples: sine(1_000, amplitude: 0.5), sampleRate: rate, bandCount: 5)
        let quiet = AudioSpectrum.bandLevels(samples: sine(1_000, amplitude: 0.005), sampleRate: rate, bandCount: 5)
        let band = loud.indices.max { loud[$0] < loud[$1] }!
        #expect(quiet[band] < loud[band])
    }

    @Test func levelsStayWithinZeroAndOne() {
        let levels = AudioSpectrum.bandLevels(samples: sine(300, amplitude: 1), sampleRate: rate, bandCount: 5)
        #expect(levels.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}

struct AudioLevelMeterStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    let sound: [Float] = (0..<1024).map { 0.5 * Float(sin(2 * .pi * 200 * Double($0) / 48_000)) }
    let silence = [Float](repeating: 0, count: 1024)

    @Test func startsSilentAndNotLive() {
        let meter = AudioLevelMeterState(bandCount: 5)
        #expect(!meter.isLive)
        #expect(meter.levels == Array(repeating: 0, count: 5))
    }

    @Test func soundMakesItLiveAndRaisesLevelsAtOnce() {
        var meter = AudioLevelMeterState(bandCount: 5)
        meter.update(samples: sound, sampleRate: 48_000, at: t0)
        #expect(meter.isLive)
        #expect(meter.levels.max()! > 0.5)
    }

    @Test func levelsFallGraduallyAfterTheSoundStops() {
        var meter = AudioLevelMeterState(bandCount: 5)
        meter.update(samples: sound, sampleRate: 48_000, at: t0)
        let peak = meter.levels.max()!
        meter.update(samples: silence, sampleRate: 48_000, at: at(0.1))
        let after = meter.levels.max()!
        #expect(after < peak)
        #expect(after > 0)
        #expect(meter.isLive)
    }

    @Test func silencePastTheTimeoutIsNotLive() {
        var meter = AudioLevelMeterState(bandCount: 5)
        meter.update(samples: sound, sampleRate: 48_000, at: t0)
        meter.update(samples: silence, sampleRate: 48_000, at: at(AudioLevelMeterState.silenceTimeout))
        #expect(!meter.isLive)
    }

    @Test func onlySilenceNeverGoesLive() {
        // What a denied "System Audio Recording" permission looks like: the tap delivers zeros.
        var meter = AudioLevelMeterState(bandCount: 5)
        for step in 0..<10 {
            meter.update(samples: silence, sampleRate: 48_000, at: at(Double(step)))
        }
        #expect(!meter.isLive)
    }

    @Test func resetClearsLevelsAndLiveness() {
        var meter = AudioLevelMeterState(bandCount: 5)
        meter.update(samples: sound, sampleRate: 48_000, at: t0)
        meter.reset()
        #expect(!meter.isLive)
        #expect(meter.levels == Array(repeating: 0, count: 5))
    }
}

struct SampleRingTests {
    @Test func keepsTheLatestSamplesInOrder() {
        var ring = SampleRing(capacity: 4)
        ring.append([1, 2, 3])
        #expect(ring.latest == [1, 2, 3])
        ring.append([4, 5, 6])
        #expect(ring.latest == [3, 4, 5, 6])
    }

    @Test func oversizedAppendKeepsItsTail() {
        var ring = SampleRing(capacity: 3)
        ring.append([1, 2, 3, 4, 5])
        #expect(ring.latest == [3, 4, 5])
    }

    @Test func clearEmptiesIt() {
        var ring = SampleRing(capacity: 3)
        ring.append([1, 2])
        ring.clear()
        #expect(ring.latest == [])
    }
}

struct AudioMixdownTests {
    @Test func interleavedStereoIsAveraged() {
        #expect(AudioMixdown.mono(interleaved: [1, 3, -1, 1], channels: 2) == [2, 0])
    }

    @Test func monoInterleavedIsUnchanged() {
        #expect(AudioMixdown.mono(interleaved: [0.5, -0.5], channels: 1) == [0.5, -0.5])
    }

    @Test func planarChannelsAreAveraged() {
        #expect(AudioMixdown.mono(planar: [[1, 2], [3, 4]]) == [2, 3])
    }
}
