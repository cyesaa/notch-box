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
- [ ] The only permission prompt in normal use is System Audio Recording, the first time music plays.

## Playback (repeat for each source)

Sources: Spotify (not tested for 0.1.0), Apple Music, YouTube in Safari, YouTube in Chrome.

- [ ] While playing, mini artwork shows left of the notch and the waveform moves right of it.
- [ ] Pausing flattens the waveform.
- [ ] Hovering shows artwork, title, artist, album (when the player sends one) and the source app icon.
- [ ] The small shadow around the cover, the progress bar and the waveform take the cover's colour; a grey cover
  gives a neutral light tint.
- [ ] Changing to a track with a differently coloured cover fades the tint over about half a second.
- [ ] Buttons shrink slightly while pressed; dragging the progress bar makes it thicker.
- [ ] With System Settings → Accessibility → Display → Reduce motion on, the waveform holds still while playing.
- [ ] The first time music plays, macOS asks for System Audio Recording; the app keeps responding while the prompt is open.
- [ ] After allowing it, the mini waveform follows the music (bass on the left, treble on the right), drops when the
  music gets quiet and lies flat on pause. The log (`/usr/bin/log stream --level info --predicate 'subsystem == "com.notchbox.NotchBox"'`)
  shows "Audio levels live".
- [ ] With the permission turned off in System Settings → Privacy & Security → Screen & System Audio Recording,
  the waveform still moves (on its own) while playing.
- [ ] The notch's top corners curve into the screen edge in the mini and open states, and a soft shadow sits under it.
- [ ] A YouTube video's 16:9 thumbnail is cropped to a square and never covers the title.
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

## Mini notch buttons and volume

- [ ] While playing, pointing at the mini waveform shows a pause button and does not open the panel; clicking it pauses.
- [ ] While paused (within 5 minutes), a play button sits where the waveform was; clicking it resumes.
- [ ] Pointing at the cover or the notch still opens the full player.
- [ ] Changing the volume with the keyboard slides a rounded level bar out under the notch (under the mini row
  while playing) for about 1.5 s; the bar and number follow each step.
