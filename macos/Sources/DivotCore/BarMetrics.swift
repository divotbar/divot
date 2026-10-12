import Foundation
import CoreGraphics

/// The single source of truth for the bar's compact menu-bar rhythm.
///
/// Every item is sized from these values. No widget hard-codes its own height,
/// padding, or font, and `BarGeometry` / `BarContentPolicy` read their default
/// row height from `BarMetrics.default.height` so the row height cannot drift
/// between the pure geometry and the rendered content. The pure width helpers
/// here are the tested measurement boundary: the AppKit views supply a measured
/// text width, and this type owns the arithmetic (plus the no-truncation
/// guarantee) so it is verifiable without a window server.
public struct BarMetrics: Equatable, Sendable {
    /// Default row height in points, matched to the camera-housing band so the
    /// row lines up with the notch: 32 pt is the ~64 px (2×) housing height.
    /// This is the one place the default height is set; `layout.height` in the
    /// configuration document still overrides it.
    public var height: CGFloat
    /// Gap between adjacent items in the right group. Defaults to the uniform
    /// 8 pt item rhythm from before #0054.
    public var rightItemSpacing: CGFloat
    /// Gap between adjacent items in the left group. Defaults to the same 8 pt
    /// as the right group, restoring the pre-#0054 uniform rhythm (#0060).
    public var leftItemSpacing: CGFloat
    /// Leading/trailing inset of each group inside its panel, so content never
    /// runs edge-to-edge and the left/right groups keep consistent spacing.
    public var rowInset: CGFloat
    /// SF Symbol (icon) point size for status items.
    public var iconSize: CGFloat
    /// Point size for the app icons drawn on the left: the workspace-chip app
    /// attachments and the Divot mark. Defaults to `iconSize`, so the app icons
    /// match the status icons until the configuration overrides it (#0052).
    public var appIconSize: CGFloat
    /// The SF Symbol point size for the battery, network and volume status
    /// icons. It is the bar's icon size, so the three symbols follow the text
    /// size setting; the default is 16 pt, the native menu-bar symbol size
    /// (#0057). The other items keep their compact square status-icon box.
    public var statusSymbolPointSize: CGFloat { iconSize }
    /// Gap between an item's icon and its text.
    public var iconSpacing: CGFloat
    /// Font size for status item text.
    public var textFontSize: CGFloat
    /// Font size for workspace chips and the current-program label.
    public var chipFontSize: CGFloat
    /// Gap between workspace chips.
    public var chipSpacing: CGFloat
    /// Family name for the bar's text, or `nil` for the system font. An
    /// uninstalled name is resolved to the system font at render time, so the
    /// stored value never breaks the bar.
    public var fontFamily: String?

    public init(height: CGFloat = 32,
                rightItemSpacing: CGFloat = 8,
                leftItemSpacing: CGFloat = 8,
                rowInset: CGFloat = 6,
                iconSize: CGFloat = 16,
                appIconSize: CGFloat = 16,
                iconSpacing: CGFloat = 4,
                textFontSize: CGFloat = 14,
                chipFontSize: CGFloat = 13,
                chipSpacing: CGFloat = 6,
                fontFamily: String? = nil) {
        self.height = height
        self.rightItemSpacing = rightItemSpacing
        self.leftItemSpacing = leftItemSpacing
        self.rowInset = rowInset
        self.iconSize = iconSize
        self.appIconSize = appIconSize
        self.iconSpacing = iconSpacing
        self.textFontSize = textFontSize
        self.chipFontSize = chipFontSize
        self.chipSpacing = chipSpacing
        self.fontFamily = fontFamily
    }

    public static let `default` = BarMetrics()

    /// The default text size, larger than the original fixed 12 pt so the bar
    /// reads comfortably on the maintainer's display (#0022).
    public static let defaultTextSize: CGFloat = 14

    /// Padding around a bar item's content when chips are drawn (#0030).
    /// Shared by the status item chips and the workspace chips so the two
    /// match (#0052).
    public static let chipPadding: CGFloat = 4

