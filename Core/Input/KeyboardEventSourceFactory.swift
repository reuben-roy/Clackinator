import Foundation

@MainActor
public enum KeyboardEventSourceFactory {
    public static func make(
        channel: AppChannel,
        permissionStatus: KeyboardPermissionStatus,
        onKeyEvent: @escaping (KeyEvent) -> Void
    ) -> any KeyboardEventSource {
        if channel.prefersEventTap, permissionStatus == .granted {
            let eventTap = EventTapKeyboardEventSource()
            eventTap.onKeyEvent = onKeyEvent

            if eventTap.start() {
                return eventTap
            }

            KeyTokLogger.input.warning("Falling back to NSEvent monitors after event tap initialization failed.")
        }

        let monitor = MonitorKeyboardEventSource()
        monitor.onKeyEvent = onKeyEvent
        _ = monitor.start()
        return monitor
    }
}
