import XCTest
@testable import ClackinatorCore

@MainActor
final class ClackinatorCoordinatorTests: XCTestCase {
    private final class PermissionManagerMock: KeyboardPermissionManaging {
        func preflight() -> Bool { true }
        func requestAccess() -> Bool { true }
        func openSystemSettings() {}
    }

    private final class LaunchAtLoginManagerMock: LaunchAtLoginManaging {
        func isEnabled() -> Bool { false }
        func update(enabled: Bool) throws {}
    }

    func testDeletingSelectedCustomPackFallsBackToFirstBuiltInPack() throws {
        let directory = try AudioTestSupport.temporaryDirectory()
        let sourceURL = try AudioTestSupport.makeTransientWAV(
            in: directory,
            name: "custom.wav",
            transientFrames: [1_500, 8_200, 14_600]
        )
        let store = CustomSoundPackStore(baseURL: directory.appendingPathComponent("CustomStore", isDirectory: true))
        let catalog = SoundPackCatalog(customStore: store)
        let importedPack = try catalog.importPack(from: sourceURL)

        let suiteName = "ClackinatorCoordinatorTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated UserDefaults suite.")
            return
        }

        let coordinator = ClackinatorCoordinator(
            channel: .direct,
            defaults: defaults,
            soundPackCatalog: catalog,
            permissionManager: PermissionManagerMock(),
            launchAtLoginManager: LaunchAtLoginManagerMock()
        )

        coordinator.selectedSoundPackID = importedPack.id
        coordinator.deleteCustomSoundPack(id: importedPack.id)

        XCTAssertEqual(coordinator.selectedSoundPackID, coordinator.builtInSoundPacks.first?.id)
        XCTAssertTrue(coordinator.customSoundPacks.isEmpty)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
