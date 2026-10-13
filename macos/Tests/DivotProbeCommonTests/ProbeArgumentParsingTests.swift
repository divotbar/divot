import Foundation
import Testing
import DivotProbeCommon

@Suite("Probe argument parsing")
struct ProbeArgumentParsingTests {
    @Test("Default configuration when no arguments")
    func defaultConfiguration() {
        let config = parseProbeArguments(["divot-notification-banner-probe"])
        #expect(config.watchMode == false)
        #expect(config.watchDuration == 15)
    }

    @Test("Watch mode enabled with default duration")
    func watchModeDefault() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--watch"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == 15)
    }

    @Test("Watch mode with custom duration")
    func watchModeCustomDuration() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--watch", "30"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == 30)
    }

    @Test("Watch mode with fractional duration")
    func watchModeFractionalDuration() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--watch", "2.5"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == 2.5)
    }

    @Test("Watch mode ignores non-numeric duration")
    func watchModeInvalidDuration() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--watch", "invalid"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == 15)  // Falls back to default
    }

    @Test("Watch mode with zero duration")
    func watchModeZeroDuration() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--watch", "0"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == 0)
    }

    @Test("Watch mode with negative duration")
    func watchModeNegativeDuration() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--watch", "-5"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == -5)
    }

    @Test("Unknown arguments are ignored")
    func unknownArguments() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--unknown", "value"])
        #expect(config.watchMode == false)
        #expect(config.watchDuration == 15)
    }

    @Test("Watch flag is detected among other arguments")
    func watchAmongOtherArgs() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--verbose", "--watch", "20"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == 20)
    }

    @Test("First watch flag wins if multiple")
    func multipleWatchFlags() {
        let config = parseProbeArguments(["divot-notification-banner-probe", "--watch", "10", "--watch", "20"])
        #expect(config.watchMode == true)
        #expect(config.watchDuration == 10)
    }
}
