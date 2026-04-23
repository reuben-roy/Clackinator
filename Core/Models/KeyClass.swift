import Foundation

public enum KeyClass: String, CaseIterable, Identifiable, Sendable {
    case standard
    case space
    case `return`
    case delete
    case modifier
    case navigation
    case function

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .space:
            return "Space"
        case .return:
            return "Return"
        case .delete:
            return "Delete"
        case .modifier:
            return "Modifier"
        case .navigation:
            return "Navigation"
        case .function:
            return "Function"
        }
    }
}
