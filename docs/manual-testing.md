# Manual testing checklist

Run `make run` first. Tick every box before a release.

## Notch and hover

- [ ] With nothing playing, the notch looks unchanged.
- [ ] Hovering the notch opens a small "Nothing playing" panel after a short delay.
- [ ] Sweeping the cursor quickly across the top of the screen does not open the panel.
- [ ] Moving the cursor away closes the panel after about 0.3 s; coming back within that time keeps it open.
- [ ] Menu bar items right next to the notch can still be clicked while the panel is closed.
- [ ] Clicking a button in the panel while typing in TextEdit leaves the text cursor in TextEdit.
- [ ] The panel stays on screen when switching Spaces and over a full-screen app.
- [ ] No permission prompt appears during normal use.

## Playback (repeat for each source)

Sources: Spotify (not tested for 0.1.0), Apple Music, YouTube in Safari, YouTube in Chrome.

- [ ] While playing, mini artwork shows left of the notch and the waveform moves right of it.
- [ ] Pausing flattens the waveform.
- [ ] Hovering shows artwork, title, artist, album (when the player sends one) and the source app icon.
- [ ] The glow around the cover, the progress bar and the waveform take the cover's colour; a grey cover gives a
  neutral light tint, and the strip under the hardware notch stays solid black.
- [ ] Changing to a track with a differently coloured cover fades the tint over about half a second.
- [ ] Buttons shrink slightly while pressed; dragging the progress bar makes it thicker.
- [ ] With System Settings → Accessibility → Display → Reduce motion on, the waveform holds still while playing.
- [ ] Play/pause, next and previous work.
- [ ] Dragging the progress bar seeks; the bar does not jump back after release.
- [ ] Clicking the source app icon brings that app to the front.
- [ ] A very long title ends with "…".
- [ ] Changing tracks keeps the mini view; the old cover stays until the new one arrives (about 1 s at most), then crossfades with no music-note flash.

## Menu bar and quitting

- [ ] A music note icon appears in the menu bar and there is no Dock icon.
- [ ] "Launch at Login" toggles on and off (check System Settings → General → Login Items).
- [ ] "Quit NotchBox" quits the app; `pgrep -f mediaremote-adapter` then prints nothing.
- [ ] `pkill -x NotchBox` also quits cleanly; `pgrep -f mediaremote-adapter` then prints nothing.

## Timeouts and system events

- [ ] After pausing for 5 minutes the mini artwork disappears; hovering still opens the player.
- [ ] Changing volume with the keyboard moves the volume slider.
- [ ] Dragging the volume slider changes the system volume.
- [ ] On an output without volume control (e.g. some HDMI displays) the volume slider is dimmed.
- [ ] Plugging or unplugging an external display keeps the panel on the built-in screen.
- [ ] With the lid closed on an external display, nothing appears; reopening the lid brings the panel back.
- [ ] After sleep and wake, track info updates again.

## Health check

Watch the log in a second terminal. zsh has its own `log` command, so use the full path:
`/usr/bin/log stream --level info --predicate 'subsystem == "com.notchbox.NotchBox"'`

- [ ] Shortly after `make run`, the log shows "Adapter test passed".
- [ ] After sleep and wake, the log shows "Adapter test passed" again.
- [ ] Quit every player and close tabs that played media (a paused player still counts as playing), then `make run`.
  The log shows "Adapter test passed", hovering still shows "Nothing playing", and NotchBox never shows the
  "Is It Broken Yet?" test track (it may flash in Control Center).
- [ ] With nothing playing, `defaults write com.notchbox.NotchBox SimulateHealthCheckFailure -bool true`, then `make run`.
  Within a few seconds the log shows "Adapter test exited with status 2" and hovering shows "Can't read track info".
- [ ] Still simulating, start a track: its info and the mini view come back.
- [ ] `defaults delete com.notchbox.NotchBox SimulateHealthCheckFailure`, then `make run`: normal mode is back.

## Degraded mode

- [ ] `defaults write com.notchbox.NotchBox SimulateAdapterFailure -bool true`, then `make run`.
- [ ] Within about 10 s, hovering shows "Can't read track info" and "The buttons send media keys instead" with
  controls and no mini artwork.
- [ ] The first control press asks for Accessibility permission; after granting it (System Settings → Privacy & Security → Accessibility), the buttons control playback.
- [ ] `defaults delete com.notchbox.NotchBox SimulateAdapterFailure`, then `make run`: normal mode is back.

## Languages

- [ ] Quit NotchBox first, then `open build/NotchBox.app --args -AppleLanguages '(tr)'` shows Turkish strings.
- [ ] Quit NotchBox first, then `open build/NotchBox.app --args -AppleLanguages '(en)'` shows English strings.
