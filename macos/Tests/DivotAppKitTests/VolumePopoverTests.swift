import AppKit
import Testing
@testable import DivotAppKit
import DivotCore

/// The volume popover's content rows: the slider with its percentage, the mute
/// toggle, and the disabled note for an output with no settable volume.
@MainActor
@Suite("Volume popover content")
struct VolumePopoverContentTests {
    private func makeController() -> VolumePopoverContentController {
        let controller = VolumePopoverContentController()
        // Force `loadView` so the rows exist before the assertions.
        _ = controller.view
        return controller
    }

    private func settable(_ level: Double, muted: Bool = false) -> VolumeSnapshot {
        VolumeSnapshot(hasOutputDevice: true, outputDeviceName: "Speakers",
                       level: level, isMuted: muted, isSettable: true)
    }

    @Test func settableOutputEnablesTheSliderAndShowsThePercentage() {
        let controller = makeController()

        controller.update(settable(0.4))

        #expect(controller.slider.isEnabled)
        #expect(controller.muteButton.isEnabled)
        #expect(controller.slider.doubleValue == 0.4)
        #expect(controller.percentLabel.stringValue == "40%")
        #expect(controller.statusLabel.isHidden)
    }

    @Test func unsettableOutputDisablesTheControlsAndExplainsWhy() {
        let controller = makeController()

        controller.update(VolumeSnapshot(hasOutputDevice: true, outputDeviceName: "HDMI",
                                         level: 1, isMuted: false, isSettable: false))

        #expect(!controller.slider.isEnabled)
        #expect(!controller.muteButton.isEnabled)
        #expect(controller.percentLabel.stringValue == "—")
        #expect(!controller.statusLabel.isHidden)
        #expect(!controller.statusLabel.stringValue.isEmpty)
    }

    @Test func missingOutputDisablesTheControls() {
        let controller = makeController()

        controller.update(nil)
        #expect(!controller.slider.isEnabled)
        #expect(!controller.muteButton.isEnabled)

        controller.update(.noOutput)
        #expect(!controller.slider.isEnabled)
        #expect(!controller.muteButton.isEnabled)
    }

    @Test func sliderHasAnAccessibilityLabelAndValue() {
        let controller = makeController()

        controller.update(settable(0.4))

        #expect(controller.slider.accessibilityLabel() == "Output volume")
        #expect(controller.slider.accessibilityValue() as? String == "40%")
        #expect(controller.slider.isEnabled)
    }

    @Test func movingTheSliderForwardsTheValue() {
        let controller = makeController()
        var reported: Double?
        controller.onLevelChanged = { reported = $0 }

        controller.slider.doubleValue = 0.7
        controller.slider.sendAction(controller.slider.action, to: controller.slider.target)

        #expect(reported == 0.7)
    }

    @Test func togglingMuteForwardsTheState() {
        let controller = makeController()
        var reported: Bool?
        controller.onMuteToggled = { reported = $0 }

        controller.muteButton.state = .on
        controller.muteButton.sendAction(controller.muteButton.action, to: controller.muteButton.target)

        #expect(reported == true)
    }
}
