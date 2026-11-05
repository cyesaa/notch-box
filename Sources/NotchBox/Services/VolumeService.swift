import AudioToolbox
import CoreAudio
import Foundation

/// System output volume of the default output device, via CoreAudio.
@MainActor
final class VolumeService: VolumeControlling {
    private(set) var volume: Float = 0
    private(set) var isSettable = false
    var onChange: (() -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var volumeListener: AudioObjectPropertyListenerBlock?

    func start() {
        guard deviceListener == nil else { return }
        var address = Self.defaultDeviceAddress()
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.attachToDefaultDevice() }
        }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener) == noErr {
            deviceListener = listener
        }
        attachToDefaultDevice()
    }

    func setVolume(_ value: Float) {
        guard isSettable else { return }
        var address = Self.volumeAddress()
        var newValue = Float32(min(max(value, 0), 1))
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &newValue)
        if status == noErr {
            volume = newValue
            onChange?()
        }
    }

    private func attachToDefaultDevice() {
        detachVolumeListener()
        deviceID = Self.currentDefaultDevice()
        if deviceID != kAudioObjectUnknown {
            var address = Self.volumeAddress()
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            if AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener) == noErr {
                volumeListener = listener
            }
        }
        refresh()
    }

    private func detachVolumeListener() {
        guard let listener = volumeListener, deviceID != kAudioObjectUnknown else { return }
        var address = Self.volumeAddress()
        _ = AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
        volumeListener = nil
    }

    private func refresh() {
        var address = Self.volumeAddress()
        let hasVolume = deviceID != kAudioObjectUnknown && AudioObjectHasProperty(deviceID, &address)
        var settable: DarwinBoolean = false
        if hasVolume {
            _ = AudioObjectIsPropertySettable(deviceID, &address, &settable)
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr {
                volume = value
            }
        }
        isSettable = hasVolume && settable.boolValue
        onChange?()
    }

    private static func currentDefaultDevice() -> AudioObjectID {
        var address = defaultDeviceAddress()
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return status == noErr ? id : AudioObjectID(kAudioObjectUnknown)
    }

    private static func defaultDeviceAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func volumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
