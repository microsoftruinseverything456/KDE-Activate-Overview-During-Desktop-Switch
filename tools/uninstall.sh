#!/bin/bash
# Turn off and remove Activate Overview During Desktop Switch.
set -euo pipefail

kwriteconfig6 --file kwinrc --group Plugins --key interruptibleoverviewEnabled false
if qdbus6 org.kde.KWin /KWin >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript interruptibleoverview >/dev/null 2>&1 || true
    qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
fi
kpackagetool6 --type=KWin/Script --remove interruptibleoverview
echo "Removed. Overview, Grid View and Present Windows have their keys back."
