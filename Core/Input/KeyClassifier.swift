import Foundation

public struct KeyClassifier {
    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    private let navigationKeyCodes: Set<UInt16> = [115, 116, 119, 121, 123, 124, 125, 126]
    private let functionKeyCodes: Set<UInt16> = [64, 79, 80, 90, 96, 97, 98, 99, 100, 101, 103, 105, 107, 109, 111, 113, 114, 118, 120, 122]

    public init() {}

    public func classify(_ keyEvent: KeyEvent) -> KeyClass {
        switch keyEvent.keyCode {
        case 49:
            return .space
        case 36, 76:
            return .return
        case 51, 117:
            return .delete
        default:
            break
        }

        if modifierKeyCodes.contains(keyEvent.keyCode) {
            return .modifier
        }

        if navigationKeyCodes.contains(keyEvent.keyCode) {
            return .navigation
        }

        if functionKeyCodes.contains(keyEvent.keyCode) {
            return .function
        }

        return .standard
    }
}
