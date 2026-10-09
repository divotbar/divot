import Foundation
import CoreAudio
import DivotCore

/// Live output volume and mute state from Core Audio.
///
/// Reads are cheap property copies. Changes arrive through Core Audio property
/// listeners on a utility queue: volume/mute on the current default output
/// device and default-device switches on the system object. No polling, no main
/// thread, and no permission.
public final class CoreAudioVolumeReading: VolumeReading, @unchecked Sendable {
    public init() {}

    public func snapshot() -> VolumeSnapshot? {
        CoreAudioVolumeReading.read()
    }

    public func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription {
        let watcher = CoreAudioVolumeWatcher(handler: handler)
        watcher.start()
        return CallbackSubscription { watcher.stop() }
    }

    // MARK: Property reads

    static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address, 0, nil, &size, &device)
        guard status == noErr, device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static func float(_ device: AudioDeviceID,
                              _ selector: AudioObjectPropertySelector,
                              element: AudioObjectPropertyElement) -> Float? {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: element)
        var size = UInt32(MemoryLayout<Float32>.size)
        var value: Float32 = 0
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? Float(value) : nil
    }

    private static func isMuted(_ device: AudioDeviceID) -> Bool? {
        if let value = mute(device, element: kAudioObjectPropertyElementMain) { return value }
        return mute(device, element: 1)
    }

    private static func mute(_ device: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: element)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value != 0 : nil
    }

    /// Main element first; some devices only expose per-channel volume, so fall
    /// back to the two front channels.
    private static func level(_ device: AudioDeviceID) -> Float? {
        if let main = float(device, kAudioDevicePropertyVolumeScalar,
                            element: kAudioObjectPropertyElementMain) {
            return main
        }
        let left = float(device, kAudioDevicePropertyVolumeScalar, element: 1)
        let right = float(device, kAudioDevicePropertyVolumeScalar, element: 2)
        switch (left, right) {
        case let (l?, r?): return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    private static func deviceName(_ device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    static func read() -> VolumeSnapshot? {
        guard let device = defaultOutputDevice() else { return .noOutput }
        let muted = isMuted(device) ?? false
        let level = level(device)
        return VolumeSnapshot(hasOutputDevice: true,
                              outputDeviceName: deviceName(device),
                              // A device with no software volume control is
                              // treated as full scale, honoring mute.
                              level: Double(level ?? (muted ? 0 : 1)),
                              isMuted: muted)
    }
}

/// Installs and removes the Core Audio property listeners.
private final class CoreAudioVolumeWatcher: @unchecked Sendable {
    private let handler: @Sendable () -> Void
    private let queue = DispatchQueue(label: "divot.audio", qos: .utility)
    private let lock = NSLock()
    private var device: AudioDeviceID?
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var systemListener: (AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)?

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func start() {
        let systemBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.defaultDeviceChanged()
        }
        var systemAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                       mScope: kAudioObjectPropertyScopeGlobal,
                                                       mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                            &systemAddress, queue, systemBlock)
        systemListener = (systemAddress, systemBlock)
        installDeviceListeners()
    }

    func stop() {
        lock.lock()
        let listeners = deviceListeners
        let device = self.device
        let system = systemListener
        deviceListeners = []
        self.device = nil
        systemListener = nil
        lock.unlock()

        if let device {
            for (address, block) in listeners {
                var mutable = address
                AudioObjectRemovePropertyListenerBlock(device, &mutable, queue, block)
            }
        }
        if let system {
            var mutable = system.0
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                                   &mutable, queue, system.1)
        }
    }

    private func installDeviceListeners() {
        guard let device = CoreAudioVolumeReading.defaultOutputDevice() else { return }
        lock.lock()
        self.device = device
        lock.unlock()

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.deviceChanged() }
        var volume = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
                                                mScope: kAudioDevicePropertyScopeOutput,
                                                mElement: kAudioObjectPropertyElementMain)
        var mute = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                              mScope: kAudioDevicePropertyScopeOutput,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(device, &volume, queue, block)
        AudioObjectAddPropertyListenerBlock(device, &mute, queue, block)
        lock.lock()
        deviceListeners = [(volume, block), (mute, block)]
        lock.unlock()
    }

    private func defaultDeviceChanged() {
        lock.lock()
        let oldDevice = device
        let oldListeners = deviceListeners
        deviceListeners = []
        device = nil
        lock.unlock()
        if let oldDevice {
            for (address, block) in oldListeners {
                var mutable = address
                AudioObjectRemovePropertyListenerBlock(oldDevice, &mutable, queue, block)
            }
        }
        installDeviceListeners()
        handler()
    }

    private func deviceChanged() {
        handler()
    }
}
