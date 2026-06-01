import AppKit
import Foundation
import QuartzCore
import UniformTypeIdentifiers

@MainActor
public final class ClackinatorCoordinator: ObservableObject {
    private enum DefaultsKey {
        static let isEnabled = "isEnabled"
        static let selectedSoundPackID = "selectedSoundPackID"
        static let masterVolume = "masterVolume"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasRequestedKeyboardPermission = "hasRequestedKeyboardPermission"
    }

    public let channel: AppChannel

    @Published public var isEnabled: Bool {
        didSet {
            guard hasLoadedSettings else { return }
            defaults.set(isEnabled, forKey: DefaultsKey.isEnabled)
            ClackinatorLogger.app.info("Typing sounds enabled: \(self.isEnabled, privacy: .public)")
        }
    }

    @Published public var selectedSoundPackID: String {
        didSet {
            guard hasLoadedSettings else { return }
            defaults.set(selectedSoundPackID, forKey: DefaultsKey.selectedSoundPackID)
            audioEngine.activatePack(id: selectedSoundPackID)
        }
    }

    @Published public var masterVolume: Double {
        didSet {
            guard hasLoadedSettings else { return }
            defaults.set(masterVolume, forKey: DefaultsKey.masterVolume)
            audioEngine.setMasterVolume(masterVolume)
        }
    }

    @Published public var launchAtLoginEnabled: Bool {
        didSet {
            guard hasLoadedSettings else { return }
            defaults.set(launchAtLoginEnabled, forKey: DefaultsKey.launchAtLoginEnabled)
            syncLaunchAtLogin()
        }
    }

    @Published public var hasCompletedOnboarding: Bool {
        didSet {
            guard hasLoadedSettings else { return }
            defaults.set(hasCompletedOnboarding, forKey: DefaultsKey.hasCompletedOnboarding)
        }
    }

    @Published public private(set) var permissionStatus: KeyboardPermissionStatus = .unknown
    @Published public private(set) var activeBackend: KeyboardCaptureBackend = .eventMonitor
    @Published public private(set) var launchAtLoginError: String?
    @Published public private(set) var soundPackErrorMessage: String?

    public var availableSoundPacks: [SoundPack] {
        soundPackCatalog.availablePacks
    }

    public var builtInSoundPacks: [SoundPack] {
        soundPackCatalog.availableBuiltInPacks
    }

    public var customSoundPacks: [SoundPack] {
        soundPackCatalog.availableCustomPacks
    }

    public var selectedSoundPack: SoundPack? {
        soundPackCatalog.pack(id: selectedSoundPackID)
    }

    public var menuBarSymbolName: String {
        if !isEnabled {
            return "keyboard"
        }

        switch permissionStatus {
        case .granted:
            return "keyboard.fill"
        case .unknown, .denied:
            return "keyboard.badge.ellipsis"
        }
    }

    public var backendSummary: String {
        "\(activeBackend.title) on \(channel.displayName)"
    }

    public var statusSummary: String {
        switch permissionStatus {
        case .granted:
            return "Listening globally with \(activeBackend.title.lowercased())."
        case .unknown:
            return "Open settings and grant keyboard access to hear other apps."
        case .denied:
            return "Access is denied. Clackinator will only react inside its own window."
        }
    }

    private let defaults: UserDefaults
    private let audioEngine: AudioPlaybackEngine
    private let soundPackCatalog: SoundPackCatalog
    private let permissionManager: any KeyboardPermissionManaging
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private var keyboardEventSource: (any KeyboardEventSource)?
    private var settingsWindowController: SettingsWindowController?
    private var hasLoadedSettings = false

    public init(
        channel: AppChannel,
        defaults: UserDefaults = .standard,
        audioEngine providedAudioEngine: AudioPlaybackEngine? = nil,
        soundPackCatalog providedSoundPackCatalog: SoundPackCatalog? = nil,
        permissionManager: (any KeyboardPermissionManaging)? = nil,
        launchAtLoginManager: (any LaunchAtLoginManaging)? = nil
    ) {
        let resolvedSoundPackCatalog = providedSoundPackCatalog ?? SoundPackCatalog()
        let resolvedAudioEngine = providedAudioEngine ?? AudioPlaybackEngine(packs: resolvedSoundPackCatalog.availablePacks)
        let resolvedPermissionManager = permissionManager ?? KeyboardPermissionManager.shared
        let resolvedLaunchAtLoginManager = launchAtLoginManager ?? LaunchAtLoginManager.shared

        self.channel = channel
        self.defaults = defaults
        self.audioEngine = resolvedAudioEngine
        self.soundPackCatalog = resolvedSoundPackCatalog
        self.permissionManager = resolvedPermissionManager
        self.launchAtLoginManager = resolvedLaunchAtLoginManager

        let savedSoundPackID = defaults.string(forKey: DefaultsKey.selectedSoundPackID)
            ?? resolvedSoundPackCatalog.availablePacks.first?.id
            ?? "linear"
        let savedVolume = defaults.object(forKey: DefaultsKey.masterVolume) as? Double ?? 0.74
        let savedEnabled = defaults.object(forKey: DefaultsKey.isEnabled) as? Bool ?? true
        let storedLaunchAtLogin = defaults.object(forKey: DefaultsKey.launchAtLoginEnabled) as? Bool
        let actualLaunchAtLogin = resolvedLaunchAtLoginManager.isEnabled()

        isEnabled = savedEnabled
        selectedSoundPackID = savedSoundPackID
        masterVolume = savedVolume
        launchAtLoginEnabled = storedLaunchAtLogin ?? actualLaunchAtLogin
        hasCompletedOnboarding = defaults.object(forKey: DefaultsKey.hasCompletedOnboarding) as? Bool ?? false

        hasLoadedSettings = true
        _ = reloadSoundPacks(preferredSelection: savedSoundPackID)
        resolvedAudioEngine.setMasterVolume(savedVolume)
        refreshPermissionStatus()
    }

