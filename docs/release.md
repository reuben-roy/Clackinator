# Release Notes

## Local development

1. Regenerate the project after adding or removing Swift files:
   `ruby ./script/generate_xcodeproj.rb`
2. Build and run the direct target locally:
   `./script/build_and_run.sh`
3. Stream app logs:
   `./script/build_and_run.sh --telemetry`

## Direct / Homebrew release flow

1. Configure signing in Xcode or the CI environment for the `KeyTokDirect` target.
2. Create or update a notarytool keychain profile and export it as `NOTARY_KEYCHAIN_PROFILE`.
3. Run `./script/package_direct_release.sh <version>`.
4. Render a Homebrew cask file:
   `./script/render_homebrew_cask.rb <version> <sha256> <owner> <repo> <output>`
5. Upload the zipped app, generated checksum, and rendered cask file to the GitHub release.
6. Copy the rendered cask into your tap repository under `Casks/keytok.rb`.

The GitHub Actions `Direct Release` workflow automates those same steps when
the required secrets are present.

## App Store release flow

1. Open the generated Xcode project and select the `KeyTokAppStore` target.
2. Set the appropriate team, provisioning, and archive signing settings.
3. Run the validation gate from [docs/app-store-validation.md](/Users/reubenroy/github/hobby/KeyTok/docs/app-store-validation.md).
4. Archive the target, upload it to App Store Connect, and include reviewer notes that explain the keyboard-listening permission flow.
