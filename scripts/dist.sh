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
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"

CHECK="$(mktemp -d)"
if ! { ditto -x -k "$ZIP" "$CHECK" && codesign --verify --deep --strict "$CHECK/NotchBox.app"; }; then
  rm -rf "$CHECK"
  echo "error: $ZIP failed signature verification" >&2
  exit 1
fi
rm -rf "$CHECK"
echo "Created $ZIP"
