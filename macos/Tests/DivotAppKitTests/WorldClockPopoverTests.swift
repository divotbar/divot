import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The world clock popover's content rows and their remove controls. Rows are
/// built from `WorldClock.entries`, which drops invalid identifiers and
/// collapses duplicates, so removal must target the timezone identifier rather
/// than the visible row index.
@MainActor
@Suite("World clock popover content")
struct WorldClockPopoverContentTests {
    private func makeController() -> WorldClockPopoverContentController {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        return controller
    }

    /// The remove buttons, matched by the timezone identifier they carry.
    private func removeButtons(in view: NSView) -> [NSButton] {
        var result: [NSButton] = []
        func walk(_ v: NSView) {
            if let button = v as? NSButton,
               let identifier = button.identifier?.rawValue,
               TimeZone.knownTimeZoneIdentifiers.contains(identifier) {
                result.append(button)
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return result
    }

    @Test func removeButtonCarriesTheTimezoneIdentifierNotTheRowIndex() {
        let controller = makeController()
        // A stale invalid identifier and a duplicate ahead of the visible row
        // make an index-based removal delete the wrong zone.
        let stored = ["Invalid/Timezone", "Asia/Tokyo", "Asia/Tokyo", "America/Los_Angeles"]
        controller.render(timezones: stored, timeFormat: .twentyFourHour, showSeconds: false)

        let buttons = removeButtons(in: controller.view)
        #expect(buttons.count == 2, "invalid identifiers are dropped and duplicates collapse to two rows")

        var reported: [String]?
        controller.onUpdateTimezones = { reported = $0 }

        guard let losAngeles = buttons.first(where: { $0.identifier?.rawValue == "America/Los_Angeles" }) else {
            Issue.record("expected a remove button for America/Los_Angeles")
            return
        }
        losAngeles.sendAction(losAngeles.action, to: losAngeles.target)

        #expect(reported == ["Invalid/Timezone", "Asia/Tokyo", "Asia/Tokyo"],
                "removing Los Angeles must keep the stale invalid entry and both duplicate Tokyo entries")
    }

    @Test func removingADuplicatedZoneRemovesEveryStoredCopy() {
        let controller = makeController()
        controller.render(timezones: ["Asia/Tokyo", "Asia/Tokyo", "America/Los_Angeles"],
                          timeFormat: .twentyFourHour,
                          showSeconds: false)

        var reported: [String]?
        controller.onUpdateTimezones = { reported = $0 }

        let buttons = removeButtons(in: controller.view)
        guard let tokyo = buttons.first(where: { $0.identifier?.rawValue == "Asia/Tokyo" }) else {
            Issue.record("expected a remove button for Asia/Tokyo")
            return
        }
        tokyo.sendAction(tokyo.action, to: tokyo.target)

        #expect(reported == ["America/Los_Angeles"])
    }
}
