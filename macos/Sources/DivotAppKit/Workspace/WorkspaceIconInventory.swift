import AppKit
import DivotCore

/// Resolves a bundle identifier to an app icon for the workspace indicators.
///
/// Icons are looked up once per `(bundle, size)` and cached, so the bar never
/// re-reads the filesystem on every layout pass. Missing apps resolve to `nil`;
/// the renderer falls back to text rather than blocking.
@MainActor
public protocol WorkspaceIconProviding: AnyObject {
    func icon(for bundleID: String, pointSize: CGFloat) -> NSImage?
}

/// `NSWorkspace`-backed icon inventory with a per-key cache.
@MainActor
public final class WorkspaceIconInventory: WorkspaceIconProviding {
    private struct Key: Hashable {
        let bundleID: String
        let pointSize: Int
    }

    private var cache: [Key: NSImage] = [:]

    public init() {}

    public func icon(for bundleID: String, pointSize: CGFloat) -> NSImage? {
        let trimmed = bundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, pointSize > 0 else { return nil }

        let key = Key(bundleID: trimmed, pointSize: Int(pointSize.rounded()))
        if let cached = cache[key] { return cached }

        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: trimmed) else { return nil }
        let image = workspace.icon(forFile: url.path)
        image.size = NSSize(width: pointSize, height: pointSize)
        cache[key] = image
        return image
    }

    /// Number of resolved icons, for diagnostics and tests.
    public var cachedIconCount: Int { cache.count }

    /// Drop every cached icon, e.g. after appearance or scale changes.
    public func invalidate() {
        cache.removeAll()
    }
}
