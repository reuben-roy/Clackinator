# Developer guide

## Prerequisites

- macOS
- Xcode with Swift toolchain
- Ruby for project generation scripts
- Input Monitoring permission when testing global key capture

## Project generation

`Clackinator.xcodeproj` is generated. Do not hand-edit it unless the generator cannot express the required change.

```bash
ruby ./script/generate_xcodeproj.rb
```

Run the generator after adding or removing Swift files, resources, tests, or targets.

## Build and run

Direct channel:

```bash
./script/build_and_run.sh
```

With log streaming:

```bash
./script/build_and_run.sh --telemetry
```

The direct target can use the listen-only event tap path when Input Monitoring is granted. The App Store target uses monitor-based capture to stay within sandbox expectations.

## Targets

| Target | Purpose |
| --- | --- |
| `ClackinatorCore` | Shared app logic, input, audio, permissions, settings, and UI |
| `ClackinatorDirect` | Developer ID / direct distribution app |
| `ClackinatorAppStore` | Sandboxed App Store build path |
| `ClackinatorCoreTests` | Unit tests for shared core behavior |

## Runtime flow

1. App shell starts and creates `ClackinatorCoordinator`.
2. Coordinator loads persisted settings from `UserDefaults`.
3. Coordinator selects a keyboard event source through `KeyboardEventSourceFactory`.
4. Key events are translated into `KeyEvent` values.
5. `KeyClassifier` maps events to key classes.
6. `AudioPlaybackEngine` picks a buffer from the active `SoundPack`.
7. A pooled player node schedules playback at the configured volume.

Keep UI code thin. Product behavior belongs in `Core/` so both distribution channels stay aligned.

## Keyboard permissions

Global capture depends on Input Monitoring. Permission state is managed through `KeyboardPermissionManager` and persisted through `hasRequestedKeyboardPermission` so the UI can distinguish first-run unknown state from a denied state.

When debugging capture issues:

- Confirm the app is listed under System Settings > Privacy & Security > Input Monitoring.
- Remove and re-add permission after changing bundle IDs.
- Restart the app after granting access.
- Check whether the direct build is using event tap or monitor fallback.

## Tests

Run tests from Xcode or through `xcodebuild` against the generated project. Unit tests currently cover coordinator behavior, sound-pack library behavior, sampled rendering, key classification, and custom sound-pack storage.

Focus new tests on pure core behavior. Avoid depending on system permissions or real keyboard events in unit tests.

## Release references

Use [release.md](release.md) for direct packaging and Homebrew cask flow. Use [app-store-validation.md](app-store-validation.md) for the App Store channel.
