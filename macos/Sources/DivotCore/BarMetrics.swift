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
    /// Default row height in points, matched to the macOS menu bar's compact
    /// rhythm. This is the one place the default height is set.
    public var height: CGFloat
    /// Gap between adjacent items in one group.
    public var itemSpacing: CGFloat
    /// Leading/trailing inset of each group inside its panel, so content never
    /// runs edge-to-edge and the left/right groups keep consistent spacing.
    public var rowInset: CGFloat
    /// SF Symbol (icon) point size.
    public var iconSize: CGFloat
    /// Gap between an item's icon and its text.
    public var iconSpacing: CGFloat
    /// Font size for status item text.
    public var textFontSize: CGFloat
    /// Font size for workspace chips and the current-program label.
    public var chipFontSize: CGFloat
    /// Gap between workspace chips.
    public var chipSpacing: CGFloat

    public init(height: CGFloat = 24,
                itemSpacing: CGFloat = 8,
                rowInset: CGFloat = 6,
                iconSize: CGFloat = 14,
                iconSpacing: CGFloat = 4,
                textFontSize: CGFloat = 12,
                chipFontSize: CGFloat = 11,
                chipSpacing: CGFloat = 6) {
        self.height = height
        self.itemSpacing = itemSpacing
        self.rowInset = rowInset
        self.iconSize = iconSize
        self.iconSpacing = iconSpacing
        self.textFontSize = textFontSize
        self.chipFontSize = chipFontSize
        self.chipSpacing = chipSpacing
    }

    public static let `default` = BarMetrics()

    // MARK: Width measurement

    /// The width one item occupies: its icon (plus the icon/text gap) and the
    /// measured text. `textWidth` must come from a measurement that includes the
    /// label cell's own padding, or the text will ellipsize when it is drawn.
    public func itemWidth(hasIcon: Bool, textWidth: CGFloat) -> CGFloat {
        let iconWidth = hasIcon ? iconSize + iconSpacing : 0
        return iconWidth + max(0, textWidth.isFinite ? textWidth : 0)
    }

    /// Total width a group of items needs, including the gaps between them.
    public func groupWidth(_ itemWidths: [CGFloat]) -> CGFloat {
        guard itemWidths.count > 1 else { return itemWidths.first.map { max(0, $0) } ?? 0 }
        let content = itemWidths.reduce(0) { $0 + max(0, $1.isFinite ? $1 : 0) }
        return content + itemSpacing * CGFloat(itemWidths.count - 1)
    }

    /// True when the group fits inside `available` without shrinking any item,
    /// which is the condition for "no label must truncate".
    public func fits(_ itemWidths: [CGFloat], available: CGFloat) -> Bool {
        groupWidth(itemWidths) <= available + 0.5
    }
}
