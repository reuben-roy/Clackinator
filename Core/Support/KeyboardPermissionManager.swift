import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class KeyboardPermissionManager {
    public static let shared = KeyboardPermissionManager()

    private init() {}

    public func preflight() -> Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    public func requestAccess() -> Bool {
        CGRequestListenEventAccess()
    }

    public func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
