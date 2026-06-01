import AppKit
import ClackinatorCore

@MainActor
final class AppStoreAppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = ClackinatorCoordinator(channel: .appStore)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator.refreshPermissionStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.shutdown()
    }
}
