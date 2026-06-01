import AVFoundation
import Foundation

public enum SoundPackCategory: String, Sendable {
    case builtIn
    case custom
}

public struct SoundSampleKey: Hashable {
    public let keyClass: KeyClass
    public let phase: KeyPhase

    public init(keyClass: KeyClass, phase: KeyPhase) {
        self.keyClass = keyClass
        self.phase = phase
    }
}

public final class SoundPack: Identifiable {
    public let id: String
    public let name: String
    public let summary: String
    public let gain: Float
    public let pitchJitterRange: ClosedRange<Double>
    public let category: SoundPackCategory
    public let sourceFilename: String?
    public let importedAt: Date?

    private let sampleGroups: [SoundSampleKey: [AVAudioPCMBuffer]]

    init(
        id: String,
        name: String,
        summary: String,
        gain: Float,
        pitchJitterRange: ClosedRange<Double>,
        sampleGroups: [SoundSampleKey: [AVAudioPCMBuffer]],
        category: SoundPackCategory = .builtIn,
        sourceFilename: String? = nil,
        importedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.gain = gain
        self.pitchJitterRange = pitchJitterRange
        self.category = category
        self.sourceFilename = sourceFilename
        self.importedAt = importedAt
        self.sampleGroups = sampleGroups
    }

    public var isBuiltIn: Bool {
        category == .builtIn
    }

    public var isCustom: Bool {
        category == .custom
    }

    public func availableKeyClasses(for phase: KeyPhase) -> [KeyClass] {
        sampleGroups.keys
            .filter { $0.phase == phase }
            .map(\.keyClass)
            .sorted { $0.rawValue < $1.rawValue }
    }

    public func hasSamples(for keyClass: KeyClass, phase: KeyPhase) -> Bool {
        !(sampleGroups[SoundSampleKey(keyClass: keyClass, phase: phase)]?.isEmpty ?? true)
    }

    func randomBuffer(for keyClass: KeyClass, phase: KeyPhase) -> AVAudioPCMBuffer? {
        let exactKey = SoundSampleKey(keyClass: keyClass, phase: phase)
        let fallbackKey = SoundSampleKey(keyClass: .standard, phase: phase)

        if let exact = sampleGroups[exactKey], !exact.isEmpty {
            return exact.randomElement()
        }

        return sampleGroups[fallbackKey]?.randomElement()
    }
}
