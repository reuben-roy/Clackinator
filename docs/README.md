# Clackinator developer docs

Clackinator is a native macOS menu bar app with two distribution targets and one shared core framework. The core handles keyboard capture, input permission state, sound-pack generation/import, low-latency playback, onboarding, and settings.

## Docs map

| Document | Use it for |
| --- | --- |
| [Developer guide](developer-guide.md) | Local Xcode/project generation, app targets, tests, and debugging |
| [Customization guide](customization.md) | Sound packs, settings, channels, and user-facing extension points |
| [Release](release.md) | Existing direct-release packaging and distribution workflow |
| [App Store validation](app-store-validation.md) | Existing App Store target validation notes |

## Main repository areas

| Path | Responsibility |
| --- | --- |
| `App/Direct/` | Direct distribution app shell and delegate |
| `App/AppStore/` | Mac App Store app shell and delegate |
| `Core/App/` | Coordinator and settings window controller |
| `Core/Input/` | Keyboard event sources, backend selection, key classification |
| `Core/Audio/` | Playback engine, sound packs, synthesis, sample slicing, custom pack storage |
| `Core/UI/` | Menu bar and settings SwiftUI views |
| `Core/Support/` | Permissions, logging, launch-at-login |
| `Config/` | Plists and entitlements for app targets |
| `Tests/ClackinatorCoreTests/` | Unit tests for core behavior |
| `script/` | Project generation, build/run, packaging, Homebrew cask rendering |

## Maintenance rule

Regenerate and commit `Clackinator.xcodeproj` whenever Swift files, targets, resources, or tests are added or removed.
