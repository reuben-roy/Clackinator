import AVFoundation
import Foundation

enum AudioTestSupport {
    static func temporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ClackinatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    static func makeTransientWAV(
        in directory: URL,
        name: String = "transient.wav",
        transientFrames: [Int],
        totalFrames: Int = 44_100
    ) throws -> URL {
        let outputURL = directory.appendingPathComponent(name)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        let channel = buffer.floatChannelData!.pointee
        for frame in 0..<totalFrames {
            channel[frame] = 0
        }

        for transientFrame in transientFrames {
            for offset in 0..<420 {
                let frameIndex = transientFrame + offset
                guard frameIndex < totalFrames else { break }

                let envelope = exp(-Double(offset) / 72.0)
                let value = sin(Double(offset) / 5.5) * 0.88 * envelope
                channel[frameIndex] += Float(value)
            }
        }

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try outputFile.write(from: buffer)
        return outputURL
    }
}
