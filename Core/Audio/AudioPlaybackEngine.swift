import AVFoundation
import Foundation
import QuartzCore

@MainActor
public final class AudioPlaybackEngine {
    private struct PlayerSlot {
        let player: AVAudioPlayerNode
        var queuedUntil: TimeInterval = 0
    }

    private let engine = AVAudioEngine()
    private let classifier = KeyClassifier()
    private let fallbackPack = SoundPack(
        id: "fallback",
        name: "Fallback",
        summary: "Fallback preset.",
        gain: 1.0,
        pitchJitterRange: 0...0,
        sampleGroups: [:]
    )
    private var playerSlots: [PlayerSlot] = []
    private var packIndex: [String: SoundPack] = [:]
    private var currentPack: SoundPack
    private var masterVolume: Double = 0.72

    public init(packs: [SoundPack] = SoundPackLibrary.all, poolSize: Int = 14) {
        currentPack = packs.first ?? fallbackPack
        packIndex = Dictionary(uniqueKeysWithValues: packs.map { ($0.id, $0) })

        configureEngine(poolSize: poolSize)
        activatePack(id: currentPack.id)
    }

    public var availablePacks: [SoundPack] {
        packIndex.values.sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn {
                return lhs.isBuiltIn
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func replacePacks(_ packs: [SoundPack], selecting preferredID: String? = nil) {
        packIndex = Dictionary(uniqueKeysWithValues: packs.map { ($0.id, $0) })
        let targetID = preferredID ?? currentPack.id
        currentPack = packIndex[targetID] ?? packs.first ?? fallbackPack
        ClackinatorLogger.audio.info("Available sound packs updated: \(self.packIndex.count, privacy: .public)")
    }

    public func activatePack(id: String) {
        if let pack = packIndex[id] {
            currentPack = pack
            ClackinatorLogger.audio.info("Activated sound pack: \(pack.name, privacy: .public)")
        }
    }

    public func setMasterVolume(_ volume: Double) {
        masterVolume = max(0, min(1, volume))
    }

    public func play(_ keyEvent: KeyEvent) {
        let keyClass = classifier.classify(keyEvent)
        guard let buffer = currentPack.randomBuffer(for: keyClass, phase: keyEvent.phase) else {
            return
        }

        guard let slotIndex = nextSlot(isRepeat: keyEvent.isRepeat) else {
            return
        }

        let now = CACurrentMediaTime()
        let duration = buffer.durationSeconds
        let nextStart = max(playerSlots[slotIndex].queuedUntil, now)
        playerSlots[slotIndex].queuedUntil = nextStart + duration

        let player = playerSlots[slotIndex].player
        player.volume = Float(masterVolume) * currentPack.gain
        player.scheduleBuffer(buffer, completionHandler: nil)

        if !player.isPlaying {
            player.play()
        }
    }

    private func configureEngine(poolSize: Int) {
        let mixer = engine.mainMixerNode

        for _ in 0..<poolSize {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: SoundSynthesizer.format)
            playerSlots.append(PlayerSlot(player: player))
        }

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restartEngineIfNeeded()
            }
        }

        restartEngineIfNeeded()
    }

    private func restartEngineIfNeeded() {
        do {
            if engine.isRunning {
                engine.stop()
            }
            try engine.start()
        } catch {
            ClackinatorLogger.audio.error("Failed to start audio engine: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func nextSlot(isRepeat: Bool) -> Int? {
        let now = CACurrentMediaTime()

        if let freeIndex = playerSlots.firstIndex(where: { $0.queuedUntil <= now }) {
            return freeIndex
        }

        if isRepeat {
            return nil
        }

        return playerSlots.enumerated().min(by: { $0.element.queuedUntil < $1.element.queuedUntil })?.offset
    }
}

private extension AVAudioPCMBuffer {
    var durationSeconds: TimeInterval {
        guard format.sampleRate > 0 else {
            return 0
        }

        return Double(frameLength) / format.sampleRate
    }
}
