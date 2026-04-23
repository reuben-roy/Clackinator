import XCTest
@testable import KeyTokCore

final class SoundPackLibraryTests: XCTestCase {
    func testThreeNamedPacksExist() {
        let packNames = SoundPackLibrary.all.map(\.name)

        XCTAssertEqual(packNames, ["Linear", "Tactile", "Clicky"])
    }

    func testEveryPackContainsPrimaryKeyClassesForKeyDown() {
        let requiredClasses: [KeyClass] = [.standard, .space, .return, .delete, .modifier]

        for pack in SoundPackLibrary.all {
            for keyClass in requiredClasses {
                XCTAssertTrue(pack.hasSamples(for: keyClass, phase: .down), "\(pack.name) is missing \(keyClass.rawValue) down samples.")
            }
        }
    }

    func testEveryPackContainsReleaseSamples() {
        for pack in SoundPackLibrary.all {
            XCTAssertTrue(pack.hasSamples(for: .standard, phase: .up))
            XCTAssertTrue(pack.hasSamples(for: .space, phase: .up))
        }
    }
}
