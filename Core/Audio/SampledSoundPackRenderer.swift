import AVFoundation
import Foundation

struct SampledPackDefinition {
    let id: String
    let name: String
    let summary: String
    let gain: Float
    let pitchJitterRange: ClosedRange<Double>
    let resourceNames: [String]
}

enum SampledSoundPackRendererError: LocalizedError {
    case missingBundledResource(String)
    case unreadableAudioFile(String)
    case noUsableSamples(String)

    var errorDescription: String? {
        switch self {
        case let .missingBundledResource(name):
            return "Missing bundled audio resource: \(name)"
        case let .unreadableAudioFile(name):
            return "Unable to decode audio file: \(name)"
        case let .noUsableSamples(name):
            return "Unable to derive keyboard samples from: \(name)"
        }
    }
}

enum SampledSoundPackRenderer {
    static func renderPack(from definition: SampledPackDefinition, bundle: Bundle = .keyTokCore) throws -> SoundPack {
        let urls = try definition.resourceNames.map { resourceName -> URL in
            guard let url = bundle.resourceURL(named: resourceName) else {
                throw SampledSoundPackRendererError.missingBundledResource(resourceName)
            }

            return url
        }

        let sampleGroups = try renderSamples(
            from: urls,
            seedPrefix: definition.id,
            pitchJitterRange: definition.pitchJitterRange
        )

        return SoundPack(
            id: definition.id,
            name: definition.name,
            summary: definition.summary,
            gain: definition.gain,
            pitchJitterRange: definition.pitchJitterRange,
            sampleGroups: sampleGroups
        )
    }

    static func renderSamples(
        from urls: [URL],
        seedPrefix: String,
        pitchJitterRange: ClosedRange<Double>
    ) throws -> [SoundSampleKey: [AVAudioPCMBuffer]] {
        var pressVariants: [AVAudioPCMBuffer] = []

        for url in urls {
            let normalizedBuffer = try normalizedBuffer(from: url)
            pressVariants.append(contentsOf: extractTransientSlices(from: normalizedBuffer))
        }

        guard !pressVariants.isEmpty else {
            throw SampledSoundPackRendererError.noUsableSamples(urls.first?.lastPathComponent ?? seedPrefix)
        }

        let cappedPressVariants = Array(pressVariants.prefix(12))
        let releaseVariants = cappedPressVariants.enumerated().compactMap { index, buffer in
            transformBuffer(
                from: buffer,
                pitchScale: 1.04 + (Double(index) * 0.004),
                durationScale: 0.36,
                gain: 0.34
            )
        }

        var generated: [SoundSampleKey: [AVAudioPCMBuffer]] = [:]

        for keyClass in KeyClass.allCases {
            generated[SoundSampleKey(keyClass: keyClass, phase: .down)] = makeVariants(
                from: cappedPressVariants,
                keyClass: keyClass,
                phase: .down,
                seedPrefix: "\(seedPrefix)-\(keyClass.rawValue)-down",
                pitchJitterRange: pitchJitterRange
            )

            generated[SoundSampleKey(keyClass: keyClass, phase: .up)] = makeVariants(
                from: releaseVariants.isEmpty ? cappedPressVariants : releaseVariants,
                keyClass: keyClass,
                phase: .up,
                seedPrefix: "\(seedPrefix)-\(keyClass.rawValue)-up",
                pitchJitterRange: pitchJitterRange
            )
        }

        return generated
    }

    private static func makeVariants(
        from sourceBuffers: [AVAudioPCMBuffer],
        keyClass: KeyClass,
        phase: KeyPhase,
        seedPrefix: String,
        pitchJitterRange: ClosedRange<Double>
    ) -> [AVAudioPCMBuffer] {
        let baseTransform = transformProfile(for: keyClass, phase: phase)

        return sourceBuffers.enumerated().compactMap { index, buffer in
            let seed = seedValue(for: seedPrefix) ^ UInt64(index &* 17 &+ 29)
            var generator = SeededGenerator(seed: seed)
            let pitchScale = baseTransform.pitchScale * (1 + Double.random(in: pitchJitterRange, using: &generator))
            let durationScale = baseTransform.durationScale * Double.random(in: 0.94...1.06, using: &generator)
            let gain = baseTransform.gain * Float(Double.random(in: 0.94...1.06, using: &generator))

            return transformBuffer(
                from: buffer,
                pitchScale: pitchScale,
                durationScale: durationScale,
                gain: gain
            )
        }
    }

