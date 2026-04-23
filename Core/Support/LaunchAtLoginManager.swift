import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginManager {
    public static let shared = LaunchAtLoginManager()

    private init() {}

    public func isEnabled() -> Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    public func update(enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