- [ ] Changing the volume while the full player is open shows no extra bar (the player's own bar moves).
- [ ] No volume bar appears when NotchBox starts.

## Timeouts and system events

- [ ] After pausing for 5 minutes the mini artwork disappears; hovering still opens the player.
- [ ] Changing volume with the keyboard moves the volume slider.
- [ ] Dragging the volume slider changes the system volume.
- [ ] On an output without volume control (e.g. some HDMI displays) the volume slider is dimmed.
- [ ] Plugging or unplugging an external display keeps the panel on the built-in screen.
- [ ] With the lid closed on an external display, nothing appears; reopening the lid brings the panel back.
- [ ] After sleep and wake, track info updates again.

## Installer

Needs the repository to be public and a published release.

- [ ] `curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash` installs NotchBox into
  `/Applications`, opens it, and macOS shows no "unidentified developer" warning.
- [ ] Running it again while NotchBox runs quits it, replaces it and opens the new copy.
- [ ] `… | bash -s -- --uninstall` removes the app, its settings and its permissions.
- [ ] While the repository is private, the installer stops with "The repository may be private right now".

## Updates

A fake newer release and a local install make this testable while the repository is private:

```bash
echo '{"tag_name":"v9.0.0","html_url":"https://github.com/cyesaa/notch-box/releases","draft":false}' > /tmp/release.json
defaults write com.notchbox.NotchBox UpdateFeedURL file:///tmp/release.json
defaults write com.notchbox.NotchBox UpdateInstallCommand "NOTCHBOX_ZIP=$PWD/dist/NotchBox-<version>.zip NOTCHBOX_DEST=/tmp/nb bash $PWD/install.sh"
```

- [ ] About 15 seconds after start a dot appears on the menu bar icon and the menu starts with a bold
  "Update available: NotchBox 9.0.0".
- [ ] Clicking it asks Update / What's New / Later. Update quits NotchBox and opens the new copy: only one
  menu bar icon is left. ~/Library/Logs/NotchBox/update.log has the installer's output.
- [ ] Make the install command fail (`UpdateInstallCommand 'exit 3'`): an alert says the update could not be
  installed, the real install command is on the clipboard and Finder shows update.log.
- [ ] "Check for Updates…" with no newer release says NotchBox is up to date; with the repository private (and
  no feed override) it says the check failed.
- [ ] "Check for Updates Automatically" off: no check after start (no dot).
- [ ] Clean up: `defaults delete com.notchbox.NotchBox UpdateFeedURL` and the same for `UpdateInstallCommand`.

## Watching in the notch

- [ ] Play a YouTube video in Chrome and hover the notch: the Chrome icon sits left of the camera, the waveform
  right of it, and a picture-in-picture button sits at the right end of the controls. It is not there for Apple Music.
- [ ] Press it: macOS asks once whether NotchBox may control Google Chrome. After allowing it, Chrome pauses and the
  notch opens a video panel that plays the same video from about the same moment, with sound.
- [ ] Put Chrome behind other windows: the video keeps playing in the notch, and the panel stays open when the
  cursor leaves it.
- [ ] The Chrome icon and the X sit beside the camera; the video starts right below the notch.
- [ ] Moving the cursor onto the video panel from below or from the side fades the panel and video to almost
  invisible; the windows behind it show through and can be clicked; only the X stays fully visible.
- [ ] Moving the cursor onto the video panel down from the menu bar keeps it fully visible, and YouTube's own
  controls (play, seek bar, settings) work. It stays that way until the cursor leaves the panel.
- [ ] Moving the cursor away brings the video back at full opacity.
- [ ] The X closes the panel with one click; Chrome stays paused at the position where the notch player stopped.
- [ ] Without a video, the open player still takes clicks as before (buttons, progress bar, volume).
- [ ] With two YouTube tabs open, the panel shows the one whose title matches what was playing.
- [ ] With a second copy of Chrome running (`open -n -a "Google Chrome" --args --user-data-dir=/tmp/chrome2`), the
  video in your normal Chrome still moves into the notch.
- [ ] With the Automation permission denied (System Settings → Privacy & Security → Automation), the player shows
  "Allow NotchBox under Privacy & Security → Automation" for a few seconds.
- [ ] A video whose owner disabled embedding closes the panel and shows "This video can only be watched on YouTube".
- [ ] Repeat with Safari.

## Clipboard

- [ ] Hover the notch: the player grows to the left with a "Clipboard" column; the player itself stays centred
  under the notch, and moving the cursor over the clipboard column keeps the panel open.
- [ ] With nothing copied yet the column says copied text and images show up there. (Whatever was on the
  pasteboard when NotchBox started is the first item.) If macOS asks whether NotchBox may paste from other apps,
  allow it.
- [ ] Copy some text in any app: it appears at the top on one line. Copy an image (a screenshot with
  ⌃⇧⌘4, or "Copy Image" in a browser): it appears with a thumbnail and its size in pixels.
- [ ] Copy the same text again: it moves to the top instead of showing twice.
- [ ] Copy more than 20 things: the list keeps the newest 20 and scrolls.
- [ ] Click an older item: it shows "Copied", moves to the top, and ⌘V pastes it in another app (text and image).
- [ ] Each row's × removes just that item (right-click → Remove does the same); the bin clears the list.
- [ ] An image row has an eye: it shows the image large in place of the player, with its size, a copy button and
  an × that brings the player back. Closing the notch also closes the image.
- [ ] Copy a password from a password manager (or a file in Finder): it is not added.
- [ ] Quit and reopen NotchBox: the list starts over.

## Calendar

- [ ] Hover the notch: a calendar column as wide as the clipboard sits right of the player; the panel is
  symmetric around the notch and the player stays centred under it.
- [ ] Before access is given, the column offers "Show my calendar". Pressing it shows macOS's calendar prompt once;
  after allowing, the week strip and today's remaining events appear without reopening the notch.
- [ ] The strip shows this week from your first weekday; today is filled white, days with events have a dot.
  Clicking another day rings it, shows its date in the header and lists all its events ("No events" if none).
  Closing and reopening the notch goes back to today.
- [ ] All-day events come first; a running event is highlighted and says "Now · until <time>"; one starting within
  15 minutes says "in N min".
- [ ] An event with a Zoom / Meet / Teams link has a green Join button that opens the call; clicking the event
  opens Calendar.
- [ ] Add or move an event in Calendar while the notch is open: the column updates.
- [ ] Deny access in System Settings → Privacy & Security → Calendars: the column says how to turn it back on.

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
