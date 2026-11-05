#!/usr/bin/env bash
# Zips build/NotchBox.app into dist/NotchBox-<version>.zip for GitHub Releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/NotchBox.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ZIP="$ROOT/dist/NotchBox-$VERSION.zip"

if [ ! -d "$APP" ]; then
  echo "error: $APP not found. Run: make app" >&2
  exit 1
fi

mkdir -p "$ROOT/dist"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Created $ZIP"
