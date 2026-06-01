import AppKit
import ClackinatorCore

@MainActor
final class DirectAppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = ClackinatorCoordinator(channel: .direct)

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
