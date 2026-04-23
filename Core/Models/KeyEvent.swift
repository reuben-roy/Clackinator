import Foundation

public enum KeyPhase: String, CaseIterable, Sendable {
    case down
    case up
}

public struct KeyModifierSet: OptionSet, Hashable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifierSet(rawValue: 1 << 0)
    public static let option = KeyModifierSet(rawValue: 1 << 1)
    public static let control = KeyModifierSet(rawValue: 1 << 2)
    public static let shift = KeyModifierSet(rawValue: 1 << 3)
    public static let capsLock = KeyModifierSet(rawValue: 1 << 4)
    public static let function = KeyModifierSet(rawValue: 1 << 5)
}

public struct KeyEvent: Hashable, Sendable {
    public let keyCode: UInt16
    public let phase: KeyPhase
    public let isRepeat: Bool
    public let modifiers: KeyModifierSet
    public let timestamp: TimeInterval

    public init(
        keyCode: UInt16,
        phase: KeyPhase,
        isRepeat: Bool,
        modifiers: KeyModifierSet,
        timestamp: TimeInterval
    ) {
        self.keyCode = keyCode
        self.phase = phase
        self.isRepeat = isRepeat
        self.modifiers = modifiers
        self.timestamp = timestamp
    }
}
