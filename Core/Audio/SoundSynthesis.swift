import AVFoundation
import Foundation

struct TimbreRecipe {
    let bodyFrequency: Double
    let overtoneFrequency: Double
    let clickFrequency: Double
    let bodyMix: Double
    let clickMix: Double
    let noiseMix: Double
    let duration: Double
    let decay: Double
    let gain: Double
}

struct PackRecipe {
    let id: String
    let name: String
    let summary: String
    let gain: Float
    let pitchJitterRange: ClosedRange<Double>
    let baseRecipe: TimbreRecipe
}

enum SoundSynthesizer {
    static let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    static func renderSamples(for recipe: PackRecipe) -> [SoundSampleKey: [AVAudioPCMBuffer]] {
        var generated: [SoundSampleKey: [AVAudioPCMBuffer]] = [:]

        for keyClass in KeyClass.allCases {
            let downKey = SoundSampleKey(keyClass: keyClass, phase: .down)
            let upKey = SoundSampleKey(keyClass: keyClass, phase: .up)

            generated[downKey] = makeVariants(
                recipe: adjustedRecipe(recipe.baseRecipe, for: keyClass, phase: .down),
                variantCount: 6,
                seedPrefix: "\(recipe.id)-\(keyClass.rawValue)-down",
                pitchJitterRange: recipe.pitchJitterRange
            )

            generated[upKey] = makeVariants(
                recipe: adjustedRecipe(recipe.baseRecipe, for: keyClass, phase: .up),
                variantCount: 4,
                seedPrefix: "\(recipe.id)-\(keyClass.rawValue)-up",
                pitchJitterRange: recipe.pitchJitterRange
            )
        }

        return generated
    }

    private static func makeVariants(
        recipe: TimbreRecipe,
        variantCount: Int,
        seedPrefix: String,
        pitchJitterRange: ClosedRange<Double>
    ) -> [AVAudioPCMBuffer] {
        (0..<variantCount).compactMap { variantIndex in
            let seed = seedPrefix.seed64 ^ UInt64(variantIndex &* 13 &+ 17)
            var generator = SeededGenerator(seed: seed)
            var adjusted = recipe
            let pitchScale = 1.0 + Double.random(in: pitchJitterRange, using: &generator)
            adjusted = TimbreRecipe(
                bodyFrequency: recipe.bodyFrequency * pitchScale,
                overtoneFrequency: recipe.overtoneFrequency * pitchScale,
                clickFrequency: recipe.clickFrequency * pitchScale,
                bodyMix: recipe.bodyMix,
                clickMix: recipe.clickMix * Double.random(in: 0.92...1.08, using: &generator),
                noiseMix: recipe.noiseMix * Double.random(in: 0.9...1.1, using: &generator),
                duration: recipe.duration * Double.random(in: 0.94...1.06, using: &generator),
                decay: recipe.decay * Double.random(in: 0.92...1.08, using: &generator),
                gain: recipe.gain * Double.random(in: 0.94...1.04, using: &generator)
            )
            return renderBuffer(recipe: adjusted, generator: &generator)
        }
    }

    private static func adjustedRecipe(_ recipe: TimbreRecipe, for keyClass: KeyClass, phase: KeyPhase) -> TimbreRecipe {
        let frequencyMultiplier: Double
        let durationMultiplier: Double
        let clickMultiplier: Double

        switch keyClass {
        case .standard:
            frequencyMultiplier = 1.0
            durationMultiplier = 1.0
            clickMultiplier = 1.0
        case .space:
            frequencyMultiplier = 0.72
            durationMultiplier = 1.45
            clickMultiplier = 0.9
        case .return:
            frequencyMultiplier = 0.82
            durationMultiplier = 1.25
            clickMultiplier = 1.08
        case .delete:
            frequencyMultiplier = 0.9
            durationMultiplier = 1.14
            clickMultiplier = 1.0
        case .modifier:
            frequencyMultiplier = 0.78
            durationMultiplier = 1.08
            clickMultiplier = 0.84
        case .navigation:
            frequencyMultiplier = 0.96
            durationMultiplier = 1.05
            clickMultiplier = 0.95
        case .function:
            frequencyMultiplier = 1.12
            durationMultiplier = 0.95
            clickMultiplier = 1.12
        }

        let phaseDuration = phase == .down ? recipe.duration : recipe.duration * 0.46
        let phaseDecay = phase == .down ? recipe.decay : recipe.decay * 0.52
        let phaseGain = phase == .down ? recipe.gain : recipe.gain * 0.45
        let phaseNoise = phase == .down ? recipe.noiseMix : recipe.noiseMix * 0.32
        let phaseClick = phase == .down ? recipe.clickMix : recipe.clickMix * 0.54

        return TimbreRecipe(
            bodyFrequency: recipe.bodyFrequency * frequencyMultiplier,
            overtoneFrequency: recipe.overtoneFrequency * frequencyMultiplier,
            clickFrequency: recipe.clickFrequency * frequencyMultiplier,
            bodyMix: recipe.bodyMix,
            clickMix: phaseClick * clickMultiplier,
            noiseMix: phaseNoise,
            duration: phaseDuration * durationMultiplier,
            decay: phaseDecay * durationMultiplier,
            gain: phaseGain
        )
    }

    private static func renderBuffer(recipe: TimbreRecipe, generator: inout SeededGenerator) -> AVAudioPCMBuffer? {
        let frameCount = Int(format.sampleRate * recipe.duration)
        guard frameCount > 0 else {
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channel = buffer.floatChannelData?.pointee else {
            return nil
        }

        let sampleRate = format.sampleRate

        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let attack = min(1.0, time / 0.0015)
            let bodyEnvelope = exp(-time / recipe.decay)
            let clickEnvelope = exp(-time / max(recipe.decay * 0.18, 0.002))
            let noiseEnvelope = exp(-time / max(recipe.decay * 0.32, 0.003))

            let body = sin(2.0 * .pi * recipe.bodyFrequency * time) * recipe.bodyMix * bodyEnvelope
            let overtone = sin(2.0 * .pi * recipe.overtoneFrequency * time) * recipe.bodyMix * 0.36 * bodyEnvelope
            let click = sin(2.0 * .pi * recipe.clickFrequency * time) * recipe.clickMix * clickEnvelope
            let noise = Double.random(in: -1.0...1.0, using: &generator) * recipe.noiseMix * noiseEnvelope
            let transient = sin(2.0 * .pi * (recipe.clickFrequency * 1.8) * time) * recipe.clickMix * 0.18 * clickEnvelope

            let dry = (body + overtone + click + noise + transient) * attack * recipe.gain
            channel[frame] = Float(max(-0.95, min(0.95, dry)))
        }

        return buffer
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

private extension String {
    var seed64: UInt64 {
        utf8.reduce(into: UInt64(1469598103934665603)) { result, byte in
            result ^= UInt64(byte)
            result &*= 1099511628211
        }
    }
}
