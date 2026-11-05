#!/usr/bin/env bash
# Builds build/NotchBox.app (release): binary, Info.plist, translations, adapter. Ad-hoc signed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/NotchBox.app"

"$ROOT/scripts/build-adapter.sh"

swift build --package-path "$ROOT" -c release
BIN_DIR="$(swift build --package-path "$ROOT" -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$BIN_DIR/NotchBox" "$APP/Contents/MacOS/NotchBox"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Translations go straight into Contents/Resources (not a SwiftPM resource bundle) so that
# Bundle.main finds them and the bundle stays signable.
ditto "$ROOT/Resources/en.lproj" "$APP/Contents/Resources/en.lproj"
ditto "$ROOT/Resources/tr.lproj" "$APP/Contents/Resources/tr.lproj"
cp "$ROOT/Vendor/mediaremote-adapter/bin/mediaremote-adapter.pl" "$APP/Contents/Resources/mediaremote-adapter.pl"
ditto "$ROOT/build/adapter/MediaRemoteAdapter.framework" "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
