import AppKit

/// The Divot mark used for the menu-bar status item.
///
/// The artwork is the landing-page mark (`site/public/mark.svg`) with its cream
/// tile dropped: only the glyph is kept, as an alpha mask, so it can be shipped
/// as a template image. The system tints a template image to match the menu bar,
/// so one asset follows both the light and dark appearance. The glyph keeps the
/// landing mark's geometry and square proportion, scaled uniformly to fill the
/// icon so the shape still reads at menu-bar size.
public enum DivotMenuBarMark {
    /// The mark as a template image, or `nil` when the bundled asset is missing.
    ///
    /// The caller sizes the result to the menu bar; `pointSize` is the square
    /// edge in points. A `nil` return lets the caller fall back rather than show
    /// a blank item.
    @MainActor
    public static func image(pointSize: CGFloat = 18) -> NSImage? {
        guard let url = Bundle.module.url(forResource: "menubar-mark", withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: pointSize, height: pointSize)
        return image
    }
}
