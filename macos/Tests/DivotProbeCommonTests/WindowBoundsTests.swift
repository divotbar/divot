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

@Suite("Window layer parsing")
struct WindowLayerTests {
    @Test("Parse valid window layer")
    func parseValidLayer() {
        let dict: [String: Any] = [
            "kCGWindowLayer": NSNumber(value: 23)
        ]

        let layer = parseWindowLayerFromDict(dict)
        #expect(layer == 23)
    }

    @Test("Parse notification banner layer")
    func parseBannerLayer() {
        let dict: [String: Any] = [
            "kCGWindowLayer": NSNumber(value: 25)
        ]

        let layer = parseWindowLayerFromDict(dict)
        #expect(layer == 25)
    }

    @Test("Parse negative wallpaper layer")
    func parseNegativeWallpaperLayer() {
        let dict: [String: Any] = [
            "kCGWindowLayer": NSNumber(value: -2147483648)
        ]

        let layer = parseWindowLayerFromDict(dict)
        #expect(layer == -2147483648)
    }

    @Test("Missing layer key returns zero")
    func missingLayerKey() {
        let dict: [String: Any] = [:]
        let layer = parseWindowLayerFromDict(dict)
        #expect(layer == 0)
    }

    @Test("Invalid layer type returns zero")
    func invalidLayerType() {
        let dict: [String: Any] = [
            "kCGWindowLayer": "not a number"
        ]
        let layer = parseWindowLayerFromDict(dict)
        #expect(layer == 0)
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

@Suite("Window classification")
struct WindowClassificationTests {
    @Test("Classify NotificationCenter banner by owner name")
    func classifyNotificationBannerByOwner() {
        let dict: [String: Any] = [
            "kCGWindowOwnerName": "NotificationCenter"
        ]
        #expect(classifyWindow(dict) == .notificationBanner)
    }

    @Test("Classify Notification Center with space (case-insensitive)")
    func classifyNotificationCenterWithSpace() {
        let dict: [String: Any] = [
            "kCGWindowOwnerName": "notification center"
        ]
        #expect(classifyWindow(dict) == .notificationBanner)
    }

    @Test("Classify NotificationCenter by bundle ID")
    func classifyNotificationBannerByBundleID() {
        let dict: [String: Any] = [
            "kCGWindowOwnerName": "SomeOtherApp",
            "kCGWindowOwnerBundleIdentifier": "com.apple.notificationcenterui"
        ]
        #expect(classifyWindow(dict) == .notificationBanner)
    }

    @Test("Classify ControlCenter by owner name")
    func classifyControlCenterByOwner() {
        let dict: [String: Any] = [
            "kCGWindowOwnerName": "ControlCenter"
        ]
        #expect(classifyWindow(dict) == .controlCenter)
    }

    @Test("Classify ControlCenter by bundle ID")
    func classifyControlCenterByBundleID() {
        let dict: [String: Any] = [
            "kCGWindowOwnerName": "SystemUI",
            "kCGWindowOwnerBundleIdentifier": "com.apple.controlcenter"
        ]
        #expect(classifyWindow(dict) == .controlCenter)
    }

    @Test("Classify Divot window")
    func classifyDivotWindow() {
        let dict: [String: Any] = [
            "kCGWindowOwnerName": "Divot"
        ]
        #expect(classifyWindow(dict) == .divot)
    }

    @Test("Classify other window")
    func classifyOtherWindow() {
        let dict: [String: Any] = [
            "kCGWindowOwnerName": "Finder"
        ]
        #expect(classifyWindow(dict) == .other)
    }

    @Test("Classify window without owner name")
    func classifyWindowNoName() {
        let dict: [String: Any] = [:]
        #expect(classifyWindow(dict) == .other)
    }
}

@Suite("Window snapshot and diffing")
struct WindowSnapshotTests {
    @Test("Create snapshot from valid window dictionary")
    func createValidSnapshot() {
        let dict: [String: Any] = [
            "kCGWindowNumber": NSNumber(value: 123),
            "kCGWindowLayer": NSNumber(value: 25),
            "kCGWindowBounds": [
                "X": NSNumber(value: 100.0),
                "Y": NSNumber(value: 200.0),
                "Width": NSNumber(value: 300.0),
                "Height": NSNumber(value: 400.0)
            ]
        ]

        let snapshot = WindowSnapshot.from(dict)
        #expect(snapshot != nil)
        #expect(snapshot?.windowID == 123)
        #expect(snapshot?.layer == 25)
        #expect(snapshot?.bounds.minX == 100.0)
    }

    @Test("Create snapshot returns nil without window number")
    func createSnapshotNoWindowNumber() {
        let dict: [String: Any] = [
            "kCGWindowLayer": NSNumber(value: 25)
        ]

        let snapshot = WindowSnapshot.from(dict)
        #expect(snapshot == nil)
    }

    @Test("Detect new windows")
    func detectNewWindows() {
        let previous = [
            WindowSnapshot(windowID: 1, layer: 20, bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]

        let current = [
            WindowSnapshot(windowID: 1, layer: 20, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
            WindowSnapshot(windowID: 2, layer: 25, bounds: CGRect(x: 200, y: 200, width: 100, height: 100))
        ]

        let changes = diffWindowSnapshots(previous: previous, current: current)
        #expect(changes.new == [2])
        #expect(changes.boundsChanged.isEmpty)
        #expect(changes.layerChanged.isEmpty)
    }

    @Test("Detect bounds change")
    func detectBoundsChange() {
        let previous = [
            WindowSnapshot(windowID: 1, layer: 20, bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]

        let current = [
            WindowSnapshot(windowID: 1, layer: 20, bounds: CGRect(x: 50, y: 50, width: 100, height: 100))
        ]

        let changes = diffWindowSnapshots(previous: previous, current: current)
        #expect(changes.new.isEmpty)
        #expect(changes.boundsChanged == [1])
        #expect(changes.layerChanged.isEmpty)
    }

    @Test("Detect layer change")
    func detectLayerChange() {
        let previous = [
            WindowSnapshot(windowID: 1, layer: 20, bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]

        let current = [
            WindowSnapshot(windowID: 1, layer: 25, bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]

        let changes = diffWindowSnapshots(previous: previous, current: current)
        #expect(changes.new.isEmpty)
        #expect(changes.boundsChanged.isEmpty)
        #expect(changes.layerChanged == [1])
    }

    @Test("Detect multiple changes")
    func detectMultipleChanges() {
        let previous = [
            WindowSnapshot(windowID: 1, layer: 20, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
            WindowSnapshot(windowID: 2, layer: 25, bounds: CGRect(x: 200, y: 200, width: 100, height: 100))
        ]

        let current = [
            WindowSnapshot(windowID: 1, layer: 22, bounds: CGRect(x: 10, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 3, layer: 30, bounds: CGRect(x: 300, y: 300, width: 100, height: 100))
        ]

        let changes = diffWindowSnapshots(previous: previous, current: current)
        #expect(changes.new == [3])
        #expect(changes.boundsChanged == [1])
        #expect(changes.layerChanged == [1])
    }
}

@Suite("Find Divot panel")
struct FindDivotPanelTests {
    @Test("Find Divot panel at top edge")
    func findDivotAtTop() {
        let windowList: [[String: Any]] = [
            [
                "kCGWindowOwnerName": "Finder",
                "kCGWindowBounds": [
                    "X": NSNumber(value: 0.0),
                    "Y": NSNumber(value: 100.0),
                    "Width": NSNumber(value: 1710.0),
                    "Height": NSNumber(value: 800.0)
                ]
            ],
            [
                "kCGWindowOwnerName": "Divot",
                "kCGWindowBounds": [
                    "X": NSNumber(value: 0.0),
                    "Y": NSNumber(value: 0.0),
                    "Width": NSNumber(value: 1710.0),
                    "Height": NSNumber(value: 33.0)
                ]
            ]
        ]

        let panel = findDivotPanelWindow(windowList)
        #expect(panel != nil)
        #expect((panel?["kCGWindowOwnerName"] as? String) == "Divot")
    }

    @Test("Find no Divot panel when none present")
    func findNoDivotPanel() {
        let windowList: [[String: Any]] = [
            [
                "kCGWindowOwnerName": "Finder",
                "kCGWindowBounds": [
                    "X": NSNumber(value: 0.0),
                    "Y": NSNumber(value: 100.0),
                    "Width": NSNumber(value: 1710.0),
                    "Height": NSNumber(value: 800.0)
                ]
            ]
        ]

        let panel = findDivotPanelWindow(windowList)
        #expect(panel == nil)
    }

    @Test("Find Divot panel but not when far from top")
    func findNoDivotPanelWhenFarFromTop() {
        let windowList: [[String: Any]] = [
            [
                "kCGWindowOwnerName": "Divot",
                "kCGWindowBounds": [
                    "X": NSNumber(value: 0.0),
                    "Y": NSNumber(value: 100.0),
                    "Width": NSNumber(value: 1710.0),
                    "Height": NSNumber(value: 33.0)
                ]
            ]
        ]

        let panel = findDivotPanelWindow(windowList)
        #expect(panel == nil)
    }
}
