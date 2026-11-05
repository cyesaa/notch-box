#!/usr/bin/env bash
# Builds MediaRemoteAdapter.framework and MediaRemoteAdapterTestClient from the vendored submodule
# with plain clang (no CMake).
# Output (ad-hoc signed):
#   build/adapter/MediaRemoteAdapter.framework   (versioned layout)
#   build/adapter/MediaRemoteAdapterTestClient   (helper for the adapter's `test` command)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Vendor/mediaremote-adapter"
OUT="$ROOT/build/adapter"
FW="$OUT/MediaRemoteAdapter.framework"
CLIENT="$OUT/MediaRemoteAdapterTestClient"

if [ ! -f "$SRC/bin/mediaremote-adapter.pl" ]; then
  echo "error: adapter sources missing. Run: git submodule update --init" >&2
  exit 1
fi

rm -rf "$FW" "$CLIENT"
mkdir -p "$FW/Versions/A/Resources"

cd "$SRC"
shopt -s nullglob
# Same source set as ADAPTER_SOURCES in the upstream CMakeLists.txt.
SOURCES=(src/adapter/*.m src/private/*.m src/utility/*.m)
if [ ${#SOURCES[@]} -eq 0 ]; then
  echo "error: no adapter sources found in $SRC/src" >&2
  exit 1
fi

clang -dynamiclib \
  -fobjc-arc -fmodules -fvisibility=default \
  -arch arm64 -mmacosx-version-min=14.0 \
  -Iinclude -Isrc \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name "@rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter" \
  -o "$FW/Versions/A/MediaRemoteAdapter" \
  "${SOURCES[@]}"

cat > "$FW/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
  <key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>MediaRemoteAdapter</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
</dict>
</plist>
PLIST

ln -s A "$FW/Versions/Current"
ln -s Versions/Current/MediaRemoteAdapter "$FW/MediaRemoteAdapter"
ln -s Versions/Current/Resources "$FW/Resources"

codesign --force --sign - "$FW"
echo "Built $FW"

# Same sources and frameworks as the MediaRemoteAdapterTestClient target in the upstream CMakeLists.txt.
# -Wno-gnu-folding-constant: upstream main.m sizes a stack buffer with a `static const`, which clang flags.
TEST_SOURCES=(src/test/main.m src/test/NowPlayingTest.m)
clang \
  -fobjc-arc -fmodules -Wno-gnu-folding-constant \
  -arch arm64 -mmacosx-version-min=14.0 \
  -Isrc/test \
  -framework Foundation -framework MediaPlayer \
  -o "$CLIENT" \
  "${TEST_SOURCES[@]}"

codesign --force --sign - "$CLIENT"
echo "Built $CLIENT"
