# Customization guide

Clackinator is already structured for customization through sound packs, settings, and distribution channels. Keep new customization work in the shared core unless it must differ by channel.

## Sound packs

Built-in sound packs come from two sources:

| Source | Code path | Notes |
| --- | --- | --- |
| Procedural synthesis | `Core/Audio/SoundSynthesis.swift` | Good for small, deterministic packs with no bundled assets |
| Bundled samples | `Core/Audio/Resources/`, `SampledSoundPackRenderer` | Good for real keyboard recordings |
| User imports | `CustomSoundPackStore` | One user-provided audio file is sliced and stored under Application Support |

When adding a built-in pack:

1. Add synthesis logic or audio resources.
2. Register the pack in the sound-pack library/catalog.
3. Add tests for catalog visibility or rendering behavior.
4. Regenerate the Xcode project if files or resources changed.

## User settings

Current user-facing preferences are persisted in `UserDefaults`:

| Setting | Purpose |
| --- | --- |
| `isEnabled` | Master sound toggle |
| `selectedSoundPackID` | Active sound pack |
| `masterVolume` | Playback volume multiplier |
| `launchAtLoginEnabled` | Login item registration |
| `hasCompletedOnboarding` | First-run settings prompt |
| `hasRequestedKeyboardPermission` | Permission state UX |

New settings should have a clear default, a UI control in settings, and coordinator-owned behavior. Avoid reading `UserDefaults` directly from many places.

## Per-user customization ideas

Good general-purpose additions:

- Per-app enable/disable rules
- Per-pack volume normalization
- Key-class volume controls
- Randomization amount
- Minimum interval/debounce for repeated keys
- Import/export of custom packs
- Multiple custom packs instead of one imported pack

Each of these should be implemented in `ClackinatorCore` so both direct and App Store targets share behavior.

## Channel-specific behavior

Only keep behavior channel-specific when it is required by distribution constraints:

| Channel | Reason to differ |
| --- | --- |
| Direct | Can prefer listen-only event tap and Developer ID distribution |
| App Store | Should prefer sandbox-compatible monitor behavior and App Store validation constraints |

If a feature can work in both channels, put it in core and gate only the permission/capability edge.

## Privacy boundary

Clackinator should not record typed text. Keyboard events should be used only for key classification and immediate sound playback. Do not add storage, telemetry, or logs that capture key values in a way that could reconstruct user input.