    public func start() {
        restartKeyboardEventSource()
        syncLaunchAtLogin()

        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.presentSettings()
            }
        }
    }

    public func refreshPermissionStatus() {
        if permissionManager.preflight() {
            permissionStatus = .granted
            return
        }

        let hasRequested = defaults.bool(forKey: DefaultsKey.hasRequestedKeyboardPermission)
        permissionStatus = hasRequested ? .denied : .unknown
    }

    public func requestKeyboardAccess() {
        defaults.set(true, forKey: DefaultsKey.hasRequestedKeyboardPermission)
        let granted = permissionManager.requestAccess()
        permissionStatus = granted ? .granted : .denied
        ClackinatorLogger.permissions.info("Keyboard access requested. Granted: \(granted, privacy: .public)")
        restartKeyboardEventSource()
    }

    public func openPrivacySettings() {
        permissionManager.openSystemSettings()
    }

    public func importCustomSoundPack() {
        let panel = NSOpenPanel()
        panel.title = "Import Keyboard Audio"
        panel.message = "Choose one MP3, M4A, WAV, or AIFF file to slice into a custom sound pack."
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let sourceURL = panel.url else { return }

            Task { @MainActor [weak self] in
                self?.finishImport(from: sourceURL)
            }
        }
    }

    public func deleteCustomSoundPack(id: String) {
        do {
            try soundPackCatalog.deletePack(id: id)
            let preferredSelection = selectedSoundPackID == id ? builtInSoundPacks.first?.id : selectedSoundPackID
            _ = reloadSoundPacks(preferredSelection: preferredSelection)
            soundPackErrorMessage = nil
        } catch {
            soundPackErrorMessage = error.localizedDescription
            ClackinatorLogger.audio.error("Failed to delete custom sound pack \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    public func previewSelectedSoundPack() {
        guard isEnabled else { return }

        let timestamp = CACurrentMediaTime()
        let press = KeyEvent(keyCode: 36, phase: .down, isRepeat: false, modifiers: [], timestamp: timestamp)
        let release = KeyEvent(keyCode: 36, phase: .up, isRepeat: false, modifiers: [], timestamp: timestamp + 0.045)

        audioEngine.play(press)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) { [weak self] in
            self?.audioEngine.play(release)
        }
    }

    public func presentSettings(activating: Bool = true) {
        if settingsWindowController == nil {
            let controller = SettingsWindowController(coordinator: self)
            controller.onClose = { [weak self] in
                self?.settingsWindowController = nil
            }
            settingsWindowController = controller
        }

        settingsWindowController?.present(activating: activating)
    }

    public func finishOnboarding() {
        hasCompletedOnboarding = true
        NSApp.keyWindow?.close()
    }

    public func shutdown() {
        keyboardEventSource?.stop()
        keyboardEventSource = nil
    }

    @discardableResult
    private func reloadSoundPacks(preferredSelection: String? = nil) -> String {
        soundPackCatalog.reload()

        let packs = soundPackCatalog.availablePacks
        let resolvedSelection = packs.first(where: { $0.id == (preferredSelection ?? selectedSoundPackID) })?.id
            ?? builtInSoundPacks.first?.id
            ?? packs.first?.id
            ?? "linear"

        audioEngine.replacePacks(packs, selecting: resolvedSelection)

        if selectedSoundPackID != resolvedSelection {
            selectedSoundPackID = resolvedSelection
        } else {
            audioEngine.activatePack(id: resolvedSelection)
        }

        return resolvedSelection
    }

    private func finishImport(from sourceURL: URL) {
        do {
            let pack = try soundPackCatalog.importPack(from: sourceURL)
            _ = reloadSoundPacks(preferredSelection: pack.id)
            soundPackErrorMessage = nil
        } catch {
            soundPackErrorMessage = error.localizedDescription
            ClackinatorLogger.audio.error("Failed to import custom sound pack: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func restartKeyboardEventSource() {
        keyboardEventSource?.stop()
        keyboardEventSource = KeyboardEventSourceFactory.make(
            channel: channel,
            permissionStatus: permissionStatus
        ) { [weak self] keyEvent in
            self?.handleKeyEvent(keyEvent)
        }

        activeBackend = keyboardEventSource?.backend ?? .eventMonitor
        ClackinatorLogger.input.info("Keyboard backend active: \(self.activeBackend.rawValue, privacy: .public)")
    }

    private func handleKeyEvent(_ keyEvent: KeyEvent) {
        guard isEnabled else {
            return
        }

        audioEngine.play(keyEvent)
    }

    private func syncLaunchAtLogin() {
        do {
            try launchAtLoginManager.update(enabled: launchAtLoginEnabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            ClackinatorLogger.app.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