    private static func transformProfile(for keyClass: KeyClass, phase: KeyPhase) -> (pitchScale: Double, durationScale: Double, gain: Float) {
        let base: (pitchScale: Double, durationScale: Double, gain: Float)

        switch keyClass {
        case .standard:
            base = (1.0, 1.0, 1.0)
        case .space:
            base = (0.8, 1.42, 1.08)
        case .return:
            base = (0.86, 1.24, 1.02)
        case .delete:
            base = (0.92, 1.12, 0.98)
        case .modifier:
            base = (0.84, 1.06, 0.9)
        case .navigation:
            base = (0.96, 1.04, 0.94)
        case .function:
            base = (1.08, 0.94, 0.9)
        }

        if phase == .down {
            return base
        }

        return (
            pitchScale: base.pitchScale * 1.04,
            durationScale: max(0.24, base.durationScale * 0.42),
            gain: base.gain * 0.42
        )
    }

    private static func normalizedBuffer(from url: URL) throws -> AVAudioPCMBuffer {
        guard let sourceFile = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false) else {
            throw SampledSoundPackRendererError.unreadableAudioFile(url.lastPathComponent)
        }

        let frameCapacity = AVAudioFrameCount(max(sourceFile.length, 1))
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat, frameCapacity: frameCapacity) else {
            throw SampledSoundPackRendererError.unreadableAudioFile(url.lastPathComponent)
        }

        try sourceFile.read(into: sourceBuffer)

        let monoBuffer = downmixToMono(sourceBuffer)
        if monoBuffer.format.sampleRate == SoundSynthesizer.format.sampleRate {
            return monoBuffer
        }

        return resample(monoBuffer, to: SoundSynthesizer.format.sampleRate)
    }

    private static func downmixToMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: buffer.format.sampleRate, channels: 1) ?? SoundSynthesizer.format
        let frameCount = Int(buffer.frameLength)
        let output = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(max(frameCount, 1)))!
        output.frameLength = AVAudioFrameCount(frameCount)

        guard
            let inputChannels = buffer.floatChannelData,
            let outputChannel = output.floatChannelData?.pointee
        else {
            return output
        }

        let channelCount = Int(buffer.format.channelCount)
        for frame in 0..<frameCount {
            var mixed: Float = 0
            for channelIndex in 0..<channelCount {
                mixed += inputChannels[channelIndex][frame]
            }

            outputChannel[frame] = mixed / Float(max(channelCount, 1))
        }

        return output
    }

    private static func resample(_ buffer: AVAudioPCMBuffer, to sampleRate: Double) -> AVAudioPCMBuffer {
        let sourceRate = buffer.format.sampleRate
        let sourceCount = Int(buffer.frameLength)
        let targetCount = max(1, Int((Double(sourceCount) * sampleRate / sourceRate).rounded()))
        let output = AVAudioPCMBuffer(pcmFormat: SoundSynthesizer.format, frameCapacity: AVAudioFrameCount(targetCount))!
        output.frameLength = AVAudioFrameCount(targetCount)

        guard
            let inputChannel = buffer.floatChannelData?.pointee,
            let outputChannel = output.floatChannelData?.pointee
        else {
            return output
        }

        if sourceCount <= 1 {
            let value = sourceCount == 1 ? inputChannel[0] : 0
            for index in 0..<targetCount {
                outputChannel[index] = value
            }
            return output
        }

        let ratio = sourceRate / sampleRate
        for targetIndex in 0..<targetCount {
            let sourcePosition = Double(targetIndex) * ratio
            outputChannel[targetIndex] = interpolatedSample(at: sourcePosition, in: inputChannel, count: sourceCount)
        }

        return output
    }

    private static func extractTransientSlices(from buffer: AVAudioPCMBuffer) -> [AVAudioPCMBuffer] {
        guard
            let channel = buffer.floatChannelData?.pointee,
            buffer.frameLength > 0
        else {
            return []
        }

        let sampleCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channel, count: sampleCount))
        let peaks = detectTransientPeaks(in: samples, sampleRate: buffer.format.sampleRate)

        return peaks.prefix(6).compactMap { peakIndex in
            extractSlice(from: samples, around: peakIndex, sampleRate: buffer.format.sampleRate)
        }
    }

    private static func detectTransientPeaks(in samples: [Float], sampleRate: Double) -> [Int] {
        guard !samples.isEmpty else {
            return []
        }

        let window = max(24, Int(sampleRate * 0.0012))
        var envelope = Array(repeating: Float.zero, count: samples.count)
        var sum: Float = 0

        for index in samples.indices {
            sum += abs(samples[index])
            if index >= window {
                sum -= abs(samples[index - window])
            }

            envelope[index] = sum / Float(min(index + 1, window))
        }

        let mean = envelope.reduce(0, +) / Float(max(envelope.count, 1))
        let maxValue = envelope.max() ?? 0
        let threshold = max(mean * 1.9, maxValue * 0.36)
        let minimumSpacing = max(240, Int(sampleRate * 0.028))

        var candidates: [(index: Int, value: Float)] = []
        var lastAccepted = -minimumSpacing

        if envelope.count > 2 {
            for index in 1..<(envelope.count - 1) {
                let value = envelope[index]
                guard value >= threshold else { continue }
                guard value >= envelope[index - 1], value > envelope[index + 1] else { continue }
                guard index - lastAccepted >= minimumSpacing else { continue }

                candidates.append((index, value))
                lastAccepted = index
            }
        }

        if candidates.isEmpty {
            if let maxIndex = envelope.indices.max(by: { envelope[$0] < envelope[$1] }) {
                return [maxIndex]
            }

            return []
        }

        let ranked = candidates.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.index < rhs.index
            }

            return lhs.value > rhs.value
        }

        return ranked.prefix(6).map(\.index).sorted()
    }

    private static func extractSlice(from samples: [Float], around center: Int, sampleRate: Double) -> AVAudioPCMBuffer? {
        let preRollFrames = max(32, Int(sampleRate * 0.0025))
        let sliceFrames = max(320, Int(sampleRate * 0.072))
        let unclampedStart = center - preRollFrames
        let start = max(0, min(unclampedStart, max(samples.count - sliceFrames, 0)))
        let end = min(samples.count, start + sliceFrames)

        guard end > start else {
            return nil
        }

        let frameCount = end - start
        let output = AVAudioPCMBuffer(pcmFormat: SoundSynthesizer.format, frameCapacity: AVAudioFrameCount(frameCount))!
        output.frameLength = AVAudioFrameCount(frameCount)

        guard let channel = output.floatChannelData?.pointee else {
            return nil
        }

        let fadeInFrames = max(12, Int(sampleRate * 0.0015))
        let fadeOutFrames = max(48, Int(sampleRate * 0.006))

        for index in 0..<frameCount {
            var sample = samples[start + index]

            if index < fadeInFrames {
                sample *= Float(index) / Float(max(fadeInFrames, 1))
            }

            if index >= frameCount - fadeOutFrames {
                let remaining = frameCount - index
                sample *= Float(max(remaining, 0)) / Float(max(fadeOutFrames, 1))
            }

            channel[index] = max(-0.98, min(0.98, sample))
        }

        return output
    }

    private static func transformBuffer(
        from source: AVAudioPCMBuffer,
        pitchScale: Double,
        durationScale: Double,
        gain: Float
    ) -> AVAudioPCMBuffer? {
        guard
            let inputChannel = source.floatChannelData?.pointee,
            source.frameLength > 0
        else {
            return nil
        }

        let sourceCount = Int(source.frameLength)
        let targetCount = max(1, Int((Double(sourceCount) * durationScale).rounded()))
        let output = AVAudioPCMBuffer(pcmFormat: SoundSynthesizer.format, frameCapacity: AVAudioFrameCount(targetCount))!
        output.frameLength = AVAudioFrameCount(targetCount)

        guard let outputChannel = output.floatChannelData?.pointee else {
            return nil
        }

        let fadeOutFrames = max(24, Int(Double(targetCount) * 0.18))
        for outputIndex in 0..<targetCount {
            let sourcePosition = (Double(outputIndex) / max(durationScale, 0.0001)) * pitchScale
            let sample = interpolatedSample(at: sourcePosition, in: inputChannel, count: sourceCount)
            var scaled = sample * gain

            if outputIndex >= targetCount - fadeOutFrames {
                let remaining = targetCount - outputIndex
                scaled *= Float(max(remaining, 0)) / Float(max(fadeOutFrames, 1))
            }

            outputChannel[outputIndex] = max(-0.98, min(0.98, scaled))
        }

        return output
    }

    private static func interpolatedSample(
        at sourcePosition: Double,
        in channel: UnsafeMutablePointer<Float>,
        count: Int
    ) -> Float {
        guard count > 1 else {
            return count == 1 ? channel[0] : 0
        }

        guard sourcePosition >= 0 else {
            return 0
        }

        let lowerIndex = Int(floor(sourcePosition))
        let upperIndex = lowerIndex + 1

        if lowerIndex >= count {
            return 0
        }

        if upperIndex >= count {
            return channel[lowerIndex]
        }

        let fraction = Float(sourcePosition - Double(lowerIndex))
        let lowerSample = channel[lowerIndex]
        let upperSample = channel[upperIndex]
        return lowerSample + ((upperSample - lowerSample) * fraction)
    }

    private static func seedValue(for string: String) -> UInt64 {
        string.utf8.reduce(into: UInt64(1469598103934665603)) { result, byte in
            result ^= UInt64(byte)
            result &*= 1099511628211
        }
    }
}

private final class ClackinatorCoreBundleLocator {}

private extension Bundle {
    static var keyTokCore: Bundle {
        Bundle(for: ClackinatorCoreBundleLocator.self)
    }

    func resourceURL(named fileName: String) -> URL? {
        let resourceName = (fileName as NSString).deletingPathExtension
        let resourceExtension = (fileName as NSString).pathExtension
        return url(forResource: resourceName, withExtension: resourceExtension.isEmpty ? nil : resourceExtension)
    }
}
