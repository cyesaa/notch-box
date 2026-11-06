import Accelerate
import Foundation

/// Turns a window of mono samples into bar heights: FFT, log-spaced bands from bass to treble,
/// decibels mapped to 0...1. Higher bands get a small boost, since music has less energy there.
public enum AudioSpectrum {
    public static let lowestFrequency = 60.0
    public static let highestFrequency = 14_000.0
    /// Band peaks at or below `floorDecibels` show as empty bars, at or above `ceilingDecibels` as full.
    public static let floorDecibels = -65.0
    public static let ceilingDecibels = -10.0
    public static let tiltPerBand = 4.0
    public static let minimumSamples = 256
    /// Larger frames are cut to their newest 2^maximumLog2n samples.
    public static let maximumLog2n = 12

    /// One setup serves every transform up to 2^maximumLog2n points; creating it is the costly part.
    private static let fftSetup = vDSP_create_fftsetup(vDSP_Length(maximumLog2n), FFTRadix(kFFTRadix2))

    /// Uses the newest power-of-two number of samples (at least `minimumSamples`).
    public static func bandLevels(samples: [Float], sampleRate: Double, bandCount: Int) -> [Double] {
        let silent = Array(repeating: 0.0, count: max(0, bandCount))
        guard bandCount > 0, samples.count >= minimumSamples, sampleRate > 0 else { return silent }
        let log2n = min(maximumLog2n, Int(log2(Double(samples.count))))
        let n = 1 << log2n
        let amplitudes = spectrum(Array(samples.suffix(n)), log2n: log2n)
        let binWidth = sampleRate / Double(n)
        let top = min(highestFrequency, sampleRate / 2)
        let ratio = top / lowestFrequency
        return (0..<bandCount).map { band in
            let low = lowestFrequency * pow(ratio, Double(band) / Double(bandCount))
            let high = lowestFrequency * pow(ratio, Double(band + 1) / Double(bandCount))
            let first = max(1, Int(low / binWidth))
            let last = min(amplitudes.count - 1, max(first, Int((high / binWidth).rounded(.up))))
            guard first <= last else { return 0 }
            let peak = amplitudes[first...last].max() ?? 0
            guard peak > 0 else { return 0 }
            let decibels = 20 * log10(Double(peak)) + tiltPerBand * Double(band)
            return min(1, max(0, (decibels - floorDecibels) / (ceilingDecibels - floorDecibels)))
        }
    }

    /// Amplitude per frequency bin (bin k is k × sampleRate / n), for a Hann-windowed frame of 2^log2n samples.
    private static func spectrum(_ frame: [Float], log2n: Int) -> [Float] {
        let n = frame.count
        let half = n / 2
        guard let setup = fftSetup else { return Array(repeating: 0, count: half) }
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_DENORM))
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(n))
        var real = [Float](repeating: 0, count: half)
        var imaginary = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { samples in
                    samples.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }
        // vDSP's real FFT is scaled by 2 and the Hann window halves a tone's peak: × 2 / n gives amplitude.
        let scale = 2 / Float(n)
        return magnitudes.map { $0 * scale }
    }
}

/// Bar heights over time: they jump up with the music and fall back smoothly.
/// `isLive` is false until non-silent audio arrives and again after `silenceTimeout` of digital
/// silence, which is also what a denied audio capture permission looks like.
/// Pure value type: the caller passes the current time.
public struct AudioLevelMeterState: Sendable {
    public static let silenceTimeout: TimeInterval = 1.5
    /// How fast a bar falls, in full heights per second.
    public static let releasePerSecond = 2.5

    public let bandCount: Int
    public private(set) var levels: [Double]
    public private(set) var isLive = false

    private var lastSoundAt: Date?
    private var lastUpdateAt: Date?

    public init(bandCount: Int) {
        self.bandCount = bandCount
        self.levels = Array(repeating: 0, count: bandCount)
    }

    public mutating func update(samples: [Float], sampleRate: Double, at now: Date) {
        let elapsed = lastUpdateAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        lastUpdateAt = now
        let hasSound = samples.contains { $0 != 0 }
        if hasSound { lastSoundAt = now }
        isLive = lastSoundAt.map { now.timeIntervalSince($0) < Self.silenceTimeout } ?? false
        let targets = hasSound
            ? AudioSpectrum.bandLevels(samples: samples, sampleRate: sampleRate, bandCount: bandCount)
            : Array(repeating: 0, count: bandCount)
        levels = zip(levels, targets).map { current, target in
            target >= current ? target : max(target, current - Self.releasePerSecond * elapsed)
        }
    }

    public mutating func reset() {
        levels = Array(repeating: 0, count: bandCount)
        isLive = false
        lastSoundAt = nil
        lastUpdateAt = nil
    }
}

/// The newest `capacity` samples, oldest first.
public struct SampleRing: Sendable {
    public let capacity: Int
    public private(set) var latest: [Float] = []

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public mutating func append(_ samples: [Float]) {
        latest.append(contentsOf: samples.suffix(capacity))
        if latest.count > capacity {
            latest.removeFirst(latest.count - capacity)
        }
    }

    public mutating func clear() {
        latest.removeAll(keepingCapacity: true)
    }
}

/// Averages channels into one.
public enum AudioMixdown {
    public static func mono(interleaved samples: [Float], channels: Int) -> [Float] {
        guard channels > 1 else { return samples }
        let frames = samples.count / channels
        return (0..<frames).map { frame in
            var sum: Float = 0
            for channel in 0..<channels { sum += samples[frame * channels + channel] }
            return sum / Float(channels)
        }
    }

    public static func mono(planar channels: [[Float]]) -> [Float] {
        guard let frames = channels.map(\.count).min(), !channels.isEmpty else { return [] }
        return (0..<frames).map { frame in
            channels.reduce(Float(0)) { $0 + $1[frame] } / Float(channels.count)
        }
    }
}
