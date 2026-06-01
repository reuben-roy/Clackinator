import Foundation

public struct CustomSoundPackRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sourceFilename: String
    public let importedAt: Date

    public init(id: String, name: String, sourceFilename: String, importedAt: Date) {
        self.id = id
        self.name = name
        self.sourceFilename = sourceFilename
        self.importedAt = importedAt
    }
}

enum CustomSoundPackStoreError: LocalizedError {
    case unsupportedAudioFileExtension(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedAudioFileExtension(extensionName):
            return "Unsupported audio file type: .\(extensionName)"
        }
    }
}

public final class CustomSoundPackStore {
    public static let supportedFileExtensions: Set<String> = ["aif", "aiff", "m4a", "mp3", "wav"]

    private let baseURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.baseURL = baseURL ?? Self.defaultBaseURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadRecords() throws -> [CustomSoundPackRecord] {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return []
        }

        let data = try Data(contentsOf: indexURL)
        return try decoder.decode([CustomSoundPackRecord].self, from: data)
            .sorted { $0.importedAt < $1.importedAt }
    }

    @discardableResult
    public func importRecord(from sourceFileURL: URL) throws -> CustomSoundPackRecord {
        let pathExtension = sourceFileURL.pathExtension.lowercased()
        guard Self.supportedFileExtensions.contains(pathExtension) else {
            throw CustomSoundPackStoreError.unsupportedAudioFileExtension(pathExtension)
        }

        try ensureBaseDirectory()

        let record = CustomSoundPackRecord(
            id: UUID().uuidString.lowercased(),
            name: Self.displayName(for: sourceFileURL),
            sourceFilename: sourceFileURL.lastPathComponent,
            importedAt: Date()
        )

        let destinationFolder = folderURL(for: record.id)
        let destinationURL = sourceURL(for: record)

        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        try fileManager.copyItem(at: sourceFileURL, to: destinationURL)

        var records = try loadRecords()
        records.append(record)
        try saveRecords(records)

        return record
    }

    public func deletePack(id: String) throws {
        var records = try loadRecords()
        records.removeAll { $0.id == id }

        let packFolder = folderURL(for: id)
        if fileManager.fileExists(atPath: packFolder.path) {
            try fileManager.removeItem(at: packFolder)
        }

        try saveRecords(records)
    }

    public func sourceURL(for record: CustomSoundPackRecord) -> URL {
        let pathExtension = (record.sourceFilename as NSString).pathExtension
        return folderURL(for: record.id)
            .appendingPathComponent("source")
            .appendingPathExtension(pathExtension)
    }

    private func ensureBaseDirectory() throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    private func saveRecords(_ records: [CustomSoundPackRecord]) throws {
        try ensureBaseDirectory()
        let sortedRecords = records.sorted { $0.importedAt < $1.importedAt }
        let data = try encoder.encode(sortedRecords)
        try data.write(to: indexURL, options: .atomic)
    }

    private func folderURL(for id: String) -> URL {
        baseURL.appendingPathComponent(id, isDirectory: true)
    }

    private var indexURL: URL {
        baseURL.appendingPathComponent("index.json")
    }

    private static func defaultBaseURL(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.clackinator"
        return applicationSupport
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("CustomSoundPacks", isDirectory: true)
    }

    private static func displayName(for sourceURL: URL) -> String {
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        let normalized = stem
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            return "Imported Pack"
        }

        return normalized
    }
}
