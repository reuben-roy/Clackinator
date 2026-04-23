import AVFoundation
import Foundation

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

    private let sampleGroups: [SoundSampleKey: [AVAudioPCMBuffer]]

    init(
        id: String,
        name: String,
        summary: String,
        gain: Float,
        pitchJitterRange: ClosedRange<Double>,
        sampleGroups: [SoundSampleKey: [AVAudioPCMBuffer]]
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.gain = gain
        self.pitchJitterRange = pitchJitterRange
        self.sampleGroups = sampleGroups
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
