# Clackinator (KeyTok)

> A native macOS menu bar utility that plays satisfying mechanical keyboard sounds as you type.

## What It Does

KeyTok sits in your macOS menu bar and plays real-time mechanical-style audio feedback for every keystroke. It captures global keyboard events and maps them to synthesized sound packs — so typing feels tactile even on a MacBook butterfly keyboard or an external membrane board.

### Sound Packs

Three synthesized profiles are included, each tuned with pitch jitter and key-class variation:

- **Linear** — Smooth, thocky downstrokes and upstrokes (think red switches).
- **Tactile** — A subtle bump before actuation (think brown switches).
- **Clicky** — Crisp, audible click on press (think blue switches).

## Tech Stack

| Layer | Technology |
|-------|------------|
| Platform | macOS (Swift, AppKit) |
| Architectures | Apple Silicon & Intel (universal) |
| Audio | `AVAudioEngine` with low-latency PCM buffer playback |
| Event Capture | `NSEvent` global monitors + Quartz listen-only event tap |
| Distribution | Developer ID (direct) & Mac App Store (sandbox) targets |
| Packaging | Homebrew Cask + GitHub Releases automation |

## Quick Start

```bash
# 1. Generate the Xcode project
ruby ./script/generate_xcodeproj.rb

# 2. Build and run the direct-distribution target
./script/build_and_run.sh

# 3. Grant keyboard access when prompted, then type anywhere.
```

## Project Structure

```
App/
  AppStore/           # Mac App Store wrapper (sandbox entitlement path)
  Direct/             # Developer ID / Homebrew wrapper
Core/
  App/                # Coordinator, settings window controller
  Audio/              # SoundPack, SoundPackLibrary, synthesis, playback engine
  Input/              # Keyboard event sources (monitor vs event tap)
  Models/             # KeyEvent, KeyClass, AppChannel
  Support/            # Permissions, launch-at-login, logging
  UI/                 # Menu bar SwiftUI views, settings window
Tests/
  KeyTokCoreTests/
Config/
  Plists & entitlements for both targets
script/
  generate_xcodeproj.rb       # Rebuild the Xcode project
  build_and_run.sh          # Local dev loop
  package_direct_release.sh # GitHub Release packaging
  render_homebrew_cask.rb   # Homebrew Cask ERB template
Homebrew/
  Casks/keytok.rb.erb       # Homebrew formula template
docs/
  app-store-validation.md   # Mac App Store review notes
  release.md                # Release checklist
```

## Two Build Targets

| Target | Use Case | How to Build |
|--------|----------|--------------|
| `KeyTokDirect` | Side-loading, Developer ID, Homebrew | `./script/build_and_run.sh` or Xcode |
| `KeyTokAppStore` | Mac App Store review sandbox | Xcode → `KeyTokAppStore` scheme |

Both targets share the same `KeyTokCore` framework. The only differences are entitlements and the app wrapper.

## How It Works

1. **Event Capture** — `KeyboardEventSourceFactory` selects the best backend:
   - If Accessibility permission is **granted** → low-latency `CGEventTap` (works across all apps).
   - If permission is **denied / unknown** → `NSEvent` global monitor (works only inside the app).
2. **Key Classification** — Keystrokes are classified by key family (spacebar, modifier, alphanumeric, etc.).
3. **Audio Playback** — `AudioPlaybackEngine` maintains an `AVAudioEngine` graph and plays random samples per key class + phase (press / release), applying master volume and pitch jitter.
4. **Persistence** — All preferences (enabled, pack, volume, launch-at-login) are stored in `UserDefaults`.

## Configuration

Open the settings window from the menu bar icon to:

- Toggle sounds on/off
- Pick a sound pack
- Adjust master volume
- Enable / disable launch at login
- Grant or re-check keyboard accessibility permissions

## CI / Release

| Workflow | File | What it does |
|----------|------|--------------|
| CI | `.github/workflows/ci.yml` | Builds both targets, runs unit tests |
| Direct Release | `.github/workflows/direct-release.yml` | Packages a signed `.zip` and uploads to GitHub Releases |

For a manual release:

```bash
./script/package_direct_release.sh
```

## License

No explicit LICENSE file. Assume all rights reserved unless otherwise stated.

---

Typed with care by [Reuben Roy](https://github.com/reuben-roy).
