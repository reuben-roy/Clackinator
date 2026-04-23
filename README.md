# KeyTok

KeyTok is a native macOS menu bar utility that plays original mechanical-style
keyboard sounds while you type. The repo ships two app targets:

- `KeyTokDirect` for Developer ID / Homebrew distribution
- `KeyTokAppStore` for the sandbox-validation path toward the Mac App Store

Shared behavior lives in the `KeyTokCore` framework:

- global key event capture via `NSEvent` monitors and a listen-only Quartz event tap
- generated sound packs for `Linear`, `Tactile`, and `Clicky`
- a low-latency `AVAudioEngine` playback pool
- onboarding, permission guidance, preset selection, and launch-at-login

## Getting started

1. Regenerate the Xcode project:
   `ruby ./script/generate_xcodeproj.rb`
2. Build and run the direct target:
   `./script/build_and_run.sh`
3. Open the settings window from the menu bar icon and grant keyboard access.

## Repository layout

- `App/` contains the two thin app wrappers.
- `Core/` contains the shared framework code.
- `Tests/` contains `KeyTokCore` unit tests.
- `Config/` contains target plists and entitlements.
- `script/` contains project generation, local build, release, and cask helpers.
- `.github/workflows/` contains CI and direct-release automation.