    /// The size of a chip's box around its content. Chip chrome adds
    /// `chipPadding` on every side, so the selected workspace chip and the
    /// right-side status chips share one shape and size at any text size
    /// (#0059). This is the single tested metric the AppKit views consume
    /// rather than each adding its own padding.
    public func chipSize(contentWidth: CGFloat, contentHeight: CGFloat) -> CGSize {
        let width = contentWidth.isFinite ? max(0, contentWidth) : 0
        let height = contentHeight.isFinite ? max(0, contentHeight) : 0
        return CGSize(width: width + Self.chipPadding * 2,
                      height: height + Self.chipPadding * 2)
    }

    /// Fixed inset between the rightmost item and the right edge of the screen,
    /// so the macOS camera-in-use indicator never overlaps the right group.
    /// #0054 misread the request as a 17 pt item gap; #0060 restores the 8 pt
    /// item rhythm and keeps 17 pt as this edge inset instead.
    public static let rightEdgeInset: CGFloat = 17

    /// Derive the whole render rhythm from a configured text size.
    ///
    /// Icon and chip sizes are expressed relative to the text so the row stays
    /// in proportion as the text grows: the icon is two points larger than the
    /// text and the workspace chip one point smaller. Heights and gaps are
    /// passed through, so a layout change never disturbs the type scale.
    public static func scaled(textSize: CGFloat,
                              height: CGFloat = BarMetrics.default.height,
                              rowInset: CGFloat = BarMetrics.default.rowInset,
                              fontFamily: String? = nil,
                              appIconSize: CGFloat? = nil,
                              rightItemSpacing: CGFloat = BarMetrics.default.rightItemSpacing,
                              leftItemSpacing: CGFloat = BarMetrics.default.leftItemSpacing) -> BarMetrics {
        let size = (textSize.isFinite ? textSize : defaultTextSize).rounded()
        let clamped = max(1, size)
        // The app icon defaults to the status icon size so the left app icons
        // match the right-side icons until the configuration overrides it
        // (#0052). A non-finite override falls back to that default.
        let requestedAppIcon = appIconSize.map { $0.isFinite ? $0 : clamped + 2 } ?? (clamped + 2)
        return BarMetrics(height: height,
                          rightItemSpacing: rightItemSpacing,
                          leftItemSpacing: leftItemSpacing,
                          rowInset: rowInset,
                          iconSize: clamped + 2,
                          appIconSize: max(1, requestedAppIcon.rounded()),
                          textFontSize: clamped,
                          chipFontSize: max(1, clamped - 1),
                          fontFamily: fontFamily)
    }

    // MARK: Width measurement

    /// The width one item occupies: its icon (plus the icon/text gap) and the
    /// measured text. `textWidth` must come from a measurement that includes the
    /// label cell's own padding, or the text will ellipsize when it is drawn.
    public func itemWidth(hasIcon: Bool, textWidth: CGFloat) -> CGFloat {
        let iconWidth = hasIcon ? iconSize + iconSpacing : 0
        return iconWidth + max(0, textWidth.isFinite ? textWidth : 0)
    }

    /// Total width a group of items needs, including the gaps between them.
    /// The caller passes the side's spacing so the left and right rhythms are
    /// both measured with the value the renderer draws (#0054).
    public func groupWidth(_ itemWidths: [CGFloat], spacing: CGFloat) -> CGFloat {
        guard itemWidths.count > 1 else { return itemWidths.first.map { max(0, $0) } ?? 0 }
        let content = itemWidths.reduce(0) { $0 + max(0, $1.isFinite ? $1 : 0) }
        return content + spacing * CGFloat(itemWidths.count - 1)
    }

    /// True when the group fits inside `available` without shrinking any item,
    /// which is the condition for "no label must truncate".
    public func fits(_ itemWidths: [CGFloat], available: CGFloat, spacing: CGFloat) -> Bool {
        groupWidth(itemWidths, spacing: spacing) <= available + 0.5
    }
}
