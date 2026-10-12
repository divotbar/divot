import Foundation
import CoreGraphics
import Testing
@testable import DivotCore

// MARK: - Single source of truth

@Test func defaultBarHeightComesFromOnePlace() {
    // The row height is defined once in `BarMetrics` and read by both the pure
    // geometry and the content policy, so it cannot drift between them. 32 pt
    // matches the ~64 px (2x) camera-housing band so the row lines up with the
    // notch (#0021).
    #expect(BarMetrics.default.height == 32)
    let geometry = BarGeometry(screen: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    #expect(geometry.left.height == BarMetrics.default.height)
    let policy = BarContentPolicy()
    #expect(policy.height == BarMetrics.default.height)
}

@Test func aCustomHeightFlowsThroughPolicyAndGeometry() {
    let policy = BarContentPolicy(height: 30, clearance: 10)
    let screen = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                safeAreaTop: 0)
    let placement = BarPlacementResolver.placement(screen: screen, visibility: .hidden, policy: policy)
    #expect(placement?.geometry.left.height == 30)
}

// MARK: - Width measurement

@Test func itemWidthAddsIconAndGapOnlyWhenThereIsAnIcon() {
    let m = BarMetrics()
    #expect(m.itemWidth(hasIcon: false, textWidth: 40) == 40)
    #expect(m.itemWidth(hasIcon: true, textWidth: 40) == m.iconSize + m.iconSpacing + 40)
    // A negative measurement never produces a negative item.
    #expect(m.itemWidth(hasIcon: true, textWidth: -5) == m.iconSize + m.iconSpacing)
    // A non-finite measurement is treated as no text rather than poisoning the row.
    #expect(m.itemWidth(hasIcon: false, textWidth: .nan) == 0)
}

@Test func groupWidthIncludesTheGapsBetweenItems() {
    let m = BarMetrics()
    #expect(m.groupWidth([], spacing: m.rightItemSpacing) == 0)
    #expect(m.groupWidth([40], spacing: m.rightItemSpacing) == 40)
    #expect(m.groupWidth([40, 30, 20], spacing: m.rightItemSpacing) == 90 + m.rightItemSpacing * 2)
    #expect(m.groupWidth([40, 30, 20], spacing: m.leftItemSpacing) == 90 + m.leftItemSpacing * 2)
}

@Test func fitsIsTheNoTruncationTest() {
    let m = BarMetrics()
    let widths: [CGFloat] = [40, 120, 40]
    let needed = m.groupWidth(widths, spacing: m.rightItemSpacing)
    #expect(m.fits(widths, available: needed, spacing: m.rightItemSpacing))
    #expect(m.fits(widths, available: needed + 10, spacing: m.rightItemSpacing))
    #expect(!m.fits(widths, available: needed - 1, spacing: m.rightItemSpacing))
}

// MARK: - Item spacing and the front-app gap (#0054)

@Test func defaultItemSpacingIsSeventeenOnTheRightAndHalfOnTheLeft() {
    // The maintainer's chosen rhythm: 17 pt between right-side items, and a
    // left gap that defaults to half of it so the Divot mark and workspaces do
    // not look too far apart.
    #expect(BarMetrics.default.rightItemSpacing == 17)
    #expect(BarMetrics.default.leftItemSpacing == BarMetrics.default.rightItemSpacing / 2)
    #expect(BarMetrics.default.leftItemSpacing == 8.5)
    // The front app keeps its own fixed gap, independent of either side.
    #expect(BarMetrics.frontAppSpacing == 12)
}

@Test func scaledCarriesTheConfiguredSideSpacing() {
    let metrics = BarMetrics.scaled(textSize: 14, rightItemSpacing: 20, leftItemSpacing: 10)
    #expect(metrics.rightItemSpacing == 20)
    #expect(metrics.leftItemSpacing == 10)
    // The default left is half the default right when the caller passes nothing.
    let defaults = BarMetrics.scaled(textSize: 14)
    #expect(defaults.rightItemSpacing == 17)
    #expect(defaults.leftItemSpacing == 8.5)
}

// MARK: - Chip size (#0059)

@Test func chipSizePadsEverySideSoEveryChipSharesOneShape() {
    // The selected workspace chip and the right-side status chips both pad their
    // content through `chipSize`, so they are the same size at any text scale.
    // Before #0059 the workspace chip added the padding to its width only and
    // stayed visibly shorter than the right-side chip.
    let m = BarMetrics()
    let size = m.chipSize(contentWidth: 40, contentHeight: 16)
    #expect(size.width == 40 + BarMetrics.chipPadding * 2)
    #expect(size.height == 16 + BarMetrics.chipPadding * 2)
    // Padding is symmetric on both axes, so width and height grow together.
    #expect(size.width - 40 == size.height - 16)
    #expect(size.width - 40 == BarMetrics.chipPadding * 2)
}

