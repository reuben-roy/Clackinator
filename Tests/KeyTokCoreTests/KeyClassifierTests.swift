import XCTest
@testable import KeyTokCore

final class KeyClassifierTests: XCTestCase {
    private let classifier = KeyClassifier()

    func testSpaceClassifiesAsSpace() {
        XCTAssertEqual(classifier.classify(event(keyCode: 49)), .space)
    }

    func testReturnClassifiesAsReturn() {
        XCTAssertEqual(classifier.classify(event(keyCode: 36)), .return)
    }

    func testDeleteClassifiesAsDelete() {
        XCTAssertEqual(classifier.classify(event(keyCode: 51)), .delete)
    }

    func testModifiersClassifyAsModifier() {
        XCTAssertEqual(classifier.classify(event(keyCode: 55)), .modifier)
    }

    func testArrowsClassifyAsNavigation() {
        XCTAssertEqual(classifier.classify(event(keyCode: 123)), .navigation)
    }

    func testFunctionKeysClassifyAsFunction() {
        XCTAssertEqual(classifier.classify(event(keyCode: 122)), .function)
    }

    func testLetterKeysClassifyAsStandard() {
        XCTAssertEqual(classifier.classify(event(keyCode: 0)), .standard)
    }

    private func event(keyCode: UInt16) -> KeyEvent {
        KeyEvent(
            keyCode: keyCode,
            phase: .down,
            isRepeat: false,
            modifiers: [],
            timestamp: 0
        )
    }
}
