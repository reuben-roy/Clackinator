import Foundation

public enum AppChannel: String, CaseIterable, Sendable {
    case direct
    case appStore

    public var bundleIdentifier: String {
        switch self {
        case .direct:
            return "com.clackinator.direct"
        case .appStore:
            return "com.clackinator.appstore"
        }
    }

    public var displayName: String {
        switch self {
        case .direct:
            return "Direct / Homebrew"
        case .appStore:
            return "Mac App Store"
        }
    }

    public var prefersEventTap: Bool {
        self == .direct
    }
}

public enum KeyboardCaptureBackend: String, Sendable {
    case eventMonitor
    case eventTap

    public var title: String {
        switch self {
        case .eventMonitor:
            return "Event Monitor"
        case .eventTap:
            return "Listen-Only Event Tap"
        }
    }

    public var summary: String {
        switch self {
        case .eventMonitor:
            return "Uses AppKit event monitors. Works inside Clackinator and can hear other apps after keyboard access is granted."
        case .eventTap:
            return "Uses a listen-only Quartz event tap for tighter global capture in the direct build."
        }
    }
}
