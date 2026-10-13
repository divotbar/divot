import Foundation
import Testing
import CoreGraphics
import DivotProbeCommon

@Suite("Window bounds parsing")
struct WindowBoundsTests {
    @Test("Parse valid bounds dictionary")
    func parseValidBounds() {
        let dict: [String: Any] = [
            "kCGWindowBounds": [
                "X": NSNumber(value: 100.0),
                "Y": NSNumber(value: 200.0),
                "Width": NSNumber(value: 300.0),
                "Height": NSNumber(value: 400.0)
            ]
        ]

        let bounds = parseBoundsFromWindowDict(dict)
        #expect(bounds.minX == 100.0)
        #expect(bounds.minY == 200.0)
        #expect(bounds.width == 300.0)
        #expect(bounds.height == 400.0)
    }

    @Test("Parse bounds with zero values")
    func parseZeroBounds() {
        let dict: [String: Any] = [
            "kCGWindowBounds": [
                "X": NSNumber(value: 0.0),
                "Y": NSNumber(value: 0.0),
                "Width": NSNumber(value: 0.0),
                "Height": NSNumber(value: 0.0)
            ]
        ]

        let bounds = parseBoundsFromWindowDict(dict)
        #expect(bounds == .zero)
    }

    @Test("Missing bounds key returns zero rect")
    func missingBoundsKey() {
        let dict: [String: Any] = [:]
        let bounds = parseBoundsFromWindowDict(dict)
        #expect(bounds == .zero)
    }

    @Test("Invalid bounds type returns zero rect")
    func invalidBoundsType() {
        let dict: [String: Any] = [
            "kCGWindowBounds": "not a dict"
        ]
        let bounds = parseBoundsFromWindowDict(dict)
        #expect(bounds == .zero)
    }

    @Test("Missing numeric values default to zero")
    func missingNumericValues() {
        let dict: [String: Any] = [
            "kCGWindowBounds": [
                "X": NSNumber(value: 10.0)
                // Y, Width, Height missing
            ]
        ]

        let bounds = parseBoundsFromWindowDict(dict)
        #expect(bounds.minX == 10.0)
        #expect(bounds.minY == 0.0)
        #expect(bounds.width == 0.0)
        #expect(bounds.height == 0.0)
    }

    @Test("Real notification banner bounds example")
    func realBannerExample() {
        // Typical notification banner at top right: ~354x76 at approximately (1356, 0)
        let dict: [String: Any] = [
            "kCGWindowBounds": [
                "X": NSNumber(value: 1356.0),
                "Y": NSNumber(value: 0.0),
                "Width": NSNumber(value: 354.0),
                "Height": NSNumber(value: 76.0)
            ]
        ]

        let bounds = parseBoundsFromWindowDict(dict)
        #expect(bounds.minX == 1356.0)
        #expect(bounds.minY == 0.0)
        #expect(bounds.width == 354.0)
        #expect(bounds.height == 76.0)
    }
}

@Suite("Window level parsing")
struct WindowLevelTests {
    @Test("Parse valid window level")
    func parseValidLevel() {
        let dict: [String: Any] = [
            "kCGWindowLevel": NSNumber(value: 23)
        ]

        let level = parseWindowLevelFromDict(dict)
        #expect(level == 23)
    }

    @Test("Parse notification banner level")
    func parseBannerLevel() {
        let dict: [String: Any] = [
            "kCGWindowLevel": NSNumber(value: 25)
        ]

        let level = parseWindowLevelFromDict(dict)
        #expect(level == 25)
    }

    @Test("Missing level key returns zero")
    func missingLevelKey() {
        let dict: [String: Any] = [:]
        let level = parseWindowLevelFromDict(dict)
        #expect(level == 0)
    }

    @Test("Invalid level type returns zero")
    func invalidLevelType() {
        let dict: [String: Any] = [
            "kCGWindowLevel": "not a number"
        ]
        let level = parseWindowLevelFromDict(dict)
        #expect(level == 0)
    }
}

@Suite("Coordinate system conversion")
struct CoordinateFlipTests {
    @Test("Flip banner at top of screen to AppKit coordinates")
    func flipTopBanner() {
        let cgBounds = CGRect(x: 1356, y: 0, width: 354, height: 76)
        let screenHeight: CGFloat = 1107

        let appKitBounds = flipBoundsToAppKit(cgBounds, screenHeight: screenHeight)

        #expect(appKitBounds.minX == 1356)
        #expect(appKitBounds.minY == 1031)  // 1107 - 76 = 1031
        #expect(appKitBounds.width == 354)
        #expect(appKitBounds.height == 76)
    }

    @Test("Flip window in middle of screen")
    func flipMiddleWindow() {
        let cgBounds = CGRect(x: 100, y: 200, width: 300, height: 400)
        let screenHeight: CGFloat = 1000

        let appKitBounds = flipBoundsToAppKit(cgBounds, screenHeight: screenHeight)

        #expect(appKitBounds.minX == 100)
        #expect(appKitBounds.minY == 400)  // 1000 - (200 + 400) = 400
        #expect(appKitBounds.width == 300)
        #expect(appKitBounds.height == 400)
    }

    @Test("Flip zero bounds")
    func flipZeroBounds() {
        let cgBounds = CGRect.zero
        let screenHeight: CGFloat = 1107

        let appKitBounds = flipBoundsToAppKit(cgBounds, screenHeight: screenHeight)

        #expect(appKitBounds.minY == 1107)
        #expect(appKitBounds.width == 0)
        #expect(appKitBounds.height == 0)
    }
}