@Test func chipSizeGuardsNonFiniteAndNegativeContent() {
    let m = BarMetrics()
    let guarded = m.chipSize(contentWidth: .nan, contentHeight: -4)
    #expect(guarded.width == BarMetrics.chipPadding * 2)
    #expect(guarded.height == BarMetrics.chipPadding * 2)
    let infinite = m.chipSize(contentWidth: .infinity, contentHeight: .infinity)
    #expect(infinite.width == BarMetrics.chipPadding * 2)
    #expect(infinite.height == BarMetrics.chipPadding * 2)
}

// MARK: - Text size and proportional icons (#0022)

@Test func defaultTextSizeIsLargerThanTheOldFixedSize() {
    // The default is the single knob for the bar's type; the original fixed
    // 12 pt text was too small on the maintainer's display.
    #expect(BarMetrics.default.textFontSize == BarMetrics.defaultTextSize)
    #expect(BarMetrics.defaultTextSize > 12)
    #expect(BarMetrics.default.chipFontSize < BarMetrics.default.textFontSize)
    #expect(BarMetrics.default.iconSize > BarMetrics.default.textFontSize)
}

@Test func iconSizeFollowsTextSizeSoTheTwoStayInProportion() {
    let small = BarMetrics.scaled(textSize: 11)
    let large = BarMetrics.scaled(textSize: 18)
    #expect(large.textFontSize > small.textFontSize)
    #expect(large.iconSize > small.iconSize)
    #expect(large.chipFontSize > small.chipFontSize)
    // The offsets are fixed, so the icon never drifts relative to the text.
    #expect(large.iconSize - large.textFontSize == small.iconSize - small.textFontSize)
    #expect(small.iconSize == small.textFontSize + 2)
    #expect(small.chipFontSize == small.textFontSize - 1)
}

@Test func appIconSizeDefaultsToTheStatusIconSize() {
    // The app icons on the left match the right-side status icons until the
    // configuration overrides the size (#0052).
    let metrics = BarMetrics.scaled(textSize: 14)
    #expect(metrics.appIconSize == metrics.iconSize)
    #expect(BarMetrics.default.appIconSize == BarMetrics.default.iconSize)

    // An explicit size is honored, and a non-finite one falls back to the
    // status icon size instead of poisoning layout.
    #expect(BarMetrics.scaled(textSize: 14, appIconSize: 22).appIconSize == 22)
    #expect(BarMetrics.scaled(textSize: 14, appIconSize: .nan).appIconSize == 16)
}

@Test func scaledCarriesTheConfiguredHeightPaddingAndFont() {
    let metrics = BarMetrics.scaled(textSize: 16, height: 30, rowInset: 10, fontFamily: "Helvetica")
    #expect(metrics.height == 30)
    #expect(metrics.rowInset == 10)
    #expect(metrics.textFontSize == 16)
    #expect(metrics.iconSize == 18)
    #expect(metrics.fontFamily == "Helvetica")
    // A non-finite size falls back to the default rather than poisoning layout.
    #expect(BarMetrics.scaled(textSize: .nan).textFontSize == BarMetrics.defaultTextSize)
}

// MARK: - Default layout on the maintainer's notched display
/// The 0009/0015 notched built-in display: two auxiliary top regions beside the
/// camera housing. Each side must have room for its default group's measured
/// labels, and the split must keep both groups clear of the housing.
@Test func defaultGroupsFitAndClearTheNotchHousing() {
    let m = BarMetrics()
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1107)
    let geometry = BarGeometry(screen: screen,
                               topLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                               topRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
    // The notch gap is now fixed at zero; bar hugs the housing (#0028)
    #expect(geometry.left.maxX == 763)
    #expect(geometry.right.minX == 948)

    // Representative measured item widths for the default groups at the compact
    // font (a status label never exceeds the long localized clock string).
    let widestStatusWidth = m.itemWidth(hasIcon: false, textWidth: 140)
    let rightWidths: [CGFloat] = [
        m.itemWidth(hasIcon: true, textWidth: 40),   // battery "100%"
        widestStatusWidth,                            // clock/date
        m.itemWidth(hasIcon: true, textWidth: 0),     // network (icon only)
        m.itemWidth(hasIcon: true, textWidth: 45)     // volume "Muted"
    ]
    #expect(m.fits(rightWidths, available: geometry.right.width - m.rowInset * 2,
                   spacing: m.rightItemSpacing))

    // The left group's fixed content (the frontmost app) fits beside the notch.
    let leftFixed = m.itemWidth(hasIcon: false, textWidth: 120)
    #expect(leftFixed <= geometry.left.width - m.rowInset * 2)
}
