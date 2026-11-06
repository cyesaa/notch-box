#!/bin/bash
# Installs, updates or removes NotchBox.
#
#   Install or update:  curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash
#   A given version:    curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | NOTCHBOX_VERSION=0.2.0 bash
#   Uninstall:          curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash -s -- --uninstall
#
# Files downloaded with curl are not quarantined, so macOS does not block the (not notarized) app.
# For testing: NOTCHBOX_ZIP=<local zip> uses that file instead of downloading, NOTCHBOX_DEST=<dir>
# installs somewhere else, NOTCHBOX_NO_OPEN=1 does not start the app afterwards.
set -euo pipefail

REPO="cyesaa/notch-box"
BUNDLE_ID="com.notchbox.NotchBox"
APP="NotchBox.app"
ASSET="NotchBox.zip"

WORK=""
cleanup() { [ -z "$WORK" ] || rm -rf "$WORK"; }
trap cleanup EXIT

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

check_mac() {
  [ "$(uname -s)" = "Darwin" ] || fail "NotchBox runs only on macOS."
  [ "$(uname -m)" = "arm64" ] || fail "NotchBox needs a Mac with Apple silicon (MacBooks with a notch)."
  local major
  major="$(sw_vers -productVersion | cut -d. -f1)"
  [ "$major" -ge 14 ] || fail "NotchBox needs macOS 14 or later (this Mac has $(sw_vers -productVersion))."
}

# /Applications when it is writable, otherwise ~/Applications (no admin rights needed).
destination() {
  if [ -n "${NOTCHBOX_DEST:-}" ]; then
    echo "$NOTCHBOX_DEST"
  elif [ -w /Applications ]; then
    echo /Applications
  else
    echo "$HOME/Applications"
  fi
}

# -a: pgrep and pkill skip their own ancestors by default, and when NotchBox runs this script to update
# itself, NotchBox is one of them.
quit_running_app() {
  pgrep -ax NotchBox >/dev/null || return 0
  say "Quitting the running NotchBox"
  pkill -ax NotchBox || true
  for _ in $(seq 1 50); do
    pgrep -ax NotchBox >/dev/null || return 0
    sleep 0.1
  done
  fail "NotchBox did not quit. Quit it from its menu bar icon and run this again."
}

install() {
  check_mac
  local dest zip
  dest="$(destination)"
  WORK="$(mktemp -d)"

  if [ -n "${NOTCHBOX_ZIP:-}" ]; then
    zip="$NOTCHBOX_ZIP"
    say "Using $zip"
  else
    local url
    if [ -n "${NOTCHBOX_VERSION:-}" ]; then
      url="https://github.com/$REPO/releases/download/v${NOTCHBOX_VERSION#v}/$ASSET"
    else
      url="https://github.com/$REPO/releases/latest/download/$ASSET"
    fi
    zip="$WORK/$ASSET"
    say "Downloading NotchBox ${NOTCHBOX_VERSION:-(latest)}"
    curl -fL --progress-bar "$url" -o "$zip" \
      || fail "Download failed: $url. The repository may be private right now, or there is no such release."
  fi

  ditto -x -k "$zip" "$WORK/unpacked" || fail "The download is not a valid zip."
  [ -d "$WORK/unpacked/$APP" ] || fail "The zip does not contain $APP."
  codesign --verify --deep --strict "$WORK/unpacked/$APP" 2>/dev/null || fail "$APP failed its signature check."

  quit_running_app
  mkdir -p "$dest"
  rm -rf "${dest:?}/$APP"
  ditto "$WORK/unpacked/$APP" "$dest/$APP"
  # Only browsers add this, but a zip someone passed along may carry it.
  xattr -dr com.apple.quarantine "$dest/$APP" 2>/dev/null || true

  local version
  version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$dest/$APP/Contents/Info.plist" 2>/dev/null || echo "?")"
  say "Installed NotchBox $version in $dest"
  if [ -z "${NOTCHBOX_NO_OPEN:-}" ]; then
    open "$dest/$APP"
    say "NotchBox is running: look for the music note in the menu bar and hover the notch."
  fi
  echo "    macOS may ask for permissions the first time they are needed:"
  echo "    System Audio Recording (waveform), Automation (watching a browser video in the notch),"
  echo "    Accessibility (only if NotchBox cannot read track info)."
}

uninstall() {
  quit_running_app
  local removed=0 dir dirs
  # With NOTCHBOX_DEST (a test install) only that copy goes; settings and permissions stay.
  if [ -n "${NOTCHBOX_DEST:-}" ]; then
    dirs=("$NOTCHBOX_DEST")
  else
    dirs=(/Applications "$HOME/Applications")
  fi
  for dir in "${dirs[@]}"; do
    [ -d "$dir/$APP" ] || continue
    rm -rf "${dir:?}/$APP"
    say "Removed $dir/$APP"
    removed=1
  done
  [ "$removed" = 1 ] || say "NotchBox was not installed in ${dirs[*]}."
  [ -z "${NOTCHBOX_DEST:-}" ] || return 0
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset All "$BUNDLE_ID" >/dev/null 2>&1 || true
  say "Removed NotchBox's settings and permissions."
}

case "${1:-}" in
  --uninstall) uninstall ;;
  "") install ;;
  *) fail "Unknown option: $1 (use --uninstall to remove NotchBox)" ;;
esac
