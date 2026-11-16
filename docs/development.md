# Developing NotchBox

What you need to build, test and release NotchBox. For what the app does and how to install it, see the
[README](../README.md).

## Building

Needs only the Xcode Command Line Tools with Swift 6 or later (Xcode 16 tools; `xcode-select --install`); Xcode
itself is optional.

```bash
git clone --recursive https://github.com/cyesaa/notch-box.git
make test   # unit tests (Swift Testing)
make run    # build build/NotchBox.app and open it
make dist   # dist/NotchBox-<version>.zip
```

- Do not use `@State` or `#Preview`: with only the Command Line Tools, the SwiftUI macro plugin is missing.
  Keep view state in `NotchViewModel` or another `@Observable` class.
- Accessibility and System Audio Recording permissions are tied to the app's signature. Ad-hoc signed builds
  get a new signature on every build, so you may need to grant them again while developing.
- Before a release, go through [manual-testing.md](manual-testing.md).
- There are no Xcode previews. To look at every notch state with sample data, run
  `build/NotchBox.app/Contents/MacOS/NotchBox --render-snapshots /tmp/notch` after `make app`
  (add `-AppleLanguages '(tr)'` for Turkish); it writes PNGs and exits.
- `make icon` redraws `Resources/AppIcon.icns` from `scripts/make-icon.swift`.
- The pictures in the README (`docs/images/<language>/`) are those snapshots, cropped, with a menu bar drawn
  beside the panel.

## Releasing

From a clean `main` that matches `origin/main`:

```bash
make release VERSION=0.2.0            # DRY_RUN=1 make release VERSION=0.2.0 to rehearse
```

This sets the version, runs the tests, builds the zip, commits and tags `v0.2.0`, pushes, and publishes a GitHub
release with generated notes and `NotchBox.zip` attached (the file `install.sh` downloads). It uses `GITHUB_TOKEN`
if set, otherwise the github.com login git already has. Releases can be made while the repository is private;
the one-line installer works for others only while it is public.

## How "Now Playing" is read

Since macOS 15.4, apps cannot read "Now Playing" info directly. NotchBox bundles
[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), which reads it through the system's
Apple-signed `/usr/bin/perl`. This is not an official Apple API, and a future macOS update may break it.

If the adapter fails to start or keeps crashing, NotchBox switches to a limited mode: it can no longer show the
track, but the buttons keep working through media keys (this needs Accessibility permission, asked only then).
A macOS update could also block the data silently while the adapter keeps running. To catch that, NotchBox runs
the adapter's own test at launch, after waking from sleep and every 30 minutes, and switches to the same limited
mode if the test fails. Track info from a player, or a later passing test, switches it back.

When nothing is playing, the test briefly publishes a placeholder track ("Is It Broken Yet?") so that it has
something to read. It may flash in Control Center or other "Now Playing" widgets; NotchBox does not show it.
