#!/bin/bash
# Install or upgrade Activate Overview During Desktop Switch and turn it on.
#   tools/install.sh [--no-enable]
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENABLE=$([ "${1:-}" = "--no-enable" ] && echo 0 || echo 1)
scripting() { qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting."$@" 2>/dev/null || true; }
loaded() { [ "$(scripting isScriptLoaded overview-during-desktop-switch)" = true ]; }

if kpackagetool6 --type=KWin/Script --show overview-during-desktop-switch >/dev/null 2>&1; then
    kpackagetool6 --type=KWin/Script --upgrade "$ROOT/package"
else
    kpackagetool6 --type=KWin/Script --install "$ROOT/package"
fi
if [ "$ENABLE" = 1 ]; then
    kwriteconfig6 --file kwinrc --group Plugins --key overview-during-desktop-switchEnabled true
fi

# A running KWin doesn't see newly installed scripts, so (re)load it by hand.
if qdbus6 org.kde.KWin /KWin >/dev/null 2>&1 && { [ "$ENABLE" = 1 ] || loaded; }; then
    # KWin deletes an unloaded script a moment later and can't reload it before then.
    scripting unloadScript overview-during-desktop-switch >/dev/null
    for _ in $(seq 50); do
        loaded || break
        sleep 0.1
    done
    # KWin caches compiled QML by path, and Qt caches directory listings, so load
    # a copy from a new directory to get the new code. After the next login KWin
    # loads the installed file itself.
    dir=$(kpackagetool6 --type=KWin/Script --show overview-during-desktop-switch | sed -n 's/^ *Path *: *//p')
    copies="${XDG_RUNTIME_DIR:-/tmp}/overview-during-desktop-switch"
    copy="$copies/$(date +%s%N)/main.qml"
    rm -rf "$copies"
    mkdir -p "$(dirname "$copy")"
    cp "${dir%/}/contents/ui/main.qml" "$copy"
    scripting loadDeclarativeScript "$copy" overview-during-desktop-switch >/dev/null
    # Starts the loaded script. KWin reuses script numbers, so its /Scripting/ScriptN
    # path could belong to another script.
    scripting start >/dev/null

    if loaded; then
        echo "Activate Overview During Desktop Switch is running the version just installed."
    else
        echo "KWin didn't start the script: log out and back in once."
    fi
fi
echo "While it is on, it holds the Overview, Grid View and Present Windows keys (e.g. Meta+W)."
echo "It gives them back when it is turned off or removed."
