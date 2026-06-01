import XCTest
@testable import ClackinatorCore

final class SampledSoundPackRendererTests: XCTestCase {
    func testTransientFallbackStillCreatesUsableSamples() throws {
        let directory = try AudioTestSupport.temporaryDirectory()
        let sourceURL = try AudioTestSupport.makeTransientWAV(
            in: directory,
            name: "fallback.wav",
            transientFrames: [22_050]
        )

        let sampleGroups = try SampledSoundPackRenderer.renderSamples(
            from: [sourceURL],
            seedPrefix: "fallback",
            pitchJitterRange: -0.02...0.02
        )

        XCTAssertFalse(sampleGroups[SoundSampleKey(keyClass: .standard, phase: .down)]?.isEmpty ?? true)
        XCTAssertFalse(sampleGroups[SoundSampleKey(keyClass: .space, phase: .up)]?.isEmpty ?? true)
    }
}
