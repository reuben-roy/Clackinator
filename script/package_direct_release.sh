#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: ./script/package_direct_release.sh <version>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/KeyTok.xcodeproj"
ARCHIVE_DIR="$ROOT_DIR/build/archives"
EXPORT_DIR="$ROOT_DIR/build/export"
ARCHIVE_PATH="$ARCHIVE_DIR/KeyTokDirect.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/KeyTokDirect.app"
ZIP_PATH="$EXPORT_DIR/KeyTokDirect-${VERSION}.zip"
SHA_PATH="$EXPORT_DIR/KeyTokDirect-${VERSION}.sha256"

mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"
rm -rf "$ARCHIVE_PATH" "$ZIP_PATH" "$SHA_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme KeyTokDirect \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive

codesign --verify --deep --strict "$APP_PATH"

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "$APP_PATH" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
fi

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | tee "$SHA_PATH"
