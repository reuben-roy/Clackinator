import AppKit
import SwiftUI

public struct MenuBarContentView: View {
    @ObservedObject private var coordinator: ClackinatorCoordinator

    public init(coordinator: ClackinatorCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clackinator")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(coordinator.statusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Settings") {
                    coordinator.presentSettings()
                }
                .buttonStyle(.link)
            }

            Toggle("Enable keyboard sounds", isOn: $coordinator.isEnabled)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sound Pack")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Preview") {
                        coordinator.previewSelectedSoundPack()
                    }
                    .buttonStyle(.link)
                }

                Picker("Sound Pack", selection: $coordinator.selectedSoundPackID) {
                    ForEach(coordinator.availableSoundPacks) { pack in
                        Text(pack.name).tag(pack.id)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(coordinator.masterVolume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $coordinator.masterVolume, in: 0...1)
            }

            Toggle("Launch at login", isOn: $coordinator.launchAtLoginEnabled)

            if coordinator.permissionStatus != .granted {
                permissionCard
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Backend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(coordinator.backendSummary)
                    .font(.caption)
                Text(coordinator.activeBackend.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let launchAtLoginError = coordinator.launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Open Settings") {
                    coordinator.presentSettings()
                }

                Spacer()

                Button("Quit") {
                    coordinator.shutdown()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder
    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(coordinator.permissionStatus.title)
                .font(.subheadline.weight(.semibold))
            Text(coordinator.permissionStatus.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Request Access") {
                    coordinator.requestKeyboardAccess()
                }

                Button("Privacy Settings") {
                    coordinator.openPrivacySettings()
                }
                .buttonStyle(.link)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
