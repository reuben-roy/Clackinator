import AppKit
import Foundation

public final class MonitorKeyboardEventSource: KeyboardEventSource {
    public let backend: KeyboardCaptureBackend = .eventMonitor
    public var onKeyEvent: ((KeyEvent) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    public init() {}

    @discardableResult
    public func start() -> Bool {
        guard globalMonitor == nil, localMonitor == nil else {
            return true
        }

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }

        return true
    }

    public func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard let keyEvent = translate(event) else {
            return
        }

        onKeyEvent?(keyEvent)
    }

    private func translate(_ event: NSEvent) -> KeyEvent? {
        switch event.type {
        case .keyDown:
            return KeyEvent(
                keyCode: event.keyCode,
                phase: .down,
                isRepeat: event.isARepeat,
                modifiers: Self.modifiers(from: event.modifierFlags),
                timestamp: event.timestamp
            )
        case .keyUp:
            return KeyEvent(
                keyCode: event.keyCode,
                phase: .up,
                isRepeat: false,
                modifiers: Self.modifiers(from: event.modifierFlags),
                timestamp: event.timestamp
            )
        case .flagsChanged:
            return KeyEvent(
                keyCode: event.keyCode,
                phase: Self.phaseForModifierEvent(event),
                isRepeat: false,
                modifiers: Self.modifiers(from: event.modifierFlags),
                timestamp: event.timestamp
            )
        default:
            return nil
        }
    }

    private static func phaseForModifierEvent(_ event: NSEvent) -> KeyPhase {
        switch event.keyCode {
        case 54, 55:
            return event.modifierFlags.contains(.command) ? .down : .up
        case 58, 61:
            return event.modifierFlags.contains(.option) ? .down : .up
        case 59, 62:
            return event.modifierFlags.contains(.control) ? .down : .up
        case 56, 60:
            return event.modifierFlags.contains(.shift) ? .down : .up
        case 57:
            return event.modifierFlags.contains(.capsLock) ? .down : .up
        case 63:
            return event.modifierFlags.contains(.function) ? .down : .up
        default:
            return .down
        }
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> KeyModifierSet {
        var modifierSet: KeyModifierSet = []

        if flags.contains(.command) {
            modifierSet.insert(.command)
        }
        if flags.contains(.option) {
            modifierSet.insert(.option)
        }
        if flags.contains(.control) {
            modifierSet.insert(.control)
        }
        if flags.contains(.shift) {
            modifierSet.insert(.shift)
        }
        if flags.contains(.capsLock) {
            modifierSet.insert(.capsLock)
        }
        if flags.contains(.function) {
            modifierSet.insert(.function)
        }

        return modifierSet
    }
}
