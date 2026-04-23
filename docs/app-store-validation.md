# App Store Validation Gate

The App Store target is intentionally separate from the direct/Homebrew target.
Before shipping `KeyTokAppStore`, validate these behaviors with a signed
sandboxed build on the latest public macOS release:

1. Install the `KeyTokAppStore` target from Xcode or TestFlight-equivalent internal distribution.
2. Launch the app and confirm the onboarding window explains the keyboard-access flow.
3. Grant keyboard listening access when prompted.
4. Type in TextEdit, Safari, Terminal, and another sandboxed third-party app.
5. Confirm `NSEvent` monitoring receives background key down events consistently after the permission grant.
6. Revoke access and confirm the status UI falls back to a local-only warning.
7. Re-enable access in System Settings and verify recovery without reinstalling.

If any of those steps fail, keep the App Store release delayed and ship the
direct/Homebrew channel first.
