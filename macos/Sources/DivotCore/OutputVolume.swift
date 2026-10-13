import Foundation

// MARK: - Pure level math

/// Pure volume-level math shared by the popover UI and the live Core Audio
/// reader. Kept here so clamping is unit-tested without touching a device.
public enum OutputVolume {
    /// Clamp a level into the 0...1 range Core Audio's scalar volume uses.
    ///
    /// A non-finite value (NaN or infinity) clamps to 0 rather than poisoning
    /// the device write with an undefined scalar.
    public static func clamped(_ level: Double) -> Double {
        guard level.isFinite else { return 0 }
        return max(0, min(1, level))
    }

    /// A clamped level as the whole percentage the popover shows.
    public static func percent(_ level: Double) -> Int {
        Int((clamped(level) * 100).rounded())
    }
}

// MARK: - Seam

/// The seam the output-volume popover drives through.
///
/// It is deliberately wider than `VolumeReading`: alongside the snapshot and
/// change observation the bar item already uses, the popover needs to write the
/// level and mute state. The live implementation (`CoreAudioVolumeReading` in
/// `DivotAppKit`) uses public Core Audio property reads and writes only; tests
/// supply a fake, so the clamping and no-settable-control rules are asserted
/// without a real device.
public protocol OutputVolumeControlling: Sendable {
    /// The current default-output state, or `nil` when it cannot be read.
    func snapshot() -> VolumeSnapshot?
    /// Write the default output's scalar volume.
    func setLevel(_ level: Double)
    /// Write the default output's mute state.
    func setMuted(_ muted: Bool)
    /// Observe external volume/mute/default-device changes. Removed on cancel.
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription
}

// MARK: - Model

/// Holds the output-volume state the popover renders and routes edits through
/// the seam.
///
/// The popover owns one of these. It reads once when it opens, subscribes to
/// Core Audio property listeners while it is open (so keyboard keys and other
/// apps move the slider), and cancels that subscription when it closes. There is
/// no timer and no polling.
@MainActor
public final class VolumePopoverModel {
    /// The latest state, or `nil` before the first read.
    public private(set) var state: VolumeSnapshot?

    /// Called on the main actor after an external change reloads `state`, so a
    /// presenter can repaint. Not called for the presenter's own writes.
    public var onChange: (@MainActor () -> Void)?

    private let control: any OutputVolumeControlling
    private var subscription: (any ProviderSubscription)?

    public init(control: any OutputVolumeControlling) {
        self.control = control
    }

    /// Read the current state once. Called when the popover opens.
    public func refresh() {
        state = control.snapshot()
    }

    /// Subscribe to external volume/mute changes. Idempotent while open.
    public func startObserving() {
        guard subscription == nil else { return }
        subscription = control.observeChanges { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.refresh()
                self.onChange?()
            }
        }
    }

    /// Remove the external-change subscription. Called when the popover closes.
    public func stopObserving() {
        subscription?.cancel()
        subscription = nil
    }

    /// The slider's edit. Clamps to 0...1, writes through the seam, and returns
    /// the applied value. Returns `nil` when there is no settable output, so the
    /// UI can leave a disabled slider inert.
    @discardableResult
    public func setLevel(_ level: Double) -> Double? {
        guard let state, state.hasOutputDevice, state.isSettable else { return nil }
        let clamped = OutputVolume.clamped(level)
        control.setLevel(clamped)
        self.state = control.snapshot()
        return clamped
    }

    /// The mute toggle. Returns the applied mute state, or `nil` when there is
    /// no settable output.
    @discardableResult
    public func setMuted(_ muted: Bool) -> Bool? {
        guard let state, state.hasOutputDevice, state.isSettable else { return nil }
        control.setMuted(muted)
        self.state = control.snapshot()
        return muted
    }
}
