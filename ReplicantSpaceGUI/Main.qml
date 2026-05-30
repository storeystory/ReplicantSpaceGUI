import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls

Window {
    id: root
    width: 1280
    height: 820
    minimumWidth: 960
    minimumHeight: 640
    visible: true
    title: "REPLICANT SPACE"
    color: theme.bg

    property string pinnedBlueprintType: ""
    property int invNextRefresh: 30
    property var pinnedBlueprintData: {
        if (!pinnedBlueprintType) return null
        for (var i = 0; i < backend.blueprints.length; i++) {
            if ((backend.blueprints[i].device_type || "") === pinnedBlueprintType)
                return backend.blueprints[i]
        }
        return null
    }

    // ── Colour & font theme ──────────────────────────────────────────── //
    QtObject {
        id: theme
        readonly property color bg:        "#060c07"
        readonly property color panelBg:   "#0a110b"
        readonly property color border:    "#1a3320"
        readonly property color hover:     "#0d1a0e"
        readonly property color txtBright: "#39ff14"   // neon green
        readonly property color txtMid:    "#1aab5a"
        readonly property color txtDim:    "#0d5c2a"
        readonly property color txtAccent: "#00ffa0"   // cyan-green title
        readonly property color txtAmber:  "#ffb000"
        readonly property color txtRed:    "#ff3333"
        readonly property color txtInfo:   "#00ccff"
        readonly property string mono:     "Courier New"
    }

    // ── Inline component: bordered terminal panel ────────────────────── //
    component TermPanel: Rectangle {
        property string heading: ""
        color: theme.panelBg
        border.color: theme.border
        border.width: 1

        Text {
            visible: parent.heading !== ""
            anchors { top: parent.top; left: parent.left; margins: 10 }
            text: "── " + parent.heading + " "
            color: theme.txtDim
            font { family: theme.mono; pointSize: 8 }
        }
    }

    // ── Inline component: labelled status row ────────────────────────── //
    component StatusRow: RowLayout {
        property string label: ""
        property string value: ""
        spacing: 6
        Text {
            text: label + ":"
            color: theme.txtDim
            font { family: theme.mono; pointSize: 9 }
            Layout.preferredWidth: 80
        }
        Text {
            text: value
            color: theme.txtBright
            font { family: theme.mono; pointSize: 9 }
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    // ── Inline component: action button ─────────────────────────────── //
    component ActionBtn: Rectangle {
        id: btnRoot
        property string label: ""
        signal activated()
        width: parent ? parent.width : 160
        height: 30
        color: enabled && btnMa.containsMouse ? theme.hover : "transparent"
        border.color: enabled ? (btnMa.containsMouse ? theme.txtMid : theme.border) : theme.txtDim
        border.width: 1
        opacity: enabled ? 1.0 : 0.4

        Text {
            anchors.centerIn: parent
            text: btnRoot.label
            color: btnMa.containsMouse ? theme.txtBright : theme.txtMid
            font { family: theme.mono; pointSize: 9 }
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btnRoot.activated()
        }
    }

    // ── Header bar ──────────────────────────────────────────────────── //
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 46
        color: "#0b150c"
        border.color: theme.border
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 20

            Text {
                text: "◈ REPLICANT SPACE"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 13; bold: true; letterSpacing: 2 }
            }

            Rectangle { width: 1; height: 28; color: theme.border }

            Text {
                text: backend.replicantName.toUpperCase()
                color: theme.txtBright
                font { family: theme.mono; pointSize: 11; bold: true }
            }

            Text {
                text: "▸ " + backend.location
                color: theme.txtAmber
                font { family: theme.mono; pointSize: 10 }
            }

            Rectangle { width: 1; height: 28; color: theme.border }

            Text {
                text: backend.status
                color: backend.status === "IDLE" ? theme.txtDim : theme.txtInfo
                font { family: theme.mono; pointSize: 9 }
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "XP " + backend.xp
                color: theme.txtDim
                font { family: theme.mono; pointSize: 9 }
            }

            Rectangle { width: 1; height: 28; color: theme.border }

            ActionBtn {
                label: "⟳ SYNC"
                width: 72
                onActivated: backend.refresh()
            }
        }
    }

    // ── Toast notification ───────────────────────────────────────────── //
    Rectangle {
        id: toast
        anchors { top: header.bottom; horizontalCenter: parent.horizontalCenter }
        width: toastText.implicitWidth + 32
        height: toastText.implicitHeight + 14
        radius: 2
        color: "#111"
        border.color: toastText.color
        border.width: 1
        opacity: 0
        z: 100

        Text {
            id: toastText
            anchors.centerIn: parent
            font { family: theme.mono; pointSize: 9 }
            color: theme.txtBright
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }

        Timer {
            id: toastTimer
            interval: 3500
            onTriggered: toast.opacity = 0
        }
    }

    Connections {
        target: backend
        function onToastMessage(level, text) {
            toastText.color = level === "error" ? theme.txtRed
                            : level === "warn"  ? theme.txtAmber
                            : theme.txtBright
            toastText.text = text
            toast.opacity  = 1
            toastTimer.restart()
        }
        function onScanComplete() {
            centerPanel.activeTab = "system"
        }
        function onInventoryChanged() { root.invNextRefresh = 30 }
    }

    Timer {
        id: invCountdown
        interval: 1000
        repeat: true
        running: true
        onTriggered: if (root.invNextRefresh > 0) root.invNextRefresh--
    }

    // ── Main body (three-column layout) ─────────────────────────────── //
    RowLayout {
        id: mainBody
        anchors {
            top: header.bottom; bottom: devicesBar.top
            left: parent.left; right: parent.right
            margins: 4
        }
        spacing: 4

        // ── LEFT: Status + Actions ────────────────────────────────── //
        TermPanel {
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            heading: ""

            ColumnLayout {
                anchors { fill: parent; margins: 12; topMargin: 10 }
                spacing: 0

                Text {
                    text: "── STATUS ──────────────"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 8 }
                    bottomPadding: 8
                }

                StatusRow { label: "NAME    "; value: backend.replicantName }
                StatusRow { label: "CODE    "; value: backend.replicantCode }
                StatusRow { label: "LOCATION"; value: backend.location }
                StatusRow { label: "HOST    "; value: backend.hostDevice }
                StatusRow { label: "XP      "; value: backend.xp.toString() }

                Rectangle {
                    Layout.fillWidth: true; height: 1
                    color: theme.border
                    Layout.topMargin: 14; Layout.bottomMargin: 14
                }

                Text {
                    text: "── ACTIONS ─────────────"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 8 }
                    bottomPadding: 10
                }

                ActionBtn { label: "[ SCAN SYSTEM ]"; Layout.fillWidth: true; onActivated: backend.scan() }
                Item { height: 4 }
                ActionBtn { label: "[ SCAN DEVICES ]"; Layout.fillWidth: true; onActivated: backend.scanDevices() }
                Item { height: 4 }
                ActionBtn { label: "[ MINE… ]"; Layout.fillWidth: true; onActivated: mineDialog.open() }
                Item { height: 4 }
                ActionBtn { label: "[ TRAVEL… ]"; Layout.fillWidth: true; onActivated: travelDialog.open() }
                Item { height: 4 }
                ActionBtn { label: "[ TELEPORT… ]"; Layout.fillWidth: true; onActivated: teleportDialog.open() }
                Item { height: 4 }
                ActionBtn { label: "[ TRANSFER… ]"; Layout.fillWidth: true; onActivated: transferDialog.open() }
                Item { height: 4 }
                ActionBtn { label: "[ TRADE… ]"; Layout.fillWidth: true; onActivated: tradeDialog.open() }
                Item { height: 4 }
                ActionBtn { label: "[ PRINT… ]"; Layout.fillWidth: true; onActivated: printDialog.open() }

                Rectangle {
                    Layout.fillWidth: true; height: 1
                    color: theme.border
                    Layout.topMargin: 10; Layout.bottomMargin: 10
                }

                ActionBtn { label: "[ REG. WEBHOOK ]"; Layout.fillWidth: true; onActivated: backend.registerWebhook() }

                Rectangle {
                    visible: root.pinnedBlueprintType !== ""
                    Layout.fillWidth: true; height: 1
                    color: theme.border
                    Layout.topMargin: 10; Layout.bottomMargin: 6
                }

                ColumnLayout {
                    visible: root.pinnedBlueprintType !== ""
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "── PINNED ───────────────"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            Layout.fillWidth: true
                        }
                        ActionBtn {
                            label: "[ ✕ ]"
                            width: 40; height: 20
                            onActivated: root.pinnedBlueprintType = ""
                        }
                    }

                    Text {
                        text: root.pinnedBlueprintType.toUpperCase().replace(/_/g, " ")
                        color: theme.txtAccent
                        font { family: theme.mono; pointSize: 9; bold: true }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: {
                            var bp = root.pinnedBlueprintData
                            if (!bp) return []
                            var r = bp.resources || {}
                            return Object.keys(r)
                                .filter(function(k) { return r[k] > 0 })
                                .map(function(k) { return { name: k, qty: r[k] } })
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: modelData.name.substring(0, 4).toUpperCase()
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "" + modelData.qty
                                color: theme.txtAmber
                                font { family: theme.mono; pointSize: 7 }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "CODE: " + backend.replicantCode
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 7 }
                }
            }
        }

        // ── CENTRE: Nearby stars / System scan ───────────────────── //
        TermPanel {
            id: centerPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            heading: ""

            property string activeTab: "stars"

            ColumnLayout {
                anchors { fill: parent; margins: 12; topMargin: 10 }
                spacing: 4

                // Tab bar
                RowLayout {
                    spacing: 4
                    Layout.fillWidth: true

                    ActionBtn {
                        label: centerPanel.activeTab === "stars" ? "[ NEARBY STARS ]" : "  NEARBY STARS  "
                        height: 24
                        width: 130
                        onActivated: centerPanel.activeTab = "stars"
                    }
                    ActionBtn {
                        label: centerPanel.activeTab === "system" ? "[ SYSTEM SCAN ]" : "  SYSTEM SCAN  "
                        height: 24
                        width: 120
                        onActivated: centerPanel.activeTab = "system"
                    }
                    ActionBtn {
                        label: centerPanel.activeTab === "blueprints" ? "[ BLUEPRINTS ]" : "  BLUEPRINTS  "
                        height: 24
                        width: 110
                        onActivated: centerPanel.activeTab = "blueprints"
                    }
                    ActionBtn {
                        label: centerPanel.activeTab === "inventory" ? "[ INVENTORY ]" : "  INVENTORY  "
                        height: 24
                        width: 110
                        onActivated: { centerPanel.activeTab = "inventory"; backend.fetchInventory() }
                    }
                    ActionBtn {
                        label: centerPanel.activeTab === "survey" ? "[ SURVEY ]" : "  SURVEY  "
                        height: 24
                        width: 90
                        onActivated: centerPanel.activeTab = "survey"
                    }
                    ActionBtn {
                        label: centerPanel.activeTab === "messages"
                               ? "[ MESSAGES ]"
                               : backend.unreadCount > 0
                                 ? "  MSG (" + backend.unreadCount + ")  "
                                 : "  MESSAGES  "
                        height: 24
                        width: 115
                        onActivated: { centerPanel.activeTab = "messages"; backend.fetchMessages() }
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                // ── Stars tab ── //
                ColumnLayout {
                    visible: centerPanel.activeTab === "stars"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Item { width: 20 }
                        Text {
                            text: "SYSTEM"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "DIST (LY)"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            Layout.preferredWidth: 80
                        }
                        Item { width: 70 }
                    }

                    ListView {
                        id: starList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.stars
                        clip: true

                        delegate: Rectangle {
                            width: starList.width
                            height: 32
                            color: starMa.containsMouse ? theme.hover : "transparent"

                            MouseArea {
                                id: starMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                spacing: 0

                                Text {
                                    text: "◉"
                                    color: theme.txtAccent
                                    font { family: theme.mono; pointSize: 9 }
                                    Layout.preferredWidth: 20
                                }
                                Text {
                                    text: modelData.designation || "UNKNOWN"
                                    color: theme.txtBright
                                    font { family: theme.mono; pointSize: 9 }
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.distance_from_replicant !== undefined
                                            ? Number(modelData.distance_from_replicant).toFixed(2)
                                            : "—"
                                    color: theme.txtAmber
                                    font { family: theme.mono; pointSize: 9 }
                                    Layout.preferredWidth: 80
                                }
                                ActionBtn {
                                    label: "→ GO"
                                    width: 64
                                    height: 24
                                    onActivated: backend.travelTo(modelData.designation || "")
                                }
                            }
                        }

                        Text {
                            visible: starList.count === 0
                            anchors.centerIn: parent
                            text: "no star data — press SYNC"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }
                }

                // ── System scan tab ── //
                RowLayout {
                    visible: centerPanel.activeTab === "system"
                    Layout.fillWidth: true
                    Text {
                        text: beltList.count > 0
                              ? beltList.count + " BELT" + (beltList.count !== 1 ? "S" : "") + " — DATA FROM LAST SCAN"
                              : "NO SCAN DATA"
                        color: theme.txtDim
                        font { family: theme.mono; pointSize: 8 }
                        Layout.fillWidth: true
                    }
                    ActionBtn {
                        label: "[ RESCAN ]"
                        width: 90; height: 24
                        onActivated: backend.scan()
                    }
                }

                ListView {
                    id: beltList
                    visible: centerPanel.activeTab === "system"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: backend.asteroidBelts
                    clip: true
                    spacing: 8

                    delegate: Rectangle {
                        width: beltList.width
                        color: theme.hover
                        border.color: theme.border
                        border.width: 1
                        height: beltCol.implicitHeight + 16

                        Column {
                            id: beltCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                            spacing: 6

                            // Belt header
                            RowLayout {
                                width: parent.width
                                Text {
                                    text: "◈ " + (modelData.designation || "BELT")
                                    color: theme.txtAccent
                                    font { family: theme.mono; pointSize: 10; bold: true }
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: (modelData.density || "").toUpperCase()
                                    color: theme.txtAmber
                                    font { family: theme.mono; pointSize: 8 }
                                }
                            }

                            // Resource grid
                            Grid {
                                width: parent.width
                                columns: 3
                                columnSpacing: 6
                                rowSpacing: 4

                                Repeater {
                                    model: {
                                        var res = modelData.resources || {}
                                        return ["carbon","silicates","structural","conductive","rares","volatiles"].map(
                                            function(r) { return { name: r, level: res[r] || "none" } }
                                        )
                                    }

                                    Rectangle {
                                        id: resCell
                                        property string resName: modelData.name
                                        property string resLevel: modelData.level
                                        width: (beltList.width - 28) / 3
                                        height: 26
                                        color: "transparent"
                                        border.color: theme.border
                                        border.width: 1

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 5; rightMargin: 5 }
                                            spacing: 4
                                            Text {
                                                text: resCell.resName.substring(0, 4).toUpperCase()
                                                color: resCell.resLevel === "high"   ? theme.txtBright
                                                     : resCell.resLevel === "low"    ? theme.txtMid
                                                     : theme.txtDim
                                                font { family: theme.mono; pointSize: 8 }
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: resCell.resLevel === "none" ? "—" : resCell.resLevel
                                                color: resCell.resLevel === "high"   ? theme.txtBright
                                                     : resCell.resLevel === "low"    ? theme.txtAmber
                                                     : theme.txtDim
                                                font { family: theme.mono; pointSize: 7 }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: resCell.resLevel !== "none"
                                            hoverEnabled: true
                                            cursorShape: resCell.resLevel !== "none" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: mineSelectDialog.open(resCell.resName)
                                            onEntered: resCell.border.color = theme.txtMid
                                            onExited:  resCell.border.color = theme.border
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: beltList.count === 0
                        anchors.centerIn: parent
                        text: "no scan data — press [ SCAN SYSTEM ]"
                        color: theme.txtDim
                        font { family: theme.mono; pointSize: 9 }
                    }
                }

                // ── Blueprints tab ── //
                ListView {
                    id: blueprintList
                    visible: centerPanel.activeTab === "blueprints"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: backend.blueprints
                    clip: true
                    spacing: 6

                    delegate: Rectangle {
                        width: blueprintList.width
                        color: theme.hover
                        border.color: theme.border
                        border.width: 1
                        height: bpCol.implicitHeight + 16

                        Column {
                            id: bpCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                            spacing: 6

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: "◈ " + (modelData.device_type || "UNKNOWN").toUpperCase().replace(/_/g, " ")
                                    color: theme.txtAccent
                                    font { family: theme.mono; pointSize: 10; bold: true }
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: {
                                        var s = modelData.print_time || 0
                                        return s < 60 ? s + "s"
                                             : s < 3600 ? Math.round(s/60) + "m"
                                             : (s/3600).toFixed(1) + "h"
                                    }
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 8 }
                                }
                                ActionBtn {
                                    label: "[ PRINT ]"
                                    width: 72; height: 24
                                    onActivated: backend.printDevice(modelData.device_type || "")
                                }
                                ActionBtn {
                                    label: root.pinnedBlueprintType === (modelData.device_type || "")
                                           ? "[ UNPIN ]" : "[ PIN ]"
                                    width: 72; height: 24
                                    onActivated: {
                                        var t = modelData.device_type || ""
                                        root.pinnedBlueprintType = (root.pinnedBlueprintType === t) ? "" : t
                                    }
                                }
                            }

                            // Resource costs
                            Grid {
                                width: parent.width
                                columns: 3
                                columnSpacing: 6
                                rowSpacing: 3

                                Repeater {
                                    model: {
                                        var r = modelData.resources || {}
                                        return ["carbon","silicates","structural","conductive","rares","volatiles"]
                                            .filter(function(k) { return r[k] > 0 })
                                            .map(function(k) { return { name: k, qty: r[k] } })
                                    }
                                    RowLayout {
                                        width: (blueprintList.width - 28) / 3
                                        spacing: 4
                                        Text {
                                            text: modelData.name.substring(0,4).toUpperCase()
                                            color: theme.txtDim
                                            font { family: theme.mono; pointSize: 7 }
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: modelData.qty
                                            color: theme.txtAmber
                                            font { family: theme.mono; pointSize: 7 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: blueprintList.count === 0
                        anchors.centerIn: parent
                        text: "no blueprints yet"
                        color: theme.txtDim
                        font { family: theme.mono; pointSize: 9 }
                    }
                }

                // ── Inventory tab ── //
                ColumnLayout {
                    visible: centerPanel.activeTab === "inventory"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Countdown + manual refresh
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "NEXT REFRESH  " + root.invNextRefresh + "s"
                            color: root.invNextRefresh <= 10 ? theme.txtAmber : theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }
                        Item { width: 6 }
                        ActionBtn {
                            label: "[ ↺ ]"
                            width: 36; height: 22
                            onActivated: { backend.fetchInventory(); root.invNextRefresh = 30 }
                        }
                    }

                    // Column headers
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "RESOURCE"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "QUANTITY"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            Layout.preferredWidth: 80
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    ListView {
                        id: inventoryList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.inventory
                        clip: true

                        delegate: Rectangle {
                            width: inventoryList.width
                            height: 28
                            color: "transparent"

                            RowLayout {
                                anchors { fill: parent; leftMargin: 2; rightMargin: 2 }

                                Text {
                                    text: (modelData.name || "").toUpperCase()
                                    color: theme.txtBright
                                    font { family: theme.mono; pointSize: 9 }
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.qty || 0
                                    color: theme.txtAmber
                                    font { family: theme.mono; pointSize: 9 }
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 80
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: 1
                                color: theme.border; opacity: 0.4
                            }
                        }

                        Text {
                            visible: inventoryList.count === 0
                            anchors.centerIn: parent
                            text: "no resources here — try mining first"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }

                    // Total row
                    Rectangle {
                        Layout.fillWidth: true; height: 1; color: theme.border
                        visible: inventoryList.count > 0
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: inventoryList.count > 0
                        Text {
                            text: "TOTAL UNITS"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            Layout.fillWidth: true
                        }
                        Text {
                            text: {
                                var t = 0
                                for (var i = 0; i < backend.inventory.length; i++)
                                    t += backend.inventory[i].qty || 0
                                return t
                            }
                            color: theme.txtAccent
                            font { family: theme.mono; pointSize: 8 }
                            Layout.preferredWidth: 80
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // ── Survey tab ── //
                ColumnLayout {
                    visible: centerPanel.activeTab === "survey"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    // No survey drones warning
                    Text {
                        visible: {
                            var d = backend.devices
                            for (var i = 0; i < d.length; i++)
                                if ((d[i].device_type || "").indexOf("survey") !== -1) return false
                            return true
                        }
                        text: "no survey drone in fleet — print one first"
                        color: theme.txtDim
                        font { family: theme.mono; pointSize: 9 }
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        Layout.fillHeight: true
                    }

                    // Planet list (only when at least one survey drone exists)
                    ListView {
                        id: planetList
                        visible: {
                            var d = backend.devices
                            for (var i = 0; i < d.length; i++)
                                if ((d[i].device_type || "").indexOf("survey") !== -1) return true
                            return false
                        }
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.planets
                        clip: true
                        spacing: 6

                        delegate: Rectangle {
                            id: planetDelegate
                            property var planet: modelData
                            width: planetList.width
                            color: theme.hover
                            border.color: theme.border
                            border.width: 1
                            height: planetCol.implicitHeight + 16

                            Column {
                                id: planetCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 6

                                // Planet header row
                                RowLayout {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        text: "◉ " + (modelData.designation || "UNKNOWN")
                                        color: theme.txtAccent
                                        font { family: theme.mono; pointSize: 10; bold: true }
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (modelData.type || "").toUpperCase()
                                        color: theme.txtMid
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                    Text {
                                        text: modelData.in_habitable_zone ? "♦ HZ" : ""
                                        color: theme.txtBright
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                }

                                // Stats row
                                RowLayout {
                                    width: parent.width
                                    spacing: 16
                                    Text {
                                        text: "DIST  " + (modelData.orbital_distance_au
                                              ? Number(modelData.orbital_distance_au).toFixed(2) + " AU"
                                              : "—")
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                    Text {
                                        text: "MOONS " + (modelData.moon_count || 0)
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                // One button row per survey drone
                                Repeater {
                                    model: {
                                        var surveyDrones = []
                                        var d = backend.devices
                                        for (var i = 0; i < d.length; i++)
                                            if ((d[i].device_type || "").indexOf("survey") !== -1)
                                                surveyDrones.push(d[i])
                                        return surveyDrones
                                    }

                                    RowLayout {
                                        width: planetCol.width
                                        spacing: 6

                                        Text {
                                            text: (modelData.device_type || "DRONE").toUpperCase().replace(/_/g, " ")
                                                  + "  " + (modelData.device_code || "")
                                            color: theme.txtDim
                                            font { family: theme.mono; pointSize: 8 }
                                            Layout.fillWidth: true
                                        }

                                        // SCAN if drone is already here, SEND otherwise
                                        ActionBtn {
                                            property bool atPlanet: (modelData.location || "") === (planetDelegate.planet.designation || "")
                                            property bool droneScanning: {
                                                var s = (modelData.status || "").toLowerCase()
                                                return s === "scanning" || s === "active" || s === "busy"
                                            }
                                            label: atPlanet ? (droneScanning ? "[ SCANNING… ]" : "[ SCAN ]") : "[ SEND ]"
                                            enabled: !(atPlanet && droneScanning)
                                            width: 80; height: 24
                                            onActivated: {
                                                if (atPlanet)
                                                    backend.scanWithDevice(modelData.device_code)
                                                else
                                                    backend.travelDevice(modelData.device_code,
                                                                         planetDelegate.planet.designation || "")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: planetList.count === 0
                            anchors.centerIn: parent
                            text: "no planet data — press [ SCAN SYSTEM ] first"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }
                }

                // ── Messages tab ── //
                ColumnLayout {
                    visible: centerPanel.activeTab === "messages"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: backend.unreadCount > 0 ? backend.unreadCount + " UNREAD" : "ALL READ"
                            color: backend.unreadCount > 0 ? theme.txtAmber : theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }
                        Item { Layout.fillWidth: true }
                        ActionBtn {
                            label: "[ MARK ALL READ ]"
                            width: 140; height: 24
                            enabled: backend.unreadCount > 0
                            onActivated: backend.markAllRead()
                        }
                        Item { width: 4 }
                        ActionBtn {
                            label: "[ ↺ ]"
                            width: 36; height: 24
                            onActivated: backend.fetchMessages()
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    ListView {
                        id: messageList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.messages
                        clip: true
                        spacing: 4

                        delegate: Rectangle {
                            id: msgDelegate
                            property bool isRead: !!modelData.read ||
                                (modelData.read_at !== undefined && modelData.read_at !== null)
                            width: messageList.width
                            height: msgCol.implicitHeight + 16
                            color: isRead ? "transparent" : theme.hover
                            border.color: isRead ? theme.border : theme.txtDim
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (!msgDelegate.isRead && modelData.id !== undefined)
                                        backend.markMessageRead(modelData.id)
                                }
                            }

                            Column {
                                id: msgCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 4

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: (modelData.from || modelData.sender ||
                                               modelData.from_replicant || "SYSTEM").toUpperCase()
                                        color: msgDelegate.isRead ? theme.txtMid : theme.txtBright
                                        font { family: theme.mono; pointSize: 9; bold: !msgDelegate.isRead }
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.created_at || ""
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 7 }
                                    }
                                }

                                Text {
                                    visible: (modelData.subject || "") !== ""
                                    width: parent.width
                                    text: modelData.subject || ""
                                    color: msgDelegate.isRead ? theme.txtMid : theme.txtAccent
                                    font { family: theme.mono; pointSize: 8; bold: !msgDelegate.isRead }
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }

                                Text {
                                    visible: (modelData.body || modelData.message || modelData.content || "") !== ""
                                    width: parent.width
                                    text: modelData.body || modelData.message || modelData.content || ""
                                    color: msgDelegate.isRead ? theme.txtDim : theme.txtMid
                                    font { family: theme.mono; pointSize: 8 }
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }
                            }
                        }

                        Text {
                            visible: messageList.count === 0
                            anchors.centerIn: parent
                            text: "no messages"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }
                }
            }
        }

        // ── RIGHT: Event log ──────────────────────────────────────── //
        TermPanel {
            Layout.preferredWidth: 330
            Layout.fillHeight: true
            heading: "EVENT LOG"

            ColumnLayout {
                anchors { fill: parent; margins: 12; topMargin: 26 }
                spacing: 4

                ListView {
                    id: eventList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: backend.events
                    clip: true
                    verticalLayoutDirection: ListView.BottomToTop
                    spacing: 2

                    delegate: Column {
                        width: eventList.width
                        spacing: 1

                        Text {
                            visible: text !== ""
                            width: parent.width
                            text: modelData.created_at || ""
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                        }
                        Text {
                            width: parent.width
                            text: modelData.message
                                    || modelData.event_type
                                    || JSON.stringify(modelData)
                            color: theme.txtBright
                            font { family: theme.mono; pointSize: 9 }
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                        Rectangle {
                            width: parent.width; height: 1
                            color: theme.border
                            opacity: 0.5
                        }
                    }

                    Text {
                        visible: eventList.count === 0
                        anchors.centerIn: parent
                        text: "awaiting events…"
                        color: theme.txtDim
                        font { family: theme.mono; pointSize: 9 }
                    }
                }
            }
        }
    }

    // ── Bottom: Devices ──────────────────────────────────────────────── //
    TermPanel {
        id: devicesBar
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 150
        heading: "DEVICES"

        ColumnLayout {
            anchors { fill: parent; margins: 12; topMargin: 26 }
            spacing: 0

            ListView {
                id: deviceList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: backend.devices
                orientation: ListView.Horizontal
                clip: true
                spacing: 6

                delegate: Rectangle {
                    id: devCard
                    property string devStatus: (modelData.status || "").toLowerCase()
                    width: 210
                    height: deviceList.height
                    color: "#0a120a"
                    border.color: theme.border
                    border.width: 1

                    ColumnLayout {
                        anchors { fill: parent; margins: 8 }
                        spacing: 3

                        Text {
                            text: (modelData.device_type || "DEVICE").toUpperCase().replace(/_/g, " ")
                            color: theme.txtAccent
                            font { family: theme.mono; pointSize: 9; bold: true }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "CODE   " + (modelData.device_code || "—")
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }
                        Text {
                            property string s: devCard.devStatus.toUpperCase()
                            text: "STATUS " + s
                            color: s === "ACTIVE"  ? theme.txtBright
                                 : s === "IDLE"    ? theme.txtMid
                                 : s === "STOWED"  ? theme.txtDim
                                 : theme.txtAmber
                            font { family: theme.mono; pointSize: 8 }
                        }
                        Text {
                            text: "LOC    " + (modelData.location || "—")
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            ActionBtn {
                                visible: (modelData.device_type || "").indexOf("vessel") === -1
                                label: devCard.devStatus === "stowed" ? "[ DEPLOY ]" : "[ STOW ]"
                                Layout.fillWidth: true
                                height: 22
                                onActivated: {
                                    if (devCard.devStatus === "stowed") {
                                        backend.deviceCommand(modelData.device_code, "deploy")
                                    } else {
                                        stowTargetDialog.open(
                                            modelData.device_code,
                                            (modelData.device_type || "?").toUpperCase().replace(/_/g, " ")
                                            + "  " + (modelData.device_code || ""))
                                    }
                                }
                            }

                            ActionBtn {
                                label: "[ CANCEL PRINT ]"
                                Layout.fillWidth: true
                                height: 22
                                visible: (modelData.device_type || "").indexOf("autofactory") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: backend.cancelPrint(modelData.device_code)
                            }

                            ActionBtn {
                                label: "[ ↺ ]"
                                width: 36
                                height: 22
                                visible: (modelData.device_type || "").indexOf("mining") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: {
                                    retargetDialog.deviceCode = modelData.device_code
                                    retargetDialog.visible = true
                                }
                            }

                            ActionBtn {
                                label: "[ SAL… ]"
                                width: 52
                                height: 22
                                visible: (modelData.device_type || "").indexOf("mining") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: mineSiteDialog.open(
                                    modelData.device_code,
                                    (modelData.device_type || "DRONE").toUpperCase().replace(/_/g, " ")
                                    + "  " + (modelData.device_code || "")
                                )
                            }
                        }
                    }
                }

                Text {
                    visible: deviceList.count === 0
                    anchors.centerIn: parent
                    text: "no device data"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 9 }
                }
            }
        }
    }

    // ── Dialogs ───────────────────────────────────────────────────────── //

    component InputDialog: Rectangle {
        id: dlg
        property string heading: ""
        property string placeholder: ""
        signal confirmed(string value)
        function open() { visible = true; dlgInput.text = ""; dlgInput.forceActiveFocus() }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 380; height: 140
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            Text {
                text: dlg.heading
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }

            Rectangle {
                width: parent.width; height: 32
                color: "#060c07"
                border.color: theme.border; border.width: 1

                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: dlg.placeholder
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 10 }
                    visible: dlgInput.text === ""
                }
                TextInput {
                    id: dlgInput
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.txtBright
                    font { family: theme.mono; pointSize: 10 }
                    Keys.onReturnPressed: { dlg.confirmed(text); dlg.close() }
                    Keys.onEscapePressed: dlg.close()
                }
            }

            RowLayout {
                width: parent.width
                spacing: 8

                ActionBtn {
                    label: "[ CONFIRM ]"; width: 120; height: 28
                    onActivated: { dlg.confirmed(dlgInput.text); dlg.close() }
                }
                ActionBtn {
                    label: "[ CANCEL ]"; width: 100; height: 28
                    onActivated: dlg.close()
                }
            }
        }
    }

    // Retarget resource picker
    Rectangle {
        id: retargetDialog
        property string deviceCode: ""

        visible: false
        anchors.centerIn: parent
        width: 260
        height: rtBody.implicitHeight + 32
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        Column {
            id: rtBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 6

            Text {
                text: "RETARGET → NEW RESOURCE:"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }

            Repeater {
                model: ["carbon", "silicates", "structural", "conductive", "rares", "volatiles"]
                ActionBtn {
                    label: "[ " + modelData.toUpperCase() + " ]"
                    width: rtBody.width
                    height: 26
                    onActivated: {
                        backend.retarget(retargetDialog.deviceCode, modelData)
                        retargetDialog.visible = false
                    }
                }
            }

            ActionBtn {
                label: "[ CANCEL ]"
                width: rtBody.width
                height: 26
                onActivated: retargetDialog.visible = false
            }
        }
    }

    // Mine-with selection dialog
    Rectangle {
        id: mineSelectDialog
        property string resource: ""

        function open(res) { resource = res; visible = true }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 320
        height: dlgBody.implicitHeight + 32
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        Column {
            id: dlgBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8

            Text {
                text: "MINE " + mineSelectDialog.resource.toUpperCase() + " WITH:"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }

            ActionBtn {
                label: "[ REPLICANT ]"
                width: parent.width
                height: 28
                onActivated: {
                    backend.mine(mineSelectDialog.resource)
                    mineSelectDialog.close()
                }
            }

            Repeater {
                model: backend.devices.filter(function(d) {
                    var t = d.device_type || ""
                    return t.indexOf("mining") !== -1 || t.indexOf("vessel") !== -1
                })
                ActionBtn {
                    label: "[ " + (modelData.device_type || "").toUpperCase().replace(/_/g," ")
                           + "  " + (modelData.device_code || "") + " ]"
                    width: dlgBody.width
                    height: 28
                    onActivated: {
                        backend.mineWithDevice(modelData.device_code, mineSelectDialog.resource)
                        mineSelectDialog.close()
                    }
                }
            }

            ActionBtn {
                label: "[ CANCEL ]"
                width: parent.width
                height: 28
                onActivated: mineSelectDialog.close()
            }
        }
    }

    InputDialog {
        id: travelDialog
        heading: "TRAVEL TO"
        placeholder: "destination (e.g. SOL-BELT-1)"
        onConfirmed: (val) => { if (val.trim()) backend.travelTo(val.trim()) }
    }

    InputDialog {
        id: mineDialog
        heading: "MINE RESOURCE"
        placeholder: "resource type (e.g. carbon)"
        onConfirmed: (val) => { if (val.trim()) backend.mine(val.trim()) }
    }

    InputDialog {
        id: printDialog
        heading: "PRINT DEVICE"
        placeholder: "device type (e.g. mining_drone)"
        onConfirmed: (val) => { if (val.trim()) backend.printDevice(val.trim()) }
    }

    InputDialog {
        id: teleportDialog
        heading: "TELEPORT  —  FTL TRANSFER"
        placeholder: "target empty matrix device code"
        onConfirmed: (val) => { if (val.trim()) backend.teleport(val.trim().toUpperCase()) }
    }

    InputDialog {
        id: transferDialog
        heading: "TRANSFER  —  LOCAL"
        placeholder: "target empty matrix device code"
        onConfirmed: (val) => { if (val.trim()) backend.transfer(val.trim().toUpperCase()) }
    }

    // Mine specific salvage site dialog
    Rectangle {
        id: mineSiteDialog
        property string deviceCode: ""
        property string deviceLabel: ""

        function open(code, label) {
            deviceCode = code
            deviceLabel = label
            mineSiteTargetInput.text = ""
            visible = true
            mineSiteTargetInput.forceActiveFocus()
        }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 300
        height: mineSiteBody.implicitHeight + 32
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        Column {
            id: mineSiteBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8

            Text {
                text: "MINE SITE WITH:"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }
            Text {
                text: mineSiteDialog.deviceLabel
                color: theme.txtMid
                font { family: theme.mono; pointSize: 8 }
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: "TARGET SITE CODE:"
                color: theme.txtDim
                font { family: theme.mono; pointSize: 8 }
            }

            Rectangle {
                width: parent.width; height: 32
                color: "#060c07"
                border.color: theme.border; border.width: 1

                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: "e.g. MEROGA-3-1-SAL-1"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 9 }
                    visible: mineSiteTargetInput.text === ""
                }
                TextInput {
                    id: mineSiteTargetInput
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.txtBright
                    font { family: theme.mono; pointSize: 9 }
                    Keys.onEscapePressed: mineSiteDialog.close()
                }
            }

            Text {
                text: "RESOURCE TYPE:"
                color: theme.txtDim
                font { family: theme.mono; pointSize: 8 }
            }

            Repeater {
                model: ["carbon", "silicates", "structural", "conductive", "rares", "volatiles"]
                ActionBtn {
                    label: "[ " + modelData.toUpperCase() + " ]"
                    width: mineSiteBody.width
                    height: 26
                    enabled: mineSiteTargetInput.text.trim() !== ""
                    onActivated: {
                        backend.mineWithDeviceAtTarget(
                            mineSiteDialog.deviceCode,
                            modelData,
                            mineSiteTargetInput.text.trim().toUpperCase()
                        )
                        mineSiteDialog.close()
                    }
                }
            }

            ActionBtn {
                label: "[ CANCEL ]"
                width: parent.width
                height: 26
                onActivated: mineSiteDialog.close()
            }
        }
    }

    // Trade dialog — directory view + per-shop trade browser
    Rectangle {
        id: tradeDialog
        property string view: "directory"   // "directory" | "shop"
        property string shopCode: ""
        property string shopName: ""

        function open() {
            view = "directory"
            shopCode = ""
            shopName = ""
            visible = true
            backend.fetchTraders()
        }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 600
        height: 500
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 8

            // Header row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ActionBtn {
                    label: "[ ← BACK ]"
                    visible: tradeDialog.view === "shop"
                    width: 80; height: 24
                    onActivated: tradeDialog.view = "directory"
                }
                Text {
                    text: tradeDialog.view === "directory" ? "TRADING NETWORK" : tradeDialog.shopName
                    color: theme.txtAccent
                    font { family: theme.mono; pointSize: 10; bold: true }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                ActionBtn {
                    label: "[ ↺ ]"
                    visible: tradeDialog.view === "directory"
                    width: 36; height: 24
                    onActivated: backend.fetchTraders()
                }
                ActionBtn {
                    label: "[ CLOSE ]"
                    width: 80; height: 24
                    onActivated: tradeDialog.close()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            // ── Trader directory ── //
            ListView {
                id: traderList
                visible: tradeDialog.view === "directory"
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: backend.traders
                clip: true
                spacing: 5

                delegate: Rectangle {
                    width: traderList.width
                    height: traderDelegateCol.implicitHeight + 16
                    color: theme.hover
                    border.color: theme.border
                    border.width: 1

                    ColumnLayout {
                        id: traderDelegateCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "◈ " + (modelData.shop_name || "UNNAMED SHOP")
                                color: theme.txtAccent
                                font { family: theme.mono; pointSize: 9; bold: true }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                visible: !!modelData.is_local
                                width: 46; height: 18
                                color: "transparent"
                                border.color: theme.txtMid; border.width: 1
                                radius: 2
                                Text {
                                    anchors.centerIn: parent
                                    text: "LOCAL"
                                    color: theme.txtBright
                                    font { family: theme.mono; pointSize: 7 }
                                }
                            }
                            Text {
                                text: (modelData.trade_count || 0) + " TRADES"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                            }
                            ActionBtn {
                                label: "[ BROWSE ]"
                                width: 84; height: 24
                                onActivated: {
                                    tradeDialog.shopCode = modelData.controller_code || ""
                                    tradeDialog.shopName = modelData.shop_name || "SHOP"
                                    tradeDialog.view = "shop"
                                    backend.browseShop(tradeDialog.shopCode)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: (modelData.owner_name || "UNKNOWN").toUpperCase()
                                color: theme.txtMid
                                font { family: theme.mono; pointSize: 8 }
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: !!(modelData.location || modelData.star)
                                text: (modelData.location || modelData.star || "").toUpperCase()
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                            }
                        }
                    }
                }

                Text {
                    visible: traderList.count === 0
                    anchors.centerIn: parent
                    text: "no traders found — loading…"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 9 }
                }
            }

            // ── Shop trade list ── //
            ListView {
                id: shopTradeList
                visible: tradeDialog.view === "shop"
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: backend.shopTrades
                clip: true
                spacing: 5

                delegate: Rectangle {
                    id: tradeCard
                    property int stock: modelData.current_stock || 0
                    width: shopTradeList.width
                    height: tradeCardCol.implicitHeight + 16
                    color: theme.hover
                    border.color: tradeCard.stock > 0 ? theme.border : theme.txtDim
                    border.width: 1
                    opacity: tradeCard.stock > 0 ? 1.0 : 0.5

                    ColumnLayout {
                        id: tradeCardCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 5

                        // Trade name + stock + execute
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: modelData.name || "TRADE"
                                color: tradeCard.stock > 0 ? theme.txtAccent : theme.txtDim
                                font { family: theme.mono; pointSize: 9; bold: true }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "×" + tradeCard.stock
                                color: tradeCard.stock > 0 ? theme.txtAmber : theme.txtRed
                                font { family: theme.mono; pointSize: 8 }
                            }
                            ActionBtn {
                                label: "[ EXECUTE ]"
                                width: 90; height: 24
                                enabled: tradeCard.stock > 0
                                onActivated: {
                                    backend.executeTrade(tradeDialog.shopCode, modelData.trade_code || "")
                                    tradeDialog.close()
                                }
                            }
                        }

                        // Cost → reward row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: "COST"
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 7 }
                                }
                                Repeater {
                                    model: {
                                        var res = (modelData.criteria || {}).resources || {}
                                        return Object.keys(res).map(function(k) {
                                            return { name: k, qty: res[k] }
                                        })
                                    }
                                    Text {
                                        text: modelData.name.toUpperCase() + "  ×" + modelData.qty
                                        color: theme.txtMid
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                }
                                Repeater {
                                    model: {
                                        var dev = (modelData.criteria || {}).devices || {}
                                        return Object.keys(dev).map(function(k) {
                                            return { name: k, qty: dev[k] }
                                        })
                                    }
                                    Text {
                                        text: modelData.name.toUpperCase().replace(/_/g," ") + "  ×" + modelData.qty
                                        color: theme.txtMid
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                }
                            }

                            Text {
                                text: "→"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 10 }
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: "GET"
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 7 }
                                }
                                Repeater {
                                    model: {
                                        var res = (modelData.rewards || {}).resources || {}
                                        return Object.keys(res).map(function(k) {
                                            return { name: k, qty: res[k] }
                                        })
                                    }
                                    Text {
                                        text: modelData.name.toUpperCase() + "  ×" + modelData.qty
                                        color: theme.txtBright
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                }
                                Repeater {
                                    model: {
                                        var dev = (modelData.rewards || {}).devices || {}
                                        return Object.keys(dev).map(function(k) {
                                            return { name: k, qty: dev[k] }
                                        })
                                    }
                                    Text {
                                        text: modelData.name.toUpperCase().replace(/_/g," ") + "  ×" + modelData.qty
                                        color: theme.txtBright
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: shopTradeList.count === 0
                    anchors.centerIn: parent
                    text: "no trades at this shop"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 9 }
                }
            }
        }
    }

    // Stow dialog — supports optional target device code
    Rectangle {
        id: stowTargetDialog
        property string deviceCode: ""
        property string deviceLabel: ""

        function open(code, label) {
            deviceCode = code
            deviceLabel = label
            stowTargetInput.text = ""
            visible = true
            stowTargetInput.forceActiveFocus()
        }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 380
        height: stowTargetBody.implicitHeight + 32
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        Column {
            id: stowTargetBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 10

            Text {
                text: "STOW: " + stowTargetDialog.deviceLabel
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: "TARGET DEVICE CODE (leave blank for direct stow):"
                color: theme.txtDim
                font { family: theme.mono; pointSize: 8 }
            }

            Rectangle {
                width: parent.width; height: 32
                color: "#060c07"
                border.color: theme.border; border.width: 1

                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: "e.g. 8336F80E"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 10 }
                    visible: stowTargetInput.text === ""
                }
                TextInput {
                    id: stowTargetInput
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.txtBright
                    font { family: theme.mono; pointSize: 10 }
                    Keys.onEscapePressed: stowTargetDialog.close()
                    Keys.onReturnPressed: {
                        var t = stowTargetInput.text.trim()
                        if (t) backend.deviceCommandWithTarget(stowTargetDialog.deviceCode, "stow", t)
                        else   backend.deviceCommand(stowTargetDialog.deviceCode, "stow")
                        stowTargetDialog.close()
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 6

                ActionBtn {
                    label: "[ STOW ]"
                    Layout.fillWidth: true; height: 28
                    onActivated: {
                        backend.deviceCommand(stowTargetDialog.deviceCode, "stow")
                        stowTargetDialog.close()
                    }
                }
                ActionBtn {
                    label: "[ STOW TO TARGET ]"
                    Layout.fillWidth: true; height: 28
                    enabled: stowTargetInput.text.trim() !== ""
                    onActivated: {
                        backend.deviceCommandWithTarget(stowTargetDialog.deviceCode, "stow",
                                                        stowTargetInput.text.trim())
                        stowTargetDialog.close()
                    }
                }
                ActionBtn {
                    label: "[ CANCEL ]"
                    width: 90; height: 28
                    onActivated: stowTargetDialog.close()
                }
            }
        }
    }
}
