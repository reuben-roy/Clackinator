import AppKit
import Foundation
import QuartzCore

@MainActor
public final class KeyTokCoordinator: ObservableObject {
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
            KeyTokLogger.app.info("Typing sounds enabled: \(self.isEnabled, privacy: .public)")
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

    public var availableSoundPacks: [SoundPack] {
        audioEngine.availablePacks
    }

    public var selectedSoundPack: SoundPack? {
        availableSoundPacks.first(where: { $0.id == selectedSoundPackID })
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
            return "Access is denied. KeyTok will only react inside its own window."
        }
    }

    private let defaults: UserDefaults
    private let audioEngine: AudioPlaybackEngine
    private let permissionManager: KeyboardPermissionManager
    private let launchAtLoginManager: LaunchAtLoginManager
    private var keyboardEventSource: (any KeyboardEventSource)?
    private var settingsWindowController: SettingsWindowController?
    private var hasLoadedSettings = false

    public init(
        channel: AppChannel,
        defaults: UserDefaults = .standard,
        audioEngine providedAudioEngine: AudioPlaybackEngine? = nil,
        permissionManager: KeyboardPermissionManager? = nil,
        launchAtLoginManager: LaunchAtLoginManager? = nil
    ) {
        let resolvedAudioEngine = providedAudioEngine ?? AudioPlaybackEngine()
        let resolvedPermissionManager = permissionManager ?? .shared
        let resolvedLaunchAtLoginManager = launchAtLoginManager ?? .shared

        self.channel = channel
        self.defaults = defaults
        self.audioEngine = resolvedAudioEngine
        self.permissionManager = resolvedPermissionManager
        self.launchAtLoginManager = resolvedLaunchAtLoginManager

        let soundPackID = defaults.string(forKey: DefaultsKey.selectedSoundPackID) ?? SoundPackLibrary.all.first?.id ?? "linear"
        let savedVolume = defaults.object(forKey: DefaultsKey.masterVolume) as? Double ?? 0.74
        let savedEnabled = defaults.object(forKey: DefaultsKey.isEnabled) as? Bool ?? true
        let storedLaunchAtLogin = defaults.object(forKey: DefaultsKey.launchAtLoginEnabled) as? Bool
        let actualLaunchAtLogin = resolvedLaunchAtLoginManager.isEnabled()

        isEnabled = savedEnabled
        selectedSoundPackID = soundPackID
        masterVolume = savedVolume
        launchAtLoginEnabled = storedLaunchAtLogin ?? actualLaunchAtLogin
        hasCompletedOnboarding = defaults.object(forKey: DefaultsKey.hasCompletedOnboarding) as? Bool ?? false

        hasLoadedSettings = true
        resolvedAudioEngine.activatePack(id: soundPackID)
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
        KeyTokLogger.permissions.info("Keyboard access requested. Granted: \(granted, privacy: .public)")
        restartKeyboardEventSource()
    }

    public func openPrivacySettings() {
        permissionManager.openSystemSettings()
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

    private func restartKeyboardEventSource() {
        keyboardEventSource?.stop()
        keyboardEventSource = KeyboardEventSourceFactory.make(
            channel: channel,
            permissionStatus: permissionStatus
        ) { [weak self] keyEvent in
            self?.handleKeyEvent(keyEvent)
        }

        activeBackend = keyboardEventSource?.backend ?? .eventMonitor
        KeyTokLogger.input.info("Keyboard backend active: \(self.activeBackend.rawValue, privacy: .public)")
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
            KeyTokLogger.app.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
