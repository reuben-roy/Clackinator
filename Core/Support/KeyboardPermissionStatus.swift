import Foundation

public enum KeyboardPermissionStatus: String, Sendable {
    case unknown
    case denied
    case granted

    public var title: String {
        switch self {
        case .unknown:
            return "Keyboard Access Needed"
        case .denied:
            return "Keyboard Access Denied"
        case .granted:
            return "Keyboard Access Granted"
        }
    }

    public var summary: String {
        switch self {
        case .unknown:
            return "Grant keyboard listening access so KeyTok can react to typing across your Mac."
        case .denied:
            return "KeyTok can only react inside its own window until keyboard listening access is restored."
        case .granted:
            return "Global key listening is active."
        }
    }
}
