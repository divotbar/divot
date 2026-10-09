import Foundation
import ServiceManagement

/// Launch-at-login control, behind a protocol so the settings view model can be
/// tested without registering a real login item.
@MainActor
public protocol LoginItemControlling: AnyObject {
    /// Whether the app is currently registered to open at login.
    var isEnabled: Bool { get }
    /// A short, honest description of the current state (including
    /// "waiting for approval in System Settings").
    var statusDescription: String { get }
    /// Register or unregister. Returns `false` when the system refused.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool
}

/// The real login item, backed by `SMAppService.mainApp`.
///
/// This is the documented public API for a app managing its own login item; it
/// needs no privileged helper and no private API.
@MainActor
public final class SMAppServiceLoginItem: LoginItemControlling {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Divot opens at login."
        case .notRegistered: return "Divot does not open at login."
        case .requiresApproval: return "Waiting for approval in System Settings › General › Login Items."
        case .notFound: return "The login item is unavailable for this build."
        @unknown default: return "The login item status is unknown."
        }
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
