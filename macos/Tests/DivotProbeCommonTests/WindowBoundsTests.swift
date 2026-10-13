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
