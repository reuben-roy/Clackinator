import SwiftUI

public struct SettingsWindowView: View {
    @ObservedObject private var coordinator: KeyTokCoordinator

    public init(coordinator: KeyTokCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                permissionSection
                soundSection
                behaviorSection
                statusSection
                footer
            }
            .padding(24)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 540)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.16, blue: 0.18).opacity(0.16),
                    Color(red: 0.06, green: 0.11, blue: 0.16).opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KeyTok")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Mechanical keyboard presence for every app on your Mac.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: coordinator.menuBarSymbolName)
                    .font(.system(size: 34))
                    .foregroundStyle(.teal)
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Text("Current preset: \(coordinator.selectedSoundPack?.name ?? "Unknown")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionSection: some View {
        SettingsCard(title: "Keyboard Access", subtitle: coordinator.permissionStatus.summary) {
            HStack(spacing: 10) {
                statusBadge(title: coordinator.permissionStatus.title)

                Spacer()

                Button("Request Access") {
                    coordinator.requestKeyboardAccess()
                }

                Button("Open Privacy Settings") {
                    coordinator.openPrivacySettings()
                }
            }
        }
    }

    private var soundSection: some View {
        SettingsCard(title: "Sound Packs", subtitle: "Three built-in presets ship with original generated sounds for standard, modifier, navigation, return, delete, and space keys.") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(coordinator.availableSoundPacks) { pack in
                    Button {
                        coordinator.selectedSoundPackID = pack.id
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: coordinator.selectedSoundPackID == pack.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(coordinator.selectedSoundPackID == pack.id ? .teal : .secondary)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(pack.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(pack.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(coordinator.selectedSoundPackID == pack.id ? Color.teal.opacity(0.12) : Color.primary.opacity(0.03))
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Button("Preview Selected Pack") {
                        coordinator.previewSelectedSoundPack()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
        }
    }

    private var behaviorSection: some View {
        SettingsCard(title: "Behavior", subtitle: "KeyTok stays local, offline, and lightweight. Settings are stored in UserDefaults.") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable keyboard sounds", isOn: $coordinator.isEnabled)
                Toggle("Launch at login", isOn: $coordinator.launchAtLoginEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Master Volume")
                        Spacer()
                        Text("\(Int(coordinator.masterVolume * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $coordinator.masterVolume, in: 0...1)
                }

                if let launchAtLoginError = coordinator.launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusSection: some View {
        SettingsCard(title: "Runtime", subtitle: "The direct build prefers a listen-only Quartz event tap. The App Store build uses AppKit monitors until the sandbox path is fully validated.") {
            VStack(alignment: .leading, spacing: 10) {
                runtimeRow(label: "Channel", value: coordinator.channel.displayName)
                runtimeRow(label: "Backend", value: coordinator.backendSummary)
                runtimeRow(label: "Status", value: coordinator.statusSummary)
            }
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("No analytics. No cloud sync. No copied Klack assets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("App Store release remains gated on validated sandbox behavior for background key listening.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(coordinator.hasCompletedOnboarding ? "Close" : "Finish Setup") {
                coordinator.finishOnboarding()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func runtimeRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
