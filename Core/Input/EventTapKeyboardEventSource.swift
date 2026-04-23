import CoreGraphics
import Foundation
import QuartzCore

public final class EventTapKeyboardEventSource: KeyboardEventSource {
    public let backend: KeyboardCaptureBackend = .eventTap
    public var onKeyEvent: ((KeyEvent) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init() {}

    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil, runLoopSource == nil else {
            return true
        }

        let mask = Self.eventMask(for: [.keyDown, .keyUp, .flagsChanged])

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        return true
    }

    public func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let source = Unmanaged<EventTapKeyboardEventSource>.fromOpaque(userInfo).takeUnretainedValue()
        source.handle(eventType: type, event: event)
        return Unmanaged.passUnretained(event)
    }

    private func handle(eventType: CGEventType, event: CGEvent) {
        guard let keyEvent = translate(eventType: eventType, event: event) else {
            return
        }

        onKeyEvent?(keyEvent)
    }

    private func translate(eventType: CGEventType, event: CGEvent) -> KeyEvent? {
        let keyCodeValue = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCodeValue >= 0, keyCodeValue <= Int64(UInt16.max) else {
            return nil
        }

        let keyCode = UInt16(keyCodeValue)
        let modifiers = Self.modifiers(from: event.flags)
        let timestamp = CACurrentMediaTime()

        switch eventType {
        case .keyDown:
            return KeyEvent(
                keyCode: keyCode,
                phase: .down,
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) == 1,
                modifiers: modifiers,
                timestamp: timestamp
            )
        case .keyUp:
            return KeyEvent(
                keyCode: keyCode,
                phase: .up,
                isRepeat: false,
                modifiers: modifiers,
                timestamp: timestamp
            )
        case .flagsChanged:
            return KeyEvent(
                keyCode: keyCode,
                phase: Self.phaseForModifierEvent(keyCode: keyCode, modifiers: modifiers),
                isRepeat: false,
                modifiers: modifiers,
                timestamp: timestamp
            )
        default:
            return nil
        }
    }

    private static func eventMask(for eventTypes: [CGEventType]) -> CGEventMask {
        eventTypes.reduce(into: 0) { partialResult, eventType in
            partialResult |= 1 << UInt64(eventType.rawValue)
        }
    }

    private static func phaseForModifierEvent(keyCode: UInt16, modifiers: KeyModifierSet) -> KeyPhase {
        switch keyCode {
        case 54, 55:
            return modifiers.contains(.command) ? .down : .up
        case 58, 61:
            return modifiers.contains(.option) ? .down : .up
        case 59, 62:
            return modifiers.contains(.control) ? .down : .up
        case 56, 60:
            return modifiers.contains(.shift) ? .down : .up
        case 57:
            return modifiers.contains(.capsLock) ? .down : .up
        case 63:
            return modifiers.contains(.function) ? .down : .up
        default:
            return .down
        }
    }

    private static func modifiers(from flags: CGEventFlags) -> KeyModifierSet {
        var modifierSet: KeyModifierSet = []

        if flags.contains(.maskCommand) {
            modifierSet.insert(.command)
        }
        if flags.contains(.maskAlternate) {
            modifierSet.insert(.option)
        }
        if flags.contains(.maskControl) {
            modifierSet.insert(.control)
        }
        if flags.contains(.maskShift) {
            modifierSet.insert(.shift)
        }
        if flags.contains(.maskAlphaShift) {
            modifierSet.insert(.capsLock)
        }
        if flags.contains(.maskSecondaryFn) {
            modifierSet.insert(.function)
        }

        return modifierSet
    }
}
