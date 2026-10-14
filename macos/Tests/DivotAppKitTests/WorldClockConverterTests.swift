import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The world clock popover's time converter: the 15-minute scrubber, its "Now"
/// reset, the converted row times with day labels, and the sun/moon working-hours
/// markers. All driven through the real content controller with a fixed instant,
/// so nothing reads the wall clock or a display.
@MainActor
@Suite("World clock popover time converter")
struct WorldClockPopoverConverterTests {
    private let utc = TimeZone(identifier: "UTC")!
    private let gregorian = Calendar(identifier: .gregorian)
    /// 2026-01-01T10:00Z: Kiritimati (+14) is tomorrow, Midway (-11) yesterday.
    private let reference = Date(timeIntervalSince1970: 1_767_261_600)

    private func makeController() -> WorldClockPopoverContentController {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        controller.render(timezones: ["Pacific/Kiritimati", "Pacific/Midway", "Europe/London"],
                          timeFormat: .twentyFourHour,
                          showSeconds: false,
                          customPattern: nil,
                          at: reference,
                          localTimeZone: utc,
                          calendar: gregorian)
        return controller
    }

    private func textFields(in view: NSView) -> [NSTextField] {
        var result: [NSTextField] = []
        func walk(_ v: NSView) {
            if let field = v as? NSTextField { result.append(field) }
            v.subviews.forEach(walk)
        }
        walk(view)
        return result
    }

    /// The day/night marker images, matched by the accessibility label they set.
    private func markers(in view: NSView) -> [NSImageView] {
        var result: [NSImageView] = []
        func walk(_ v: NSView) {
            if let image = v as? NSImageView,
               let label = image.accessibilityLabel(),
               label == "Working hours" || label == "Outside working hours" {
                result.append(image)
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return result
    }

    private func button(labelled label: String, in view: NSView) -> NSButton? {
        var result: NSButton?
        func walk(_ v: NSView) {
            if let button = v as? NSButton, button.accessibilityLabel() == label {
                result = button
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return result
    }

    private func keyDownEvent(_ keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                         windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: keyCode)!
    }

    @Test func convertedRowsShowEquivalentTimeAndDayLabels() {
        let controller = makeController()
        let labels = textFields(in: controller.view).compactMap { $0.accessibilityLabel() }

        #expect(labels.contains { $0.contains("Tomorrow") }, "Kiritimati is a day ahead")
        #expect(labels.contains { $0.contains("Yesterday") }, "Midway is a day behind")
    }

    @Test func markersReflectEachZonesLocalWorkingHours() {
        let controller = makeController()
        let labels = markers(in: controller.view).compactMap { $0.accessibilityLabel() }

        // At 10:00Z: London is 10:00 (working), Kiritimati 00:00 and Midway 23:00
        // are both outside the window.
        #expect(labels.filter { $0 == "Working hours" }.count == 1)
        #expect(labels.filter { $0 == "Outside working hours" }.count == 2)
    }

    @Test func scrubbingUpdatesTimesAndFlipsTheMarkers() {
        let controller = makeController()
        let slider = controller.scrubberSliderForTesting
        #expect(slider?.doubleValue == 600, "the scrubber starts at the reference local minute (10:00)")

        // Twelve hours on: 22:00Z, where London is off-hours but Kiritimati
        // (12:00) and Midway (11:00) are working.
        controller.stepScrubber(by: 48)
        #expect(slider?.doubleValue == 1320, "48 steps is twelve hours")

        let labels = markers(in: controller.view).compactMap { $0.accessibilityLabel() }
        #expect(labels.filter { $0 == "Working hours" }.count == 2)
        #expect(labels.filter { $0 == "Outside working hours" }.count == 1)
    }

    @Test func dayLabelFollowsTheScrubbedInstant() {
        let controller = makeController()
        // Stepping far enough that the reference day flips keeps the labels
        // coherent (Midway stops being "yesterday" once local time is evening).
        controller.stepScrubber(by: 48)
        let labels = textFields(in: controller.view).compactMap { $0.accessibilityLabel() }
        #expect(labels.contains { $0.contains("Tomorrow") }, "Kiritimati is still a day ahead at 22:00Z")
    }

    @Test func arrowKeysStepTheScrubberFifteenMinutes() {
        let controller = makeController()
        guard let slider = controller.scrubberSliderForTesting else {
            Issue.record("expected a scrubber slider")
            return
        }

        slider.keyDown(with: keyDownEvent(124)) // right arrow
        #expect(slider.doubleValue == 615, "right arrow moves 15 minutes forward")

        slider.keyDown(with: keyDownEvent(123)) // left arrow
        #expect(slider.doubleValue == 600, "left arrow moves 15 minutes back")
    }

    @Test func theSliderAndResetAreLabelled() {
        let controller = makeController()
        let slider = controller.scrubberSliderForTesting
        #expect(slider?.accessibilityLabel() == "Time to convert")
        #expect((slider?.accessibilityHelp() ?? "").contains("15"))

        let reset = button(labelled: "Reset to now", in: controller.view)
        #expect(reset != nil, "the Now control is labelled for VoiceOver")
    }

    @Test func nowControlResetsToTheReferenceAfterScrubbing() {
        let controller = makeController()
        guard let slider = controller.scrubberSliderForTesting,
              let reset = button(labelled: "Reset to now", in: controller.view) else {
            Issue.record("expected the scrubber and its reset control")
            return
        }

        let originalHeader = textFields(in: controller.view).first?.stringValue
        #expect(reset.isEnabled == false, "Now is inert until the time is scrubbed")

        controller.stepScrubber(by: 4)
        #expect(reset.isEnabled == true)
        #expect(slider.doubleValue == 660)

        reset.sendAction(reset.action, to: reset.target)
        #expect(slider.doubleValue == 600)
        #expect(reset.isEnabled == false, "back at now, the reset is inert again")
        #expect(textFields(in: controller.view).first?.stringValue == originalHeader)
    }
}
