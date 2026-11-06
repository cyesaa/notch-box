import AudioToolbox
import CoreAudio
import Foundation
import NotchBoxCore
import os

/// Listens to everything the Mac plays through a Core Audio process tap (macOS 14.2+) and keeps the
/// newest mono samples. Nothing is recorded or stored. The first start asks for the "System Audio
/// Recording" permission; when it is denied the tap delivers silence.
/// Starting blocks while macOS shows that permission prompt, so start and stop run on `controlQueue`
/// and never on the main thread. All Core Audio state is confined to that queue.
@available(macOS 14.2, *)
final class SystemAudioTap: @unchecked Sendable {
    enum TapError: Error {
        case failed(String, OSStatus)
        case unsupportedFormat
    }

    /// About 85 ms at 48 kHz: enough for a 2048-point spectrum.
    static let sampleCapacity = 4096

    private var sampleRate: Double = 48_000
    private let controlQueue = DispatchQueue(label: "com.notchbox.NotchBox.audio-tap.control")
    private let samples = OSAllocatedUnfairLock(initialState: SampleRing(capacity: SystemAudioTap.sampleCapacity))
    private let queue = DispatchQueue(label: "com.notchbox.NotchBox.audio-tap", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?

    /// Starts in the background; `completion` gets the sample rate, on an arbitrary queue.
    func start(completion: @escaping @Sendable (Result<Double, Error>) -> Void) {
        controlQueue.async { [self] in
            guard procID == nil else { return completion(.success(sampleRate)) }
            do {
                try startTap()
                completion(.success(sampleRate))
            } catch {
                tearDown()
                completion(.failure(error))
            }
        }
    }

    func stop() {
        controlQueue.async { [self] in tearDown() }
    }

    private func tearDown() {
        if let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        samples.withLock { $0.clear() }
    }

    /// The newest samples, oldest first.
    func latestSamples() -> [Float] {
        samples.withLock { $0.latest }
    }

    private func startTap() throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "NotchBox level meter"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID), "create process tap")

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), "read tap format")
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mBitsPerChannel == 32
        else { throw TapError.unsupportedFormat }
        sampleRate = format.mSampleRate
        let channels = Int(format.mChannelsPerFrame)
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0

        // A private aggregate device whose only input is the tap.
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "NotchBox Level Meter",
            kAudioAggregateDeviceUIDKey: "com.notchbox.NotchBox.level-meter.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true],
            ],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create aggregate device")

        let samples = self.samples
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
                let mono = Self.mono(from: input, channels: channels, interleaved: interleaved)
                guard !mono.isEmpty else { return }
                samples.withLock { $0.append(mono) }
            },
            "create IO proc"
        )
        try check(AudioDeviceStart(aggregateID, procID), "start device")
    }

    private static func mono(from list: UnsafePointer<AudioBufferList>, channels: Int, interleaved: Bool) -> [Float] {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        let arrays: [[Float]] = buffers.compactMap { buffer in
            guard let data = buffer.mData else { return nil }
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count))
        }
        guard !arrays.isEmpty else { return [] }
        if interleaved, arrays.count == 1 {
            return AudioMixdown.mono(interleaved: arrays[0], channels: max(1, channels))
        }
        return AudioMixdown.mono(planar: arrays)
    }

    private func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw TapError.failed(step, status) }
    }
}
