import XCTest
@testable import ClackinatorCore

@MainActor
final class CustomSoundPackStoreTests: XCTestCase {
    func testImportCopiesAudioAndPersistsRecordAcrossReload() throws {
        let directory = try AudioTestSupport.temporaryDirectory()
        let sourceURL = try AudioTestSupport.makeTransientWAV(
            in: directory,
            name: "source.wav",
            transientFrames: [1_200, 9_400, 18_000]
        )
        let storeURL = directory.appendingPathComponent("CustomStore", isDirectory: true)
        let store = CustomSoundPackStore(baseURL: storeURL)

        let catalog = SoundPackCatalog(customStore: store, builtInPacks: [])
        let importedPack = try catalog.importPack(from: sourceURL)

        XCTAssertEqual(catalog.availableCustomPacks.count, 1)
        XCTAssertTrue(importedPack.hasSamples(for: .standard, phase: .down))
        XCTAssertTrue(importedPack.hasSamples(for: .space, phase: .up))

        let records = try store.loadRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.sourceURL(for: records[0]).path))

        let reloadedCatalog = SoundPackCatalog(customStore: store, builtInPacks: [])
        XCTAssertEqual(reloadedCatalog.availableCustomPacks.map(\.id), [importedPack.id])
    }
}
