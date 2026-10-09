import Foundation
import CoreAudio
import DivotCore

/// A registered Core Audio property listener.
final class AudioListenerToken: @unchecked Sendable {
    let address: AudioObjectPropertyAddress
    let block: AudioObjectPropertyListenerBlock

    init(address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) {
        self.address = address
        self.block = block
    }
}

/// The Core Audio property operations the volume watcher needs.
///
/// Injected so the watcher's start/stop ordering — and the "callback after
/// cancel" guard — are testable without touching a real audio device.
protocol AudioPropertyListening: Sendable {
    func defaultOutputDevice() -> AudioDeviceID?
    func addListener(on object: AudioObjectID,
                     address: AudioObjectPropertyAddress,
                     queue: DispatchQueue,
                     handler: @escaping @Sendable () -> Void) -> AudioListenerToken
    func removeListener(_ token: AudioListenerToken, on object: AudioObjectID, queue: DispatchQueue)
}

/// Live Core Audio implementation.
struct CoreAudioPropertyListening: AudioPropertyListening {
    func defaultOutputDevice() -> AudioDeviceID? {
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

    func addListener(on object: AudioObjectID,
                     address: AudioObjectPropertyAddress,
                     queue: DispatchQueue,
                     handler: @escaping @Sendable () -> Void) -> AudioListenerToken {
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        var mutable = address
        AudioObjectAddPropertyListenerBlock(object, &mutable, queue, block)
        return AudioListenerToken(address: address, block: block)
    }

    func removeListener(_ token: AudioListenerToken, on object: AudioObjectID, queue: DispatchQueue) {
        var mutable = token.address
        AudioObjectRemovePropertyListenerBlock(object, &mutable, queue, token.block)
    }
}

/// Live output volume and mute state from Core Audio.
///
/// Reads are cheap property copies. Changes arrive through Core Audio property
/// listeners on a utility queue: volume/mute on the current default output
/// device and default-device switches on the system object. No polling, no main
/// thread, and no permission.
public final class CoreAudioVolumeReading: VolumeReading, @unchecked Sendable {
    private let backend: any AudioPropertyListening

    public init() {
        self.backend = CoreAudioPropertyListening()
    }

    init(backend: any AudioPropertyListening) {
        self.backend = backend
    }

    public func snapshot() -> VolumeSnapshot? {
        CoreAudioVolumeReading.read(backend: backend)
    }

    public func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription {
        let watcher = CoreAudioVolumeWatcher(backend: backend, handler: handler)
        watcher.start()
        return CallbackSubscription { watcher.stop() }
    }

    // MARK: Property reads

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

    static func read(backend: any AudioPropertyListening = CoreAudioPropertyListening()) -> VolumeSnapshot? {
        guard let device = backend.defaultOutputDevice() else { return .noOutput }
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
///
/// `stop()` marks the watcher permanently stopped before removing anything, so a
/// default-device callback that was already queued cannot re-install listeners
/// or fire after cancellation.
final class CoreAudioVolumeWatcher: @unchecked Sendable {
    private let backend: any AudioPropertyListening
    private let handler: @Sendable () -> Void
    private let queue = DispatchQueue(label: "divot.audio", qos: .utility)
    private let lock = NSLock()
    private var stopped = false
    private var device: AudioDeviceID?
    private var deviceListeners: [AudioListenerToken] = []
    private var systemToken: AudioListenerToken?

    init(backend: any AudioPropertyListening, handler: @escaping @Sendable () -> Void) {
        self.backend = backend
        self.handler = handler
    }

    func start() {
        lock.lock()
        if stopped { lock.unlock(); return }
        lock.unlock()
        systemToken = backend.addListener(on: AudioObjectID(kAudioObjectSystemObject),
                                          address: Self.systemAddress,
                                          queue: queue) { [weak self] in
            self?.defaultDeviceChanged()
        }
        installDeviceListeners()
    }

    func stop() {
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        stopped = true
        let listeners = deviceListeners
        let device = self.device
        let system = systemToken
        deviceListeners = []
        self.device = nil
        systemToken = nil
        lock.unlock()

        if let device {
            for token in listeners {
                backend.removeListener(token, on: device, queue: queue)
            }
        }
        if let system {
            backend.removeListener(system, on: AudioObjectID(kAudioObjectSystemObject), queue: queue)
        }
    }

    private func installDeviceListeners() {
        guard let device = backend.defaultOutputDevice() else { return }
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        self.device = device
        let volume = backend.addListener(on: device, address: Self.volumeAddress, queue: queue) { [weak self] in
            self?.deviceChanged()
        }
        let mute = backend.addListener(on: device, address: Self.muteAddress, queue: queue) { [weak self] in
            self?.deviceChanged()
        }
        deviceListeners = [volume, mute]
        lock.unlock()
    }

    private func defaultDeviceChanged() {
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        let oldDevice = device
        let oldListeners = deviceListeners
        deviceListeners = []
        device = nil
        lock.unlock()

        if let oldDevice {
            for token in oldListeners {
                backend.removeListener(token, on: oldDevice, queue: queue)
            }
        }
        installDeviceListeners()

        lock.lock()
        let stillRunning = !stopped
        lock.unlock()
        if stillRunning { handler() }
    }

    private func deviceChanged() {
        lock.lock()
        let stillRunning = !stopped
        lock.unlock()
        if stillRunning { handler() }
    }

    private static let systemAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
}
