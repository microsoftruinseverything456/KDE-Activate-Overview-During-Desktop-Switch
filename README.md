# Activate Overview During Desktop Switch

A KWin script for KDE Plasma 6. With it, Overview, Grid View and Window View
(Present Windows) open as soon as you press their shortcut, even while a
virtual desktop slide is still animating. Plasma normally ignores the press
until the slide has finished.

## Install

Plasma 6.8, on Wayland.

```bash
bash tools/install.sh      # install or upgrade, and turn it on
bash tools/uninstall.sh    # remove
```

It starts right away, no logout needed. `tools/install.sh --no-enable`
installs it without turning it on.

Or from the KDE Store: System Settings › Window Management › KWin Scripts ›
Get New…, search for "Activate Overview During Desktop Switch", then tick it
and click Apply. KWin only picks up newly installed scripts when it starts, so
log out and back in once.

## Shortcuts

There's nothing to set up. While the script is on, it holds the keys of
Overview, Grid View, the two Cycle actions and Present Windows (Meta+W,
Meta+G, Meta+F9 and so on, including any you changed). They show up in System
Settings › Keyboard › Shortcuts as "Activate Overview During Desktop Switch:
…". Turning the script off or removing it gives the keys back.

To change a key while the script is on, change its "Activate Overview During
Desktop Switch: …" action.

## How it works

During a desktop switch, the Slide effect holds KWin's single full screen
effect slot, and the views refuse to start until it is free. When you press
one of the script's shortcuts during a slide, it unloads Slide, which ends the
animation on the desktop you were switching to. It then opens the view and
loads Slide again.

A press that KWin ignores still flips the view's on/off state, so in stock
Plasma the next press seems to be ignored too. The script checks that the view
really opened and presses again if it didn't.

## Limitations

- Only keyboard shortcuts are covered. Screen edges, hot corners and touchpad
  gestures behave as before.
- Only the Slide effect is handled, not other desktop switch animations.
- The script finds out which effects are running from KWin's support
  information text. If a future KWin changes that text, presses behave as in
  stock Plasma.
- If the script was installed during the current session, unticking it in
  System Settings takes effect after the next login. `tools/uninstall.sh`
  works right away.

## Development

```bash
bash tools/package.sh      # dist/interruptibleoverview-<version>.kwinscript
```

The script is `package/contents/ui/main.qml`. The `.kwinscript` file is what
the KDE Store and Get New… install from.

## License

GPL-2.0-or-later, see [LICENSE](LICENSE).
