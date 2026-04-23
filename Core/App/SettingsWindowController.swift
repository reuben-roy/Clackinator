import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    public var onClose: (() -> Void)?

    public init(coordinator: KeyTokCoordinator) {
        let hostingController = NSHostingController(rootView: SettingsWindowView(coordinator: coordinator))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "KeyTok"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 560, height: 620))
        window.minSize = NSSize(width: 520, height: 540)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func present(activating: Bool = true) {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)

        if activating {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    public func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
