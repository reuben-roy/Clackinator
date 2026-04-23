import Foundation

public protocol KeyboardEventSource: AnyObject {
    var backend: KeyboardCaptureBackend { get }
    var onKeyEvent: ((KeyEvent) -> Void)? { get set }

    @discardableResult
    func start() -> Bool

    func stop()
}
