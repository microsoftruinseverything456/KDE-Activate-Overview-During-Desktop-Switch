/*
    Activate Overview During Desktop Switch: Overview, Grid View and Window
    View shortcuts work while a virtual desktop slide is still animating.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// During a desktop switch the Slide effect holds KWin's full screen effect
// slot, and the views ignore their shortcuts until the animation ends. This
// script owns copies of those shortcuts, and takes over their keys while it is
// on. Pressed during a slide, a copy unloads Slide (which ends the animation on
// the target desktop), triggers the real shortcut and loads Slide again.

import QtQuick
import QtQml
import org.kde.kwin

Item {
    id: root

    readonly property var actions: [
        { name: "Overview", effect: "overview", text: "Toggle Overview" },
        { name: "Grid View", effect: "overview", text: "Toggle Grid View" },
        { name: "Cycle Overview", effect: "overview", text: "Cycle through Overview and Grid View" },
        { name: "Cycle Overview Opposite", effect: "overview", text: "Cycle through Grid View and Overview" },
        { name: "Expose", effect: "windowview", text: "Toggle Present Windows (Current desktop)" },
        { name: "ExposeAll", effect: "windowview", text: "Toggle Present Windows (All desktops)" },
        { name: "ExposeClass", effect: "windowview", text: "Toggle Present Windows (Window class)" },
        { name: "ExposeClassCurrentDesktop", effect: "windowview", text: "Toggle Present Windows (Window class on current desktop)" },
    ]

    readonly property var kwin: ({ service: "org.kde.KWin", path: "/KWin", dbusInterface: "org.kde.KWin" })
    readonly property var effects: ({ service: "org.kde.KWin", path: "/Effects", dbusInterface: "org.kde.kwin.Effects" })
    readonly property var shortcuts: ({ service: "org.kde.kglobalaccel", path: "/component/kwin", dbusInterface: "org.kde.kglobalaccel.Component" })
    readonly property var keyRegistry: ({ service: "org.kde.kglobalaccel", path: "/kglobalaccel", dbusInterface: "org.kde.KGlobalAccel" })

    // The press being handled, and the latest one that arrived meanwhile.
    property var pending: null
    property var queued: null
    // Keys each copy holds, by stock action name, to hand back when unloaded.
    property var ownedKeys: ({})
    property bool quitting: false

    // KGlobalAccel wants a list of strings and a list of ints. Typed list
    // properties are sent as those; plain JavaScript arrays are not.
    Component {
        id: dbusCall
        DBusCall {
            property list<string> actionId
            property list<int> keys
        }
    }

    // Calls a D-Bus method. args is an array, or a function that fills in the
    // call and returns its arguments. onDone gets the first return value, or
    // null if the call failed.
    function call(target, method, args, onDone) {
        const c = dbusCall.createObject(root, Object.assign({ method: method }, target));
        c.arguments = typeof args === "function" ? args(c) : args;
        c.finished.connect((values) => {
            c.destroy();
            if (onDone) {
                onDone(values[0]);
            }
        });
        c.failed.connect(() => {
            c.destroy();
            if (onDone) {
                onDone(null);
            }
        });
        c.call();
    }

    function getKeys(action, onDone) {
        call(keyRegistry, "shortcut", (c) => {
            c.actionId = ["kwin", action, "", ""];
            return [c.actionId];
        }, (keys) => onDone(keys === null ? null : Array.from(keys)));
    }

    function setKeys(action, keys, onDone) {
        call(keyRegistry, "setForeignShortcut", (c) => {
            c.actionId = ["kwin", action, "", ""];
            c.keys = keys;
            return [c.actionId, c.keys];
        }, onDone);
    }

    // KGlobalAccel refuses a key that another action holds, so the stock action
    // is cleared first.
    function takeKeys(action) {
        const own = "Interruptible " + action.name;
        getKeys(action.name, (stockKeys) => getKeys(own, (ownKeys) => {
            if (stockKeys === null || ownKeys === null) {
                return;
            }
            const keys = ownKeys.concat(stockKeys.filter((key) => !ownKeys.includes(key)));
            ownedKeys[action.name] = keys;
            if (stockKeys.length > 0) {
                setKeys(action.name, [], () => setKeys(own, keys));
            }
        }));
    }

    function giveKeysBack(action) {
        const keys = ownedKeys[action.name];
        if (keys && keys.length > 0) {
            setKeys("Interruptible " + action.name, []);
            setKeys(action.name, keys);
        }
    }

    // The activeEffects D-Bus property would be simpler, but KWin hands it to
    // scripts in a form they can't read. This reads the names listed under
    // "Currently Active Effects:" in KWin's support information instead, and
    // passes null if that section is missing.
    function readActiveEffects(onDone) {
        call(kwin, "supportInformation", [], (text) => {
            const lines = String(text || "").split("\n");
            const start = lines.indexOf("Currently Active Effects:");
            if (start === -1) {
                onDone(null);
                return;
            }
            const end = lines.indexOf("", start + 2);
            onDone(lines.slice(start + 2, end === -1 ? undefined : end));
        });
    }

    function press(action) {
        if (pending) {
            queued = action;
            return;
        }
        pending = action;
        readActiveEffects((active) => {
            const opening = active !== null && !active.includes(action.effect);
            if (opening && active.includes("slide")) {
                // Trigger the shortcut once the full screen slot is free.
                call(effects, "unloadEffect", ["slide"], () => {
                    trigger(action, true, 1);
                    call(effects, "loadEffect", ["slide"]);
                });
            } else {
                trigger(action, opening, 1);
            }
        });
    }

    // KWin flips a view's on/off state even for a press it ignored, which makes
    // the next press look ignored too. So when opening a view, check that it
    // opened and press again if not.
    function trigger(action, opening, attempt) {
        call(shortcuts, "invokeShortcut", [action.name], (result) => {
            if (result === null || !opening || attempt >= 3) {
                finish();
                return;
            }
            verifyTimer.check = () => readActiveEffects((active) => {
                if (active && active.includes(action.effect)) {
                    finish();
                } else {
                    trigger(action, opening, attempt + 1);
                }
            });
            verifyTimer.restart();
        });
    }

    function finish() {
        pending = null;
        if (queued) {
            const next = queued;
            queued = null;
            press(next);
        }
    }

    Instantiator {
        model: root.actions
        delegate: ShortcutHandler {
            required property var modelData
            name: "Interruptible " + modelData.name
            text: "Activate Overview During Desktop Switch: " + modelData.text
            sequence: ""
            onActivated: root.press(modelData)
        }
    }

    Timer {
        id: verifyTimer
        property var check
        interval: 150
        onTriggered: check()
    }

    // Wait for the copies to register before moving keys to them.
    Timer {
        interval: 500
        running: true
        onTriggered: root.actions.forEach(root.takeKeys)
    }

    // Keep the keys when KWin quits, e.g. on logout, so they work right after
    // the next login. Handing them back then could be cut off halfway.
    Connections {
        target: Qt.application
        function onAboutToQuit() {
            root.quitting = true;
        }
    }

    Component.onDestruction: {
        if (!quitting) {
            actions.forEach(giveKeysBack);
        }
    }
}
