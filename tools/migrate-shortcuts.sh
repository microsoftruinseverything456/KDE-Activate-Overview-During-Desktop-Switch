#!/bin/bash
# Move keys left on the "Interruptible …" actions of a pre-release build to the
# actions this version uses. Those actions were renamed, so the keys they hold
# (e.g. Meta+W) do nothing until moved. Safe to run more than once.
#   tools/migrate-shortcuts.sh
set -euo pipefail

ACTIONS=("Overview" "Grid View" "Cycle Overview" "Cycle Overview Opposite"
         "Expose" "ExposeAll" "ExposeClass" "ExposeClassCurrentDesktop")

# qdbus6 can't send the typed lists KGlobalAccel wants, gdbus can.
accel() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel."$@"
}
# Prints an action's keys as a comma separated list, e.g. "268435543,67108920".
get_keys() {
    accel shortcut "['kwin', '$1', '', '']" | sed 's/.*\[\(.*\)\].*/\1/; s/ //g'
}
set_keys() {
    accel setForeignShortcut "['kwin', '$1', '', '']" "@ai [$2]" >/dev/null
}

if ! qdbus6 org.kde.kglobalaccel /kglobalaccel >/dev/null 2>&1; then
    echo "KDE's shortcut service isn't running: run this from inside a Plasma session." >&2
    exit 1
fi

# While the script runs it holds the keys on its own actions. Otherwise they
# belong on the stock ones, and the script takes them from there when it starts.
running=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded overview-during-desktop-switch 2>/dev/null || echo false)
moved=0
for action in "${ACTIONS[@]}"; do
    old="Interruptible $action"
    keys=$(get_keys "$old")
    if [ -n "$keys" ]; then
        target=$([ "$running" = true ] && echo "Overview During Desktop Switch $action" || echo "$action")
        current=$(get_keys "$target")
        # KGlobalAccel refuses a key that another action holds, so clear the old one first.
        set_keys "$old" ""
        set_keys "$target" "${current:+$current,}$keys"
        echo "Moved the keys of \"$old\" to \"$target\"."
        moved=1
    fi
    # Drop the old action from System Settings.
    accel unregister kwin "$old" >/dev/null 2>&1 || true
done

if [ "$moved" = 0 ]; then
    echo "No keys were left on the old actions, nothing to move."
fi
