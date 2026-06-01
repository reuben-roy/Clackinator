import Foundation

@MainActor
public final class SoundPackCatalog {
    private let customStore: CustomSoundPackStore
    private let builtInPacks: [SoundPack]
    private var customPacks: [SoundPack] = []

    public init(
        customStore: CustomSoundPackStore = CustomSoundPackStore(),
        builtInPacks: [SoundPack] = SoundPackLibrary.all
    ) {
        self.customStore = customStore
        self.builtInPacks = builtInPacks
        reload()
    }

    public var availablePacks: [SoundPack] {
        builtInPacks + customPacks
    }

    public var availableBuiltInPacks: [SoundPack] {
        builtInPacks
    }

    public var availableCustomPacks: [SoundPack] {
        customPacks
    }

    public func pack(id: String) -> SoundPack? {
        availablePacks.first(where: { $0.id == id })
    }

    public func reload() {
        customPacks = loadCustomPacks()
    }

    public func importPack(from sourceURL: URL) throws -> SoundPack {
        let record = try customStore.importRecord(from: sourceURL)

        do {
            let pack = try makeCustomPack(from: record)
            customPacks.append(pack)
            customPacks.sort { ($0.importedAt ?? .distantPast) < ($1.importedAt ?? .distantPast) }
            return pack
        } catch {
            try? customStore.deletePack(id: record.id)
            throw error
        }
    }

    public func deletePack(id: String) throws {
        try customStore.deletePack(id: id)
        customPacks.removeAll { $0.id == id }
    }

    private func loadCustomPacks() -> [SoundPack] {
        do {
            return try customStore.loadRecords().compactMap { record in
                do {
                    return try makeCustomPack(from: record)
                } catch {
                    ClackinatorLogger.audio.error("Failed to load custom sound pack \(record.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
        } catch {
            ClackinatorLogger.audio.error("Failed to load custom sound pack index: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func makeCustomPack(from record: CustomSoundPackRecord) throws -> SoundPack {
        let sampleGroups = try SampledSoundPackRenderer.renderSamples(
            from: [customStore.sourceURL(for: record)],
            seedPrefix: record.id,
            pitchJitterRange: -0.03...0.03
        )

        return SoundPack(
            id: record.id,
            name: record.name,
            summary: "Imported from \(record.sourceFilename).",
            gain: 0.92,
            pitchJitterRange: -0.03...0.03,
            sampleGroups: sampleGroups,
            category: .custom,
            sourceFilename: record.sourceFilename,
            importedAt: record.importedAt
        )
    }
}
