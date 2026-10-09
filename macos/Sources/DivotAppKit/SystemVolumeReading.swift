import Foundation
import CoreAudio
import DivotCore

/// Builds an output-scope property address for a device.
private func outputAddress(selector: AudioObjectPropertySelector,
                           element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector,
                               mScope: kAudioDevicePropertyScopeOutput,
                               mElement: element)
}

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
    /// Whether `object` exposes `address`. Used to pick the property elements a
    /// device actually has (main control versus per-channel controls).
    func hasProperty(on object: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool
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

    func hasProperty(on object: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
        var mutable = address
        return AudioObjectHasProperty(object, &mutable)
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

    private static func isMuted(backend: any AudioPropertyListening, device: AudioDeviceID) -> Bool? {
        for element in muteElements(backend: backend, device: device) {
            if let value = mute(device, element: element) { return value }
        }
        return nil
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
    /// back to the two front channels. The watcher observes the same elements.
    private static func level(backend: any AudioPropertyListening, device: AudioDeviceID) -> Float? {
        let values = volumeElements(backend: backend, device: device)
            .compactMap { float(device, kAudioDevicePropertyVolumeScalar, element: $0) }
        switch values.count {
        case 0: return nil
        default: return values.reduce(0, +) / Float(values.count)
        }
    }

    /// The volume elements this device exposes: the main element when present,
    /// otherwise the front channels that per-channel-only devices provide.
    static func volumeElements(backend: any AudioPropertyListening,
                               device: AudioDeviceID) -> [AudioObjectPropertyElement] {
        controlElements(backend: backend, device: device,
                        selector: kAudioDevicePropertyVolumeScalar,
                        fallbackElements: [1, 2])
    }

    /// The mute elements this device exposes: main element first, then channel 1.
    static func muteElements(backend: any AudioPropertyListening,
                             device: AudioDeviceID) -> [AudioObjectPropertyElement] {
        controlElements(backend: backend, device: device,
                        selector: kAudioDevicePropertyMute,
                        fallbackElements: [1])
    }

    private static func controlElements(backend: any AudioPropertyListening,
                                        device: AudioDeviceID,
                                        selector: AudioObjectPropertySelector,
                                        fallbackElements: [AudioObjectPropertyElement]) -> [AudioObjectPropertyElement] {
        let main = outputAddress(selector: selector, element: kAudioObjectPropertyElementMain)
        if backend.hasProperty(on: device, address: main) { return [kAudioObjectPropertyElementMain] }
        return fallbackElements.filter {
            backend.hasProperty(on: device, address: outputAddress(selector: selector, element: $0))
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
        let muted = isMuted(backend: backend, device: device) ?? false
        let level = level(backend: backend, device: device)
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
        let addresses = Self.observedAddresses(backend: backend, device: device)
        deviceListeners = addresses.map { address in
            backend.addListener(on: device, address: address, queue: queue) { [weak self] in
                self?.deviceChanged()
            }
        }
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

    /// The property addresses the watcher registers on the current output device.
    ///
    /// The snapshot prefers the main element and falls back to per-channel
    /// controls on devices that expose no main element (front channels 1 and 2
    /// for volume, channel 1 for mute). The watcher observes the exact same
    /// elements: listening only on the main element would leave those devices
    /// showing a stale value after a volume or mute change.
    static func observedAddresses(backend: any AudioPropertyListening,
                                  device: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        CoreAudioVolumeReading.volumeElements(backend: backend, device: device)
            .map { outputAddress(selector: kAudioDevicePropertyVolumeScalar, element: $0) }
            + CoreAudioVolumeReading.muteElements(backend: backend, device: device)
            .map { outputAddress(selector: kAudioDevicePropertyMute, element: $0) }
    }
}
