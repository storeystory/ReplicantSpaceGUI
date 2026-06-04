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
    readonly property bool hasAutofactory: {
        var d = backend.devices
        for (var i = 0; i < d.length; i++)
            if ((d[i].device_type || "").indexOf("autofactory") !== -1) return true
        return false
    }
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
        function onDevicesChanged() {
            var x = deviceList.contentX
            Qt.callLater(function() { deviceList.contentX = x })
        }
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
                ActionBtn { label: "[ TRADE ]"; Layout.fillWidth: true; onActivated: { centerPanel.activeTab = "trade"; backend.fetchTraders() } }
                Item { height: 4 }
                ActionBtn { label: "[ PRINT… ]"; Layout.fillWidth: true; onActivated: printDialog.open() }

                Rectangle {
                    Layout.fillWidth: true; height: 1
                    color: theme.border
                    Layout.topMargin: 10; Layout.bottomMargin: 10
                }

                ActionBtn { label: "[ PROFILE… ]"; Layout.fillWidth: true; onActivated: profileDlg.open() }
                Item { height: 4 }
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
                Flickable {
                    Layout.fillWidth: true
                    height: 24
                    contentWidth: tabRow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                        id: tabRow
                        spacing: 4

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
                            onActivated: { centerPanel.activeTab = "system"; backend.fetchAsteroids(); backend.fetchSystemMap() }
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
                            label: centerPanel.activeTab === "trade" ? "[ TRADE ]" : "  TRADE  "
                            height: 24
                            width: 90
                            onActivated: { centerPanel.activeTab = "trade"; backend.fetchTraders() }
                        }
                        ActionBtn {
                            label: centerPanel.activeTab === "survey" ? "[ SURVEY ]" : "  SURVEY  "
                            height: 24
                            width: 90
                            onActivated: centerPanel.activeTab = "survey"
                        }
                        ActionBtn {
                            visible: {
                                var d = backend.devices
                                for (var i = 0; i < d.length; i++)
                                    if ((d[i].device_type || "").indexOf("controller") !== -1) return true
                                return false
                            }
                            label: centerPanel.activeTab === "ami" ? "[ AMI ]" : "  AMI  "
                            height: 24
                            width: 72
                            onActivated: centerPanel.activeTab = "ami"
                        }
                        ActionBtn {
                            visible: {
                                var d = backend.devices
                                for (var i = 0; i < d.length; i++)
                                    if ((d[i].device_type || "").indexOf("relay") !== -1) return true
                                return false
                            }
                            label: centerPanel.activeTab === "relay" ? "[ RELAY ]" : "  RELAY  "
                            height: 24
                            width: 80
                            onActivated: {
                                centerPanel.activeTab = "relay"
                                var d = backend.devices
                                for (var i = 0; i < d.length; i++)
                                    if ((d[i].device_type || "").indexOf("relay") !== -1)
                                        backend.fetchRelayNetwork(d[i].device_code)
                            }
                        }
                        ActionBtn {
                            visible: {
                                var d = backend.devices
                                for (var i = 0; i < d.length; i++)
                                    if ((d[i].device_type || "").indexOf("relay") !== -1) return true
                                return false
                            }
                            label: centerPanel.activeTab === "bobnet" ? "[ BOBNET ]" : "  BOBNET  "
                            height: 24
                            width: 90
                            onActivated: centerPanel.activeTab = "bobnet"
                        }
                        ActionBtn {
                            visible: {
                                var d = backend.devices
                                for (var i = 0; i < d.length; i++)
                                    if ((d[i].device_type || "").indexOf("beacon") !== -1) return true
                                return false
                            }
                            label: centerPanel.activeTab === "beacon" ? "[ BEACON ]" : "  BEACON  "
                            height: 24
                            width: 90
                            onActivated: centerPanel.activeTab = "beacon"
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
                    }
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
                                    label: "[ DRY RUN ]"
                                    width: 90
                                    height: 24
                                    onActivated: backend.travelDryRun(modelData.designation || "")
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
                ColumnLayout {
                    visible: centerPanel.activeTab === "system"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: backend.asteroidBelts.length > 0
                                  ? backend.asteroidBelts.length + " BELT"
                                    + (backend.asteroidBelts.length !== 1 ? "S" : "")
                                    + " — DATA FROM LAST SCAN"
                                  : "NO SCAN DATA"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                            Layout.fillWidth: true
                        }
                        Text {
                            property int threatCount: {
                                var n = 0, a = backend.asteroids
                                for (var i = 0; i < a.length; i++) if (a[i].impact_target) n++
                                return n
                            }
                            visible: threatCount > 0
                            text: "⚠ " + threatCount + " THREAT" + (threatCount !== 1 ? "S" : "")
                            color: theme.txtRed
                            font { family: theme.mono; pointSize: 8; bold: true }
                        }
                        ActionBtn {
                            label: "[ MAP ]"
                            width: 68; height: 24
                            onActivated: backend.fetchSystemMap()
                        }
                        ActionBtn {
                            label: "[ ASTEROIDS ]"
                            width: 100; height: 24
                            onActivated: backend.fetchAsteroids()
                        }
                        ActionBtn {
                            label: "[ RESCAN ]"
                            width: 90; height: 24
                            onActivated: backend.scan()
                        }
                    }

                    Flickable {
                        id: scanFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: scanContent.implicitHeight
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: scanContent
                            width: scanFlickable.width
                            spacing: 8

                            // ── System Map ── //
                            Column {
                                width: scanContent.width
                                spacing: 3
                                visible: backend.systemMap.length > 0

                                Text {
                                    text: "── SYSTEM MAP ───────────────────────────"
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 8 }
                                }

                                // Header row
                                RowLayout {
                                    width: parent.width
                                    spacing: 0
                                    Text {
                                        text: "LOCATION"
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 7 }
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: "DEVICES"
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 7 }
                                        Layout.preferredWidth: 64
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Text {
                                        text: "REPLIC."
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 7 }
                                        Layout.preferredWidth: 64
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Text {
                                        text: "RSRC"
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 7 }
                                        Layout.preferredWidth: 48
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                Rectangle {
                                    width: parent.width; height: 1
                                    color: theme.border
                                }

                                Repeater {
                                    model: backend.systemMap

                                    Rectangle {
                                        property string locCode: modelData.location
                                                              || modelData.designation
                                                              || modelData.code || ""
                                        property int devCount: modelData.device_count
                                                            || modelData.devices || 0
                                        property int repCount: modelData.replicant_count
                                                            || modelData.replicants || 0
                                        property int resCount: {
                                            var r = modelData.resource_count
                                                 || modelData.resources
                                            if (typeof r === "number") return r
                                            if (r && typeof r === "object") return Object.keys(r).length
                                            return 0
                                        }
                                        property bool isHere: locCode === backend.location
                                                           || locCode.indexOf(backend.location) === 0

                                        width: scanContent.width
                                        height: 24
                                        color: isHere ? "#0d1a0e" : "transparent"
                                        border.color: isHere ? theme.border : "transparent"
                                        border.width: 1

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                            spacing: 0
                                            Text {
                                                text: (isHere ? "▸ " : "  ") + locCode.toUpperCase()
                                                color: isHere ? theme.txtBright : theme.txtMid
                                                font { family: theme.mono; pointSize: 8 }
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: devCount > 0 ? devCount : "—"
                                                color: devCount > 0 ? theme.txtAmber : theme.txtDim
                                                font { family: theme.mono; pointSize: 8 }
                                                Layout.preferredWidth: 64
                                                horizontalAlignment: Text.AlignRight
                                            }
                                            Text {
                                                text: repCount > 0 ? repCount : "—"
                                                color: repCount > 0 ? theme.txtAccent : theme.txtDim
                                                font { family: theme.mono; pointSize: 8 }
                                                Layout.preferredWidth: 64
                                                horizontalAlignment: Text.AlignRight
                                            }
                                            Text {
                                                text: resCount > 0 ? resCount : "—"
                                                color: resCount > 0 ? theme.txtMid : theme.txtDim
                                                font { family: theme.mono; pointSize: 8 }
                                                Layout.preferredWidth: 48
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Belts ── //
                            Text {
                                text: "── BELTS ────────────────────────────────"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                                visible: backend.asteroidBelts.length > 0
                            }

                            Repeater {
                                model: backend.asteroidBelts

                                Rectangle {
                                    width: scanContent.width
                                    color: theme.hover
                                    border.color: theme.border
                                    border.width: 1
                                    height: beltCol.implicitHeight + 16

                                    Column {
                                        id: beltCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        spacing: 6

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
                                                    width: (scanContent.width - 28) / 3
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
                            }

                            // ── Asteroid Threats ── //
                            Text {
                                text: "── ASTEROID THREATS ─────────────────────"
                                color: theme.txtRed
                                font { family: theme.mono; pointSize: 8 }
                                topPadding: backend.asteroidBelts.length > 0 ? 4 : 0
                            }

                            Text {
                                visible: {
                                    var a = backend.asteroids
                                    for (var i = 0; i < a.length; i++) if (a[i].impact_target) return false
                                    return true
                                }
                                text: backend.asteroids.length === 0
                                      ? "no data — press [ ASTEROIDS ] to check"
                                      : "no active threats in this system"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                                leftPadding: 8
                            }

                            Repeater {
                                model: backend.asteroids.filter(function(a) { return !!a.impact_target })

                                Rectangle {
                                    id: asteroidDelegate
                                    property var asteroid: modelData
                                    width: scanContent.width
                                    color: theme.hover
                                    border.color: theme.txtRed
                                    border.width: 1
                                    height: asteroidCol.implicitHeight + 16

                                    Column {
                                        id: asteroidCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        spacing: 6

                                        // Header
                                        RowLayout {
                                            width: parent.width
                                            spacing: 8
                                            Text {
                                                text: "⚠ " + (modelData.designation || "ASTEROID")
                                                color: theme.txtRed
                                                font { family: theme.mono; pointSize: 10; bold: true }
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: (modelData.size_class || "").toUpperCase()
                                                color: theme.txtAmber
                                                font { family: theme.mono; pointSize: 8 }
                                            }
                                        }

                                        // Target + ETA
                                        RowLayout {
                                            width: parent.width
                                            spacing: 16
                                            Text {
                                                text: "TARGET  " + (modelData.impact_target || "—")
                                                color: theme.txtBright
                                                font { family: theme.mono; pointSize: 8 }
                                            }
                                            Text {
                                                text: "ETA  " + (modelData.impact_eta || "—")
                                                color: theme.txtAmber
                                                font { family: theme.mono; pointSize: 8 }
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: (modelData.active_plates || 0) + " PLATE"
                                                      + ((modelData.active_plates || 0) !== 1 ? "S" : "") + " ACTIVE"
                                                color: (modelData.active_plates || 0) > 0 ? theme.txtMid : theme.txtDim
                                                font { family: theme.mono; pointSize: 8 }
                                            }
                                        }

                                        // Progress bar
                                        RowLayout {
                                            width: parent.width
                                            spacing: 8
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 8
                                                color: "#060c07"
                                                border.color: theme.border; border.width: 1
                                                Rectangle {
                                                    width: Math.max(0, Math.min(1, (modelData.progress_pct || 0) / 100)) * parent.width
                                                    height: parent.height
                                                    color: (modelData.progress_pct || 0) >= 75 ? theme.txtBright
                                                         : (modelData.progress_pct || 0) >= 40 ? theme.txtAmber
                                                         : theme.txtRed
                                                }
                                            }
                                            Text {
                                                text: (modelData.progress_pct || 0).toFixed(1) + "%"
                                                color: theme.txtMid
                                                font { family: theme.mono; pointSize: 8 }
                                                Layout.preferredWidth: 42
                                            }
                                        }
                                        Text {
                                            text: "STRENGTH  " + (modelData.current_progress || 0)
                                                  + " / " + (modelData.required_strength || "?")
                                            color: theme.txtDim
                                            font { family: theme.mono; pointSize: 7 }
                                        }

                                        // Per-surge-plate action rows
                                        Repeater {
                                            model: backend.devices.filter(function(d) {
                                                return (d.device_type || "").indexOf("surge") !== -1
                                                    || (d.device_type || "").indexOf("propulsor") !== -1
                                            })
                                            RowLayout {
                                                width: asteroidCol.width
                                                spacing: 6
                                                Text {
                                                    text: (modelData.device_type || "PLATE").toUpperCase().replace(/_/g, " ")
                                                          + "  " + (modelData.device_code || "")
                                                    color: theme.txtDim
                                                    font { family: theme.mono; pointSize: 8 }
                                                    Layout.fillWidth: true
                                                }
                                                ActionBtn {
                                                    property bool atAsteroid: (modelData.location || "") === (asteroidDelegate.asteroid.designation || "")
                                                    property bool isActive: (modelData.status || "").toLowerCase() === "active"
                                                    label: atAsteroid
                                                           ? (isActive ? "[ RUNNING ]" : "[ ACTIVATE ]")
                                                           : "[ SEND ]"
                                                    enabled: !isActive
                                                    width: 90; height: 24
                                                    onActivated: {
                                                        if (atAsteroid)
                                                            backend.activateDevice(modelData.device_code)
                                                        else
                                                            backend.travelDevice(modelData.device_code,
                                                                                 asteroidDelegate.asteroid.designation || "")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
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

                // ── Trade tab ── //
                ColumnLayout {
                    id: tradeTab
                    property string view: "directory"
                    property string shopCode: ""
                    property string shopName: ""

                    visible: centerPanel.activeTab === "trade"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ActionBtn {
                            label: "[ ← BACK ]"
                            visible: tradeTab.view === "shop"
                            width: 80; height: 24
                            onActivated: tradeTab.view = "directory"
                        }
                        Text {
                            text: tradeTab.view === "directory" ? "TRADING NETWORK" : tradeTab.shopName
                            color: theme.txtAccent
                            font { family: theme.mono; pointSize: 10; bold: true }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        ActionBtn {
                            label: "[ ↺ ]"
                            visible: tradeTab.view === "directory"
                            width: 36; height: 24
                            onActivated: backend.fetchTraders()
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    // Directory view
                    ListView {
                        id: tabTraderList
                        visible: tradeTab.view === "directory"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.traders
                        clip: true
                        spacing: 5

                        delegate: Rectangle {
                            width: tabTraderList.width
                            height: tabTraderCol.implicitHeight + 16
                            color: theme.hover
                            border.color: theme.border
                            border.width: 1

                            ColumnLayout {
                                id: tabTraderCol
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
                                            tradeTab.shopCode = modelData.controller_code || ""
                                            tradeTab.shopName = modelData.shop_name || "SHOP"
                                            tradeTab.view = "shop"
                                            backend.browseShop(tradeTab.shopCode)
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
                            visible: tabTraderList.count === 0
                            anchors.centerIn: parent
                            text: "no traders found — press ↺ to load"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }

                    // Shop trade list
                    ListView {
                        id: tabShopTradeList
                        visible: tradeTab.view === "shop"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.shopTrades
                        clip: true
                        spacing: 5

                        delegate: Rectangle {
                            id: tabTradeCard
                            property int stock: modelData.current_stock || 0
                            width: tabShopTradeList.width
                            height: tabTradeCardCol.implicitHeight + 16
                            color: theme.hover
                            border.color: tabTradeCard.stock > 0 ? theme.border : theme.txtDim
                            border.width: 1
                            opacity: tabTradeCard.stock > 0 ? 1.0 : 0.5

                            ColumnLayout {
                                id: tabTradeCardCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        text: modelData.name || "TRADE"
                                        color: tabTradeCard.stock > 0 ? theme.txtAccent : theme.txtDim
                                        font { family: theme.mono; pointSize: 9; bold: true }
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "×" + tabTradeCard.stock
                                        color: tabTradeCard.stock > 0 ? theme.txtAmber : theme.txtRed
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                    ActionBtn {
                                        label: "[ EXECUTE ]"
                                        width: 90; height: 24
                                        enabled: tabTradeCard.stock > 0
                                        onActivated: backend.executeTrade(tradeTab.shopCode, modelData.trade_code || "")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text { text: "COST"; color: theme.txtDim; font { family: theme.mono; pointSize: 7 } }
                                        Repeater {
                                            model: {
                                                var res = (modelData.criteria || {}).resources || {}
                                                return Object.keys(res).map(function(k) { return { name: k, qty: res[k] } })
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
                                                return Object.keys(dev).map(function(k) { return { name: k, qty: dev[k] } })
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
                                        Text { text: "GET"; color: theme.txtDim; font { family: theme.mono; pointSize: 7 } }
                                        Repeater {
                                            model: {
                                                var res = (modelData.rewards || {}).resources || {}
                                                return Object.keys(res).map(function(k) { return { name: k, qty: res[k] } })
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
                                                return Object.keys(dev).map(function(k) { return { name: k, qty: dev[k] } })
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
                            visible: tabShopTradeList.count === 0
                            anchors.centerIn: parent
                            text: "no trades at this shop"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }
                }

                // ── Survey tab ── //
                ColumnLayout {
                    visible: centerPanel.activeTab === "survey"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

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

                    Flickable {
                        id: surveyFlickable
                        visible: {
                            var d = backend.devices
                            for (var i = 0; i < d.length; i++)
                                if ((d[i].device_type || "").indexOf("survey") !== -1) return true
                            return false
                        }
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: surveyContent.implicitHeight
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: surveyContent
                            width: surveyFlickable.width
                            spacing: 6

                            // ── Planets ── //
                            Text {
                                text: "── PLANETS ──────────────────────────────"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                            }

                            Text {
                                visible: backend.planets.length === 0
                                text: "no planet data — press [ SCAN SYSTEM ] first"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                                leftPadding: 8
                            }

                            Repeater {
                                model: backend.planets

                                Rectangle {
                                    id: planetDelegate
                                    property var planet: modelData
                                    width: surveyContent.width
                                    color: theme.hover
                                    border.color: theme.border
                                    border.width: 1
                                    height: planetCol.implicitHeight + 16

                                    Column {
                                        id: planetCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        spacing: 6

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

                                        Repeater {
                                            model: {
                                                var drones = []
                                                var d = backend.devices
                                                for (var i = 0; i < d.length; i++)
                                                    if ((d[i].device_type || "").indexOf("survey") !== -1)
                                                        drones.push(d[i])
                                                return drones
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
                                                ActionBtn {
                                                    property bool atPlanet: (modelData.location || "") === (planetDelegate.planet.designation || "")
                                                    property bool droneBusy: {
                                                        var s = (modelData.status || "").toLowerCase()
                                                        return s === "scanning" || s === "active" || s === "busy"
                                                    }
                                                    label: atPlanet ? (droneBusy ? "[ SCANNING… ]" : "[ SCAN ]") : "[ SEND ]"
                                                    enabled: !(atPlanet && droneBusy)
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
                            }

                            // ── Belts ── //
                            Text {
                                text: "── BELTS ────────────────────────────────"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                                topPadding: 4
                            }

                            Text {
                                visible: backend.asteroidBelts.length === 0
                                text: "no belt data — press [ SCAN SYSTEM ] first"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                                leftPadding: 8
                            }

                            Repeater {
                                model: backend.asteroidBelts

                                Rectangle {
                                    id: beltSurveyDelegate
                                    property var belt: modelData
                                    width: surveyContent.width
                                    color: theme.hover
                                    border.color: theme.border
                                    border.width: 1
                                    height: beltSurveyCol.implicitHeight + 16

                                    Column {
                                        id: beltSurveyCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        spacing: 6

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

                                        Repeater {
                                            model: {
                                                var drones = []
                                                var d = backend.devices
                                                for (var i = 0; i < d.length; i++)
                                                    if ((d[i].device_type || "").indexOf("survey") !== -1)
                                                        drones.push(d[i])
                                                return drones
                                            }
                                            RowLayout {
                                                width: beltSurveyCol.width
                                                spacing: 6

                                                Text {
                                                    text: (modelData.device_type || "DRONE").toUpperCase().replace(/_/g, " ")
                                                          + "  " + (modelData.device_code || "")
                                                    color: theme.txtDim
                                                    font { family: theme.mono; pointSize: 8 }
                                                    Layout.fillWidth: true
                                                }

                                                ActionBtn {
                                                    property bool atBelt: (modelData.location || "") === (beltSurveyDelegate.belt.designation || "")
                                                    property bool droneBusy: {
                                                        var s = (modelData.status || "").toLowerCase()
                                                        return s === "scanning" || s === "searching" || s === "active" || s === "busy"
                                                    }
                                                    label: atBelt ? (droneBusy ? "[ BUSY… ]" : "[ SCAN ]") : "[ SEND ]"
                                                    enabled: !(atBelt && droneBusy)
                                                    width: 76; height: 24
                                                    onActivated: {
                                                        if (atBelt)
                                                            backend.scanWithDevice(modelData.device_code)
                                                        else
                                                            backend.travelDevice(modelData.device_code,
                                                                                 beltSurveyDelegate.belt.designation || "")
                                                    }
                                                }

                                                ActionBtn {
                                                    property bool atBelt: (modelData.location || "") === (beltSurveyDelegate.belt.designation || "")
                                                    property bool droneBusy: {
                                                        var s = (modelData.status || "").toLowerCase()
                                                        return s === "scanning" || s === "searching" || s === "active" || s === "busy"
                                                    }
                                                    visible: atBelt
                                                    label: droneBusy ? "[ SRCHING… ]" : "[ SEARCH ]"
                                                    enabled: !droneBusy
                                                    width: 84; height: 24
                                                    onActivated: backend.searchWithDevice(modelData.device_code)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── AMI Controllers tab ── //
                ColumnLayout {
                    visible: centerPanel.activeTab === "ami"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    ListView {
                        id: controllerList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.devices.filter(function(d) {
                            return (d.device_type || "").indexOf("controller") !== -1
                        })
                        clip: true
                        spacing: 8

                        delegate: Rectangle {
                            id: ctrlDelegate
                            property var ctrl: modelData
                            width: controllerList.width
                            color: theme.hover
                            border.color: theme.border
                            border.width: 1
                            height: ctrlCol.implicitHeight + 16

                            Column {
                                id: ctrlCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 6

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: "◈ " + (modelData.device_type || "CONTROLLER").toUpperCase().replace(/_/g, " ")
                                        color: theme.txtAccent
                                        font { family: theme.mono; pointSize: 10; bold: true }
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (modelData.status || "").toUpperCase()
                                        color: theme.txtMid
                                        font { family: theme.mono; pointSize: 8 }
                                    }
                                }

                                Text {
                                    text: "CODE  " + (modelData.device_code || "—")
                                          + "   LOC  " + (modelData.location || "—")
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 8 }
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: !!(modelData.directive || modelData.current_directive)
                                    text: "DIRECTIVE  " + (modelData.directive || modelData.current_directive || "")
                                    color: theme.txtAmber
                                    font { family: theme.mono; pointSize: 8 }
                                }

                                Text {
                                    property var fleet: modelData.fleet || modelData.assigned_devices || []
                                    visible: fleet.length > 0
                                    text: "FLEET  " + fleet.map(function(d) {
                                        return d.device_code || d
                                    }).join(", ")
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 8 }
                                    width: parent.width
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }

                                // Fleet management
                                RowLayout {
                                    width: parent.width
                                    spacing: 4
                                    ActionBtn {
                                        label: "[ ADOPT… ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: {
                                            amiAdoptDlg.controllerCode = modelData.device_code
                                            amiAdoptDlg.open()
                                        }
                                    }
                                    ActionBtn {
                                        label: "[ RELEASE… ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: {
                                            amiReleaseDlg.controllerCode = modelData.device_code
                                            amiReleaseDlg.open()
                                        }
                                    }
                                    ActionBtn {
                                        label: "[ ASSEMBLE ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: backend.amiAssemble(modelData.device_code)
                                    }
                                }

                                // Execution controls
                                RowLayout {
                                    width: parent.width
                                    spacing: 4
                                    ActionBtn {
                                        label: "[ LAUNCH ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: backend.amiLaunch(modelData.device_code)
                                    }
                                    ActionBtn {
                                        label: "[ WITHDRAW ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: backend.amiWithdraw(modelData.device_code)
                                    }
                                    ActionBtn {
                                        label: "[ RESUME ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: backend.amiResume(modelData.device_code)
                                    }
                                    ActionBtn {
                                        label: "[ CLEAR ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: backend.amiClearDirective(modelData.device_code)
                                    }
                                }

                                // Directives (survey controller only)
                                RowLayout {
                                    width: parent.width
                                    spacing: 4
                                    visible: (modelData.device_type || "").indexOf("survey") !== -1

                                    ActionBtn {
                                        label: "[ SURVEY SYSTEM… ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: {
                                            amiSurveyDlg.controllerCode = modelData.device_code
                                            amiSurveyDlg.moonsMode = "all"
                                            amiSurveyDlg.recallEnabled = true
                                            amiSurveyDlg.visible = true
                                        }
                                    }
                                    ActionBtn {
                                        label: "[ BELT SEARCH ]"
                                        Layout.fillWidth: true; height: 24
                                        onActivated: backend.amiBeltSearch(modelData.device_code)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: controllerList.count === 0
                            anchors.centerIn: parent
                            text: "no AMI controllers — print one first"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }
                }

                // ── BobNet tab ── //
                ColumnLayout {
                    id: bobnetTab
                    visible: centerPanel.activeTab === "bobnet"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    property string selectedRelay: ""
                    property string selectedChannel: "#general"

                    // Auto-select first relay and fetch when tab becomes visible
                    onVisibleChanged: {
                        if (visible && selectedRelay === "") {
                            var d = backend.devices
                            for (var i = 0; i < d.length; i++) {
                                if ((d[i].device_type || "").indexOf("relay") !== -1) {
                                    bobnetTab.selectedRelay = d[i].device_code
                                    backend.fetchBobnetMessages(bobnetTab.selectedRelay)
                                    break
                                }
                            }
                        } else if (visible && selectedRelay !== "") {
                            backend.fetchBobnetMessages(selectedRelay)
                        }
                    }

                    // Auto-poll every 30s while tab is open
                    Timer {
                        running: centerPanel.activeTab === "bobnet"
                                 && bobnetTab.selectedRelay !== ""
                        interval: 30000
                        repeat: true
                        onTriggered: backend.fetchBobnetMessages(bobnetTab.selectedRelay)
                    }

                    // ── Relay selector (if multiple) + refresh ── //
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "RELAY:"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }

                        Repeater {
                            model: backend.devices.filter(function(d) {
                                return (d.device_type || "").indexOf("relay") !== -1
                            })
                            Rectangle {
                                property bool sel: bobnetTab.selectedRelay === modelData.device_code
                                height: 22; width: bnRelayLbl.implicitWidth + 14
                                color: sel ? theme.hover : "transparent"
                                border.color: sel ? theme.txtMid : theme.border
                                border.width: 1
                                Text {
                                    id: bnRelayLbl
                                    anchors.centerIn: parent
                                    text: modelData.device_code || "RELAY"
                                    color: parent.sel ? theme.txtBright : theme.txtMid
                                    font { family: theme.mono; pointSize: 7 }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        bobnetTab.selectedRelay = modelData.device_code
                                        backend.fetchBobnetMessages(modelData.device_code)
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: backend.bobnetMessages.length + " MSG"
                            visible: backend.bobnetMessages.length > 0
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }

                        ActionBtn {
                            label: "[ ↺ ]"
                            width: 36; height: 24
                            onActivated: {
                                if (bobnetTab.selectedRelay)
                                    backend.fetchBobnetMessages(bobnetTab.selectedRelay)
                            }
                        }
                    }

                    // ── Channel chips ── //
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "CHANNEL:"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }

                        Repeater {
                            model: {
                                var seen = {"#general": true, "#trade": true}
                                var channels = ["#general", "#trade"]
                                var msgs = backend.bobnetMessages
                                for (var i = 0; i < msgs.length; i++) {
                                    var ch = msgs[i].channel || ""
                                    if (ch && !seen[ch]) { seen[ch] = true; channels.push(ch) }
                                }
                                return channels
                            }
                            Rectangle {
                                property bool sel: bobnetTab.selectedChannel === modelData
                                height: 22; width: bnChLbl.implicitWidth + 14
                                color: sel ? theme.hover : "transparent"
                                border.color: sel ? theme.txtMid : theme.border
                                border.width: 1
                                Text {
                                    id: bnChLbl
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.sel ? theme.txtBright : theme.txtMid
                                    font { family: theme.mono; pointSize: 8 }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: bobnetTab.selectedChannel = modelData
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    // ── Chat log (newest at bottom, BottomToTop) ── //
                    ListView {
                        id: bobnetList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.bobnetMessages.filter(function(m) {
                            return (m.channel || "") === bobnetTab.selectedChannel
                        })
                        verticalLayoutDirection: ListView.BottomToTop
                        clip: true
                        spacing: 2

                        delegate: Column {
                            width: bobnetList.width
                            spacing: 2

                            // Sender line
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Text {
                                    text: (modelData.replicant_name || "UNKNOWN").toUpperCase()
                                    color: (modelData.replicant_code || "") === backend.replicantCode
                                           ? theme.txtAccent : theme.txtBright
                                    font { family: theme.mono; pointSize: 8; bold: true }
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: (modelData.current_star || "").toUpperCase()
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 7 }
                                }
                                Text {
                                    text: {
                                        var t = modelData.time || ""
                                        return t.length > 16 ? t.substring(0, 16) : t
                                    }
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 7 }
                                }
                            }

                            // Message body
                            Text {
                                width: parent.width
                                text: modelData.message || ""
                                color: theme.txtMid
                                font { family: theme.mono; pointSize: 9 }
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                leftPadding: 8
                            }

                            Rectangle {
                                width: parent.width; height: 1
                                color: theme.border; opacity: 0.4
                            }
                        }

                        Text {
                            visible: bobnetList.count === 0
                            anchors.centerIn: parent
                            text: bobnetTab.selectedRelay === ""
                                  ? "no relay selected"
                                  : "no messages on " + bobnetTab.selectedChannel
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }

                    // ── Send row ── //
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: bobnetTab.selectedChannel
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: "#060c07"
                            border.color: bnInput.activeFocus ? theme.txtMid : theme.border
                            border.width: 1

                            Text {
                                anchors { fill: parent; leftMargin: 8 }
                                verticalAlignment: Text.AlignVCenter
                                text: "message…"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 9 }
                                visible: bnInput.text === ""
                            }
                            TextInput {
                                id: bnInput
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 9 }
                                Keys.onReturnPressed: {
                                    if (text.trim() !== "" && bobnetTab.selectedRelay !== "") {
                                        backend.sendBobnetMessage(bobnetTab.selectedChannel, text.trim())
                                        text = ""
                                    }
                                }
                            }
                        }

                        ActionBtn {
                            label: "[ SEND ]"
                            width: 72; height: 28
                            enabled: bnInput.text.trim() !== ""
                                     && bobnetTab.selectedRelay !== ""
                            onActivated: {
                                backend.sendBobnetMessage(bobnetTab.selectedChannel, bnInput.text.trim())
                                bnInput.text = ""
                            }
                        }
                    }
                }

                // ── Relay tab ── //
                ColumnLayout {
                    visible: centerPanel.activeTab === "relay"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "FTL RELAY NETWORK"
                            color: theme.txtAccent
                            font { family: theme.mono; pointSize: 10; bold: true }
                            Layout.fillWidth: true
                        }
                        ActionBtn {
                            label: "[ ↺ REFRESH ALL ]"
                            width: 130; height: 24
                            onActivated: {
                                var d = backend.devices
                                for (var i = 0; i < d.length; i++)
                                    if ((d[i].device_type || "").indexOf("relay") !== -1)
                                        backend.fetchRelayNetwork(d[i].device_code)
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    Flickable {
                        id: relayFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: relayContent.implicitHeight
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: relayContent
                            width: relayFlickable.width
                            spacing: 8

                            Repeater {
                                model: backend.devices.filter(function(d) {
                                    return (d.device_type || "").indexOf("relay") !== -1
                                })

                                Rectangle {
                                    id: relayCard
                                    property var relay: modelData
                                    property var netData: {
                                        var nets = backend.relayNetworks
                                        for (var i = 0; i < nets.length; i++)
                                            if (nets[i].relay_code === modelData.device_code) return nets[i]
                                        return null
                                    }
                                    width: relayContent.width
                                    color: theme.hover
                                    border.color: (modelData.status || "").toLowerCase() === "active"
                                                  ? theme.txtMid : theme.border
                                    border.width: 1
                                    height: relayCardCol.implicitHeight + 16

                                    Column {
                                        id: relayCardCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        spacing: 6

                                        RowLayout {
                                            width: parent.width
                                            spacing: 8
                                            Text {
                                                text: "◈ " + (modelData.device_type || "RELAY").toUpperCase().replace(/_/g, " ")
                                                color: theme.txtAccent
                                                font { family: theme.mono; pointSize: 10; bold: true }
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: relayCard.netData ? relayCard.netData.status.toUpperCase() : (modelData.status || "").toUpperCase()
                                                color: (modelData.status || "").toLowerCase() === "active"
                                                       ? theme.txtBright : theme.txtAmber
                                                font { family: theme.mono; pointSize: 8 }
                                            }
                                        }

                                        Text {
                                            text: "CODE  " + (modelData.device_code || "—")
                                                  + "   LOC  " + (modelData.location || "—")
                                            color: theme.txtDim
                                            font { family: theme.mono; pointSize: 8 }
                                            width: parent.width; elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: relayCard.netData !== null && relayCard.netData.range_ly !== undefined
                                            text: "RANGE  " + (relayCard.netData ? (relayCard.netData.range_ly || "?") : "?") + " LY"
                                            color: theme.txtDim
                                            font { family: theme.mono; pointSize: 8 }
                                        }

                                        // Connections
                                        Column {
                                            width: parent.width
                                            spacing: 3
                                            visible: relayCard.netData !== null
                                                     && (relayCard.netData.connections || []).length > 0

                                            Text {
                                                text: "── CONNECTIONS"
                                                color: theme.txtDim
                                                font { family: theme.mono; pointSize: 7 }
                                            }

                                            Repeater {
                                                model: relayCard.netData ? (relayCard.netData.connections || []) : []
                                                RowLayout {
                                                    width: relayCardCol.width
                                                    spacing: 8
                                                    Text {
                                                        text: "◉ " + (modelData.star_name || modelData.device_code || "RELAY")
                                                        color: theme.txtMid
                                                        font { family: theme.mono; pointSize: 8 }
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: modelData.device_code || ""
                                                        color: theme.txtDim
                                                        font { family: theme.mono; pointSize: 7 }
                                                    }
                                                    Text {
                                                        text: modelData.distance_ly !== undefined
                                                              ? Number(modelData.distance_ly).toFixed(2) + " LY"
                                                              : (modelData.distance !== undefined
                                                                 ? Number(modelData.distance).toFixed(2) + " LY" : "")
                                                        color: theme.txtAmber
                                                        font { family: theme.mono; pointSize: 8 }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            visible: relayCard.netData !== null
                                                     && (relayCard.netData.connections || []).length === 0
                                            text: "no connections detected"
                                            color: theme.txtDim
                                            font { family: theme.mono; pointSize: 8 }
                                            leftPadding: 8
                                        }

                                        Text {
                                            visible: relayCard.netData === null
                                            text: "press [ REFRESH ] to load network data"
                                            color: theme.txtDim
                                            font { family: theme.mono; pointSize: 8 }
                                            leftPadding: 8
                                        }

                                        RowLayout {
                                            width: parent.width
                                            spacing: 4
                                            ActionBtn {
                                                label: "[ ACTIVATE ]"
                                                Layout.fillWidth: true; height: 24
                                                enabled: (modelData.status || "").toLowerCase() !== "active"
                                                onActivated: backend.activateRelay(modelData.device_code)
                                            }
                                            ActionBtn {
                                                label: "[ ↺ NETWORK ]"
                                                Layout.fillWidth: true; height: 24
                                                onActivated: backend.fetchRelayNetwork(modelData.device_code)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Beacon tab ── //
                ColumnLayout {
                    id: beaconTab
                    visible: centerPanel.activeTab === "beacon"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    property string selectedBeacon: ""
                    property string dtFilter: ""
                    property string repFilter: ""

                    // Auto-select first beacon when devices load
                    Connections {
                        target: backend
                        function onDevicesChanged() {
                            if (beaconTab.selectedBeacon === "") {
                                var d = backend.devices
                                for (var i = 0; i < d.length; i++) {
                                    if ((d[i].device_type || "").indexOf("beacon") !== -1) {
                                        beaconTab.selectedBeacon = d[i].device_code
                                        break
                                    }
                                }
                            }
                        }
                    }

                    // Beacon selector chips
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "BEACON:"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }
                        Repeater {
                            model: backend.devices.filter(function(d) {
                                return (d.device_type || "").indexOf("beacon") !== -1
                            })
                            Rectangle {
                                property bool selected: beaconTab.selectedBeacon === modelData.device_code
                                height: 22; width: bcChipLbl.implicitWidth + 14
                                color: selected ? theme.hover : "transparent"
                                border.color: selected ? theme.txtMid : theme.border
                                border.width: 1
                                Text {
                                    id: bcChipLbl
                                    anchors.centerIn: parent
                                    text: modelData.device_code || "BEACON"
                                    color: parent.selected ? theme.txtBright : theme.txtMid
                                    font { family: theme.mono; pointSize: 7 }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: beaconTab.selectedBeacon = modelData.device_code
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Filters + fetch row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "TYPE:"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }
                        Rectangle {
                            width: 120; height: 24
                            color: "#060c07"; border.color: theme.border; border.width: 1
                            Text {
                                anchors { fill: parent; leftMargin: 6 }
                                verticalAlignment: Text.AlignVCenter
                                text: "any"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                                visible: bcDtInput.text === ""
                            }
                            TextInput {
                                id: bcDtInput
                                anchors { fill: parent; leftMargin: 6 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 8 }
                                onTextChanged: beaconTab.dtFilter = text.trim().toLowerCase()
                            }
                        }

                        Text {
                            text: "REPLICANT:"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }
                        Rectangle {
                            width: 120; height: 24
                            color: "#060c07"; border.color: theme.border; border.width: 1
                            Text {
                                anchors { fill: parent; leftMargin: 6 }
                                verticalAlignment: Text.AlignVCenter
                                text: "any"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 8 }
                                visible: bcRepInput.text === ""
                            }
                            TextInput {
                                id: bcRepInput
                                anchors { fill: parent; leftMargin: 6 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 8 }
                                onTextChanged: beaconTab.repFilter = text.trim()
                            }
                        }

                        ActionBtn {
                            label: "[ FETCH ]"
                            width: 72; height: 24
                            enabled: beaconTab.selectedBeacon !== ""
                            onActivated: backend.fetchBeaconAudit(beaconTab.selectedBeacon,
                                                                  beaconTab.dtFilter,
                                                                  beaconTab.repFilter)
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: backend.beaconAudit.length + " ENTRIES"
                            visible: backend.beaconAudit.length > 0
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 8 }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    // Column headers
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: " "
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                            Layout.preferredWidth: 18
                        }
                        Text {
                            text: "TYPE"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "REPLICANT"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                            Layout.preferredWidth: 90
                        }
                        Text {
                            text: "LOCATION"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                            Layout.preferredWidth: 100
                        }
                        Text {
                            text: "TIME"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                            Layout.preferredWidth: 80
                        }
                    }

                    // Audit log
                    ListView {
                        id: beaconAuditList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: backend.beaconAudit
                        clip: true
                        spacing: 0

                        delegate: Rectangle {
                            property bool isDeparture: (modelData.travel_type || "") === "departure"
                            width: beaconAuditList.width
                            height: 26
                            color: index % 2 === 0 ? "transparent" : "#050b05"

                            RowLayout {
                                anchors { fill: parent; leftMargin: 2; rightMargin: 2 }
                                spacing: 0
                                Text {
                                    text: isDeparture ? "↑" : "↓"
                                    color: isDeparture ? theme.txtRed : theme.txtBright
                                    font { family: theme.mono; pointSize: 9 }
                                    Layout.preferredWidth: 18
                                }
                                Text {
                                    text: (modelData.device_type || "UNKNOWN").replace(/_/g, " ")
                                    color: theme.txtMid
                                    font { family: theme.mono; pointSize: 8 }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.replicant_code || "—"
                                    color: modelData.replicant_code === backend.replicantCode
                                           ? theme.txtAccent : theme.txtDim
                                    font { family: theme.mono; pointSize: 7 }
                                    Layout.preferredWidth: 90
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: (modelData.location || "—").toUpperCase()
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 7 }
                                    Layout.preferredWidth: 100
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: {
                                        var t = modelData.logged_at || ""
                                        if (!t) return "—"
                                        return t.length > 16 ? t.substring(0, 16) : t
                                    }
                                    color: theme.txtDim
                                    font { family: theme.mono; pointSize: 7 }
                                    Layout.preferredWidth: 80
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: 1
                                color: theme.border; opacity: 0.3
                            }
                        }

                        Text {
                            visible: beaconAuditList.count === 0
                            anchors.centerIn: parent
                            text: beaconTab.selectedBeacon === ""
                                  ? "no beacon selected"
                                  : "press [ FETCH ] to load audit log"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 9 }
                        }
                    }

                    // Load more
                    ActionBtn {
                        label: "[ LOAD MORE ]"
                        Layout.fillWidth: true
                        height: 26
                        visible: backend.beaconAuditHasMore
                        onActivated: backend.fetchBeaconAuditMore()
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
                        model: backend.messages.filter(function(m) {
                            return !m.read && !m.read_at
                        })
                        clip: true
                        spacing: 4

                        delegate: Rectangle {
                            id: msgDelegate
                            width: messageList.width
                            height: msgCol.implicitHeight + 16
                            color: theme.hover
                            border.color: theme.txtDim
                            border.width: 1

                            Column {
                                id: msgCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 4

                                RowLayout {
                                    width: parent.width
                                    spacing: 6
                                    Text {
                                        text: (modelData.from || modelData.sender ||
                                               modelData.from_replicant || "SYSTEM").toUpperCase()
                                        color: theme.txtBright
                                        font { family: theme.mono; pointSize: 9; bold: true }
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.created_at || ""
                                        color: theme.txtDim
                                        font { family: theme.mono; pointSize: 7 }
                                    }
                                    ActionBtn {
                                        label: "[ ✓ ]"
                                        width: 36; height: 20
                                        onActivated: {
                                            if (modelData.id !== undefined)
                                                backend.markMessageRead(modelData.id)
                                        }
                                    }
                                }

                                Text {
                                    visible: (modelData.subject || "") !== ""
                                    width: parent.width
                                    text: modelData.subject || ""
                                    color: theme.txtAccent
                                    font { family: theme.mono; pointSize: 8; bold: true }
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }

                                Text {
                                    visible: (modelData.body || modelData.message || modelData.content || "") !== ""
                                    width: parent.width
                                    text: modelData.body || modelData.message || modelData.content || ""
                                    color: theme.txtMid
                                    font { family: theme.mono; pointSize: 8 }
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }
                            }
                        }

                        Text {
                            visible: messageList.count === 0
                            anchors.centerIn: parent
                            text: backend.messages.length > 0 ? "all caught up" : "no messages"
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
        height: 210
        heading: "DEVICES"

        property string deviceFilter: ""

        ColumnLayout {
            anchors { fill: parent; margins: 12; topMargin: 26 }
            spacing: 4

            // Filter chips
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "FILTER:"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 7 }
                }

                // ALL chip
                Rectangle {
                    height: 20; width: allChipLabel.implicitWidth + 14
                    color: devicesBar.deviceFilter === "" ? theme.hover : "transparent"
                    border.color: devicesBar.deviceFilter === "" ? theme.txtMid : theme.border
                    border.width: 1
                    Text {
                        id: allChipLabel
                        anchors.centerIn: parent
                        text: "ALL"
                        color: devicesBar.deviceFilter === "" ? theme.txtBright : theme.txtMid
                        font { family: theme.mono; pointSize: 7 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: devicesBar.deviceFilter = "" }
                }

                // One chip per unique type-prefix (e.g. transport_drone + transport_hauler → one TRANSPORT chip)
                Repeater {
                    model: {
                        var seen = {}, prefixes = [], d = backend.devices
                        for (var i = 0; i < d.length; i++) {
                            var t = d[i].device_type || ""
                            if (!t) continue
                            var p = t.split("_")[0]
                            if (!seen[p]) { seen[p] = true; prefixes.push(p) }
                        }
                        return prefixes
                    }
                    Rectangle {
                        property string dtype: modelData   // now a prefix, e.g. "transport"
                        height: 20; width: chipLabel.implicitWidth + 14
                        color: devicesBar.deviceFilter === dtype ? theme.hover : "transparent"
                        border.color: devicesBar.deviceFilter === dtype ? theme.txtMid : theme.border
                        border.width: 1
                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: parent.dtype.toUpperCase()
                            color: devicesBar.deviceFilter === parent.dtype ? theme.txtBright : theme.txtMid
                            font { family: theme.mono; pointSize: 7 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: devicesBar.deviceFilter =
                                devicesBar.deviceFilter === parent.dtype ? "" : parent.dtype
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                clip: true

            ListView {
                id: deviceList
                width: parent.width
                height: parent.height
                model: {
                    var f = devicesBar.deviceFilter
                    var pinned = ["heaven_vessel", "replicant_matrix"]
                    var base = f === ""
                        ? backend.devices.slice()
                        : backend.devices.filter(function(d) {
                              return (d.device_type || "").split("_")[0] === f
                          })
                    return base.sort(function(a, b) {
                        var aPin = pinned.indexOf(a.device_type || "") !== -1 ? 1 : 0
                        var bPin = pinned.indexOf(b.device_type || "") !== -1 ? 1 : 0
                        return bPin - aPin
                    })
                }
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

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: (mouse) => {
                            if (!root.hasAutofactory) return
                            deviceContextMenu.targetCode = modelData.device_code || ""
                            deviceContextMenu.targetName = (modelData.device_type || "device")
                                .toUpperCase().replace(/_/g, " ")
                            deviceContextMenu.popup()
                        }
                    }

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

                        // Hub integrity
                        Text {
                            property real integ: {
                                var m = modelData
                                if (m.integrity !== undefined)     return m.integrity
                                if (m.integrity_pct !== undefined) return m.integrity_pct
                                if (m.health !== undefined)        return m.health
                                if (m.health_pct !== undefined)    return m.health_pct
                                return -1
                            }
                            visible: (modelData.device_type || "").indexOf("hub") !== -1
                                     && integ >= 0
                            text: "INTEG  " + Math.round(integ) + "%"
                            color: integ < 30 ? theme.txtRed
                                 : integ < 60 ? theme.txtAmber
                                 : theme.txtMid
                            font { family: theme.mono; pointSize: 8 }
                        }

                        Item { Layout.fillHeight: true }

                        // Vessel / carrier actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: {
                                var t = modelData.device_type || ""
                                return (t.indexOf("vessel") !== -1 ||
                                        t.indexOf("surge") !== -1 ||
                                        t === "mobile_fleet")
                                    && devCard.devStatus !== "stowed"
                            }

                            ActionBtn {
                                label: "[ TRAVEL… ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: {
                                    deviceTravelDialog.deviceCode = modelData.device_code
                                    deviceTravelDialog.open()
                                }
                            }
                            ActionBtn {
                                label: "[ LOAD… ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: vesselLoadDialog.open(modelData.device_code)
                            }
                            ActionBtn {
                                label: "[ UNLOAD ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: backend.vesselUnload(modelData.device_code)
                            }
                        }

                        // Vessel mining cancel
                        ActionBtn {
                            label: "[ STOP MINING ]"
                            Layout.fillWidth: true; height: 22
                            visible: (modelData.device_type || "").indexOf("vessel") !== -1
                                     && devCard.devStatus === "mining"
                            onActivated: backend.stopMining()
                        }

                        // Surge plate taxi/manual config
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: (modelData.device_type || "") === "surge_plate"
                                     && devCard.devStatus !== "stowed"

                            ActionBtn {
                                label: "[ TAXI MODE ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: backend.configureSurgePlate(modelData.device_code, "taxi")
                            }
                            ActionBtn {
                                label: "[ MANUAL MODE ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: backend.configureSurgePlate(modelData.device_code, "manual")
                            }
                        }

                        // AMI Controller actions (compact)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: (modelData.device_type || "").indexOf("controller") !== -1
                                     && devCard.devStatus !== "stowed"

                            ActionBtn {
                                label: "[ LAUNCH ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: backend.amiLaunch(modelData.device_code)
                            }
                            ActionBtn {
                                label: "[ WITHDRAW ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: backend.amiWithdraw(modelData.device_code)
                            }
                            ActionBtn {
                                label: "[ ASSEMBLE ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: backend.amiAssemble(modelData.device_code)
                            }
                        }

                        // FTL Relay actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: (modelData.device_type || "").indexOf("relay") !== -1
                                     && devCard.devStatus !== "stowed"

                            ActionBtn {
                                label: "[ ACTIVATE ]"
                                Layout.fillWidth: true; height: 22
                                enabled: devCard.devStatus !== "active"
                                onActivated: backend.activateRelay(modelData.device_code)
                            }
                            ActionBtn {
                                label: "[ NETWORK ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: {
                                    backend.fetchRelayNetwork(modelData.device_code)
                                    centerPanel.activeTab = "relay"
                                }
                            }
                        }

                        // System Hub actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: (modelData.device_type || "").indexOf("hub") !== -1
                                     && devCard.devStatus !== "stowed"

                            ActionBtn {
                                label: "[ TRAVEL… ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: {
                                    deviceTravelDialog.deviceCode = modelData.device_code
                                    deviceTravelDialog.open()
                                }
                            }
                            ActionBtn {
                                label: "[ ACTIVATE ]"
                                Layout.fillWidth: true; height: 22
                                enabled: devCard.devStatus !== "active"
                                onActivated: backend.activateHub(modelData.device_code)
                            }
                            ActionBtn {
                                label: "[ MSG… ]"
                                Layout.fillWidth: true; height: 22
                                onActivated: {
                                    hubMsgDialog.hubCode = modelData.device_code
                                    hubMsgDialog.open()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            ActionBtn {
                                visible: (modelData.device_type || "").indexOf("vessel") === -1
                                         && (modelData.device_type || "").indexOf("transport") === -1
                                         && (modelData.device_type || "").indexOf("controller") === -1
                                         && (modelData.device_type || "").indexOf("hub") === -1
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
                                label: "[ PATROL ]"
                                Layout.fillWidth: true
                                height: 22
                                visible: (modelData.device_type || "").indexOf("maintenance") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: backend.setPatrol(modelData.device_code)
                            }

                            ActionBtn {
                                label: "[ SEARCH ]"
                                Layout.fillWidth: true
                                height: 22
                                visible: (modelData.device_type || "").indexOf("survey") !== -1
                                         && (modelData.location || "").toUpperCase().indexOf("BELT") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: backend.searchWithDevice(modelData.device_code)
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

                            // Transport drone actions
                            ActionBtn {
                                label: "[ TRAVEL… ]"
                                Layout.fillWidth: true
                                height: 22
                                visible: (modelData.device_type || "").indexOf("transport") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: {
                                    deviceTravelDialog.deviceCode = modelData.device_code
                                    deviceTravelDialog.open()
                                }
                            }
                            ActionBtn {
                                label: "[ COLLECT… ]"
                                Layout.fillWidth: true
                                height: 22
                                visible: (modelData.device_type || "").indexOf("transport") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: collectDialog.open(
                                    modelData.device_code,
                                    (modelData.device_type || "DRONE").toUpperCase().replace(/_/g, " ")
                                    + "  " + (modelData.device_code || "")
                                )
                            }
                            ActionBtn {
                                label: "[ DUMP ]"
                                Layout.fillWidth: true
                                height: 22
                                visible: (modelData.device_type || "").indexOf("transport") !== -1
                                         && devCard.devStatus !== "stowed"
                                onActivated: backend.depositResources(modelData.device_code)
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
            } // ScrollView
        }
    }

    // ── Profile edit dialog ───────────────────────────────────────────── //

    Rectangle {
        id: profileDlg
        property bool editIsNpc: false

        function open() {
            editIsNpc = backend.replicantIsNpc
            profileName.text        = backend.replicantName === "—" ? "" : backend.replicantName
            profilePronouns.text    = backend.replicantPronouns
            profileDescription.text = backend.replicantDescription
            profilePlan.text        = backend.replicantPlan
            profileProject.text     = backend.replicantProject
            profileFlick.contentY   = 0
            visible = true
            profileName.forceActiveFocus()
        }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 440; height: 560
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 8

            Text {
                text: "── EDIT PROFILE ─────────────────"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 9; bold: true }
            }

            Flickable {
                id: profileFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: profileForm.implicitHeight
                flickableDirection: Flickable.VerticalFlick

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: profileForm
                    width: profileFlick.width - 12
                    spacing: 10

                    // ── Name ──
                    Column {
                        width: parent.width
                        spacing: 3
                        Text {
                            text: "NAME"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                        }
                        Rectangle {
                            width: parent.width; height: 28
                            color: "#060c07"; border.color: theme.border; border.width: 1
                            TextInput {
                                id: profileName
                                anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 9 }
                                selectionColor: theme.txtAccent
                                selectByMouse: true
                                Keys.onReturnPressed: profilePronouns.forceActiveFocus()
                            }
                        }
                    }

                    // ── Pronouns ──
                    Column {
                        width: parent.width
                        spacing: 3
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "PRONOUNS"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: profilePronouns.length + "/50"
                                color: profilePronouns.length > 50 ? theme.txtRed : theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: 28
                            color: "#060c07"; border.color: theme.border; border.width: 1
                            TextInput {
                                id: profilePronouns
                                anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 9 }
                                selectionColor: theme.txtAccent
                                selectByMouse: true
                                Keys.onReturnPressed: profileDescription.forceActiveFocus()
                            }
                        }
                    }

                    // ── NPC toggle ──
                    RowLayout {
                        width: parent.width
                        Text {
                            text: "NPC CHARACTER"
                            color: theme.txtDim
                            font { family: theme.mono; pointSize: 7 }
                            Layout.fillWidth: true
                        }
                        ActionBtn {
                            label: profileDlg.editIsNpc ? "[ YES ]" : "[  NO ]"
                            width: 60; height: 22
                            onActivated: profileDlg.editIsNpc = !profileDlg.editIsNpc
                        }
                    }

                    // ── Description ──
                    Column {
                        width: parent.width
                        spacing: 3
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "DESCRIPTION"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: profileDescription.length + "/500"
                                color: profileDescription.length > 500 ? theme.txtRed : theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: 80
                            color: "#060c07"; border.color: theme.border; border.width: 1
                            TextEdit {
                                id: profileDescription
                                anchors { fill: parent; margins: 6 }
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 8 }
                                selectionColor: theme.txtAccent
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                            }
                        }
                    }

                    // ── Plan ──
                    Column {
                        width: parent.width
                        spacing: 3
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "PLAN  (short-term)"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: profilePlan.length + "/500"
                                color: profilePlan.length > 500 ? theme.txtRed : theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: 80
                            color: "#060c07"; border.color: theme.border; border.width: 1
                            TextEdit {
                                id: profilePlan
                                anchors { fill: parent; margins: 6 }
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 8 }
                                selectionColor: theme.txtAccent
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                            }
                        }
                    }

                    // ── Project ──
                    Column {
                        width: parent.width
                        spacing: 3
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "PROJECT  (long-term)"
                                color: theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: profileProject.length + "/2000"
                                color: profileProject.length > 2000 ? theme.txtRed : theme.txtDim
                                font { family: theme.mono; pointSize: 7 }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: 120
                            color: "#060c07"; border.color: theme.border; border.width: 1
                            TextEdit {
                                id: profileProject
                                anchors { fill: parent; margins: 6 }
                                color: theme.txtBright
                                font { family: theme.mono; pointSize: 8 }
                                selectionColor: theme.txtAccent
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ActionBtn {
                    label: "[ SAVE ]"
                    height: 26
                    Layout.fillWidth: true
                    enabled: profileName.text.trim().length > 0
                             && profilePronouns.length <= 50
                             && profileDescription.length <= 500
                             && profilePlan.length <= 500
                             && profileProject.length <= 2000
                    onActivated: {
                        backend.configureReplicant(
                            profileName.text.trim(),
                            profilePronouns.text,
                            profileDescription.text,
                            profilePlan.text,
                            profileProject.text,
                            profileDlg.editIsNpc
                        )
                        profileDlg.close()
                    }
                }
                ActionBtn {
                    label: "[ CANCEL ]"
                    height: 26
                    Layout.fillWidth: true
                    onActivated: profileDlg.close()
                }
            }
        }
    }

    // ── Device context menu ───────────────────────────────────────────── //

    Menu {
        id: deviceContextMenu
        property string targetCode: ""
        property string targetName: ""

        MenuItem {
            text: "Decommission " + deviceContextMenu.targetName + "…"
            onTriggered: {
                decommissionConfirmDlg.deviceCode = deviceContextMenu.targetCode
                decommissionConfirmDlg.deviceName = deviceContextMenu.targetName
                decommissionConfirmDlg.open()
            }
        }
    }

    Rectangle {
        id: decommissionConfirmDlg
        property string deviceCode: ""
        property string deviceName: ""
        function open()  { visible = true }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 380; height: 160
        color: "#0b160c"
        border.color: theme.txtAmber
        border.width: 1
        z: 50
        radius: 2

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 10

            Text {
                text: "DECOMMISSION " + decommissionConfirmDlg.deviceName + "?"
                color: theme.txtAmber
                font { family: theme.mono; pointSize: 10; bold: true }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: "Device will travel to nearest autofactory.\n~60% of materials recovered. Cannot be undone."
                color: theme.txtMid
                font { family: theme.mono; pointSize: 8 }
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ActionBtn {
                    label: "[ CONFIRM ]"
                    height: 26
                    Layout.fillWidth: true
                    onActivated: {
                        backend.decommissionDevice(decommissionConfirmDlg.deviceCode)
                        decommissionConfirmDlg.close()
                    }
                }
                ActionBtn {
                    label: "[ CANCEL ]"
                    height: 26
                    Layout.fillWidth: true
                    onActivated: decommissionConfirmDlg.close()
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

    // Vessel travel dialog
    Rectangle {
        id: deviceTravelDialog
        property string deviceCode: ""
        function open() { dvTravelInput.text = ""; visible = true; dvTravelInput.forceActiveFocus() }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 380; height: 140
        color: "#0b160c"
        border.color: theme.txtMid; border.width: 1
        z: 50; radius: 2

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            Text {
                text: "VESSEL TRAVEL TO"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }
            Rectangle {
                width: parent.width; height: 32
                color: "#060c07"; border.color: theme.border; border.width: 1
                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: "destination (e.g. SOL)"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 10 }
                    visible: dvTravelInput.text === ""
                }
                TextInput {
                    id: dvTravelInput
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.txtBright
                    font { family: theme.mono; pointSize: 10 }
                    Keys.onReturnPressed: {
                        if (text.trim()) backend.travelDevice(deviceTravelDialog.deviceCode, text.trim().toUpperCase())
                        deviceTravelDialog.close()
                    }
                    Keys.onEscapePressed: deviceTravelDialog.close()
                }
            }
            RowLayout {
                width: parent.width; spacing: 8
                ActionBtn {
                    label: "[ CONFIRM ]"; width: 120; height: 28
                    onActivated: {
                        if (dvTravelInput.text.trim())
                            backend.travelDevice(deviceTravelDialog.deviceCode, dvTravelInput.text.trim().toUpperCase())
                        deviceTravelDialog.close()
                    }
                }
                ActionBtn { label: "[ CANCEL ]"; width: 100; height: 28; onActivated: deviceTravelDialog.close() }
            }
        }
    }

    // Vessel load (attach device) dialog
    Rectangle {
        id: vesselLoadDialog
        property string deviceCode: ""
        function open(code) { deviceCode = code; vLoadInput.text = ""; visible = true; vLoadInput.forceActiveFocus() }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 380; height: 140
        color: "#0b160c"
        border.color: theme.txtMid; border.width: 1
        z: 50; radius: 2

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            Text {
                text: "LOAD DEVICE INTO VESSEL"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }
            Rectangle {
                width: parent.width; height: 32
                color: "#060c07"; border.color: theme.border; border.width: 1
                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: "device code to load (e.g. 2AC61214)"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 10 }
                    visible: vLoadInput.text === ""
                }
                TextInput {
                    id: vLoadInput
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.txtBright
                    font { family: theme.mono; pointSize: 10 }
                    Keys.onReturnPressed: {
                        if (text.trim()) backend.vesselLoad(vesselLoadDialog.deviceCode, text.trim().toUpperCase())
                        vesselLoadDialog.close()
                    }
                    Keys.onEscapePressed: vesselLoadDialog.close()
                }
            }
            RowLayout {
                width: parent.width; spacing: 8
                ActionBtn {
                    label: "[ LOAD ]"; width: 120; height: 28
                    onActivated: {
                        if (vLoadInput.text.trim())
                            backend.vesselLoad(vesselLoadDialog.deviceCode, vLoadInput.text.trim().toUpperCase())
                        vesselLoadDialog.close()
                    }
                }
                ActionBtn { label: "[ CANCEL ]"; width: 100; height: 28; onActivated: vesselLoadDialog.close() }
            }
        }
    }

    // Transport drone collect dialog
    Rectangle {
        id: collectDialog
        property string deviceCode: ""
        property string deviceLabel: ""
        function open(code, label) {
            deviceCode = code; deviceLabel = label
            collectQtyInput.text = ""
            visible = true; collectQtyInput.forceActiveFocus()
        }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 300
        height: collectBody.implicitHeight + 32
        color: "#0b160c"
        border.color: theme.txtMid; border.width: 1
        z: 50; radius: 2

        Column {
            id: collectBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8

            Text {
                text: "COLLECT RESOURCES"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }
            Text {
                text: collectDialog.deviceLabel
                color: theme.txtMid
                font { family: theme.mono; pointSize: 8 }
                elide: Text.ElideRight
                width: parent.width
            }
            Text { text: "QUANTITY:"; color: theme.txtDim; font { family: theme.mono; pointSize: 8 } }
            Rectangle {
                width: parent.width; height: 32
                color: "#060c07"; border.color: theme.border; border.width: 1
                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: "amount to collect"
                    color: theme.txtDim
                    font { family: theme.mono; pointSize: 9 }
                    visible: collectQtyInput.text === ""
                }
                TextInput {
                    id: collectQtyInput
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.txtBright
                    font { family: theme.mono; pointSize: 9 }
                    inputMethodHints: Qt.ImhDigitsOnly
                    Keys.onEscapePressed: collectDialog.close()
                }
            }
            Text { text: "RESOURCE TYPE:"; color: theme.txtDim; font { family: theme.mono; pointSize: 8 } }
            Repeater {
                model: ["carbon", "silicates", "structural", "conductive", "rares", "volatiles"]
                ActionBtn {
                    label: "[ " + modelData.toUpperCase() + " ]"
                    width: collectBody.width; height: 26
                    enabled: parseInt(collectQtyInput.text) > 0
                    onActivated: {
                        backend.collectResources(collectDialog.deviceCode, modelData,
                                                 parseInt(collectQtyInput.text))
                        collectDialog.close()
                    }
                }
            }
            ActionBtn {
                label: "[ CANCEL ]"; width: parent.width; height: 26
                onActivated: collectDialog.close()
            }
        }
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

    // System Hub welcome message dialog
    Rectangle {
        id: hubMsgDialog
        property string hubCode: ""
        function open() { hubMsgInput.text = ""; visible = true; hubMsgInput.forceActiveFocus() }
        function close() { visible = false }

        visible: false
        anchors.centerIn: parent
        width: 460; height: 180
        color: "#0b160c"
        border.color: theme.txtMid; border.width: 1
        z: 50; radius: 2

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            Text {
                text: "SET HUB WELCOME MESSAGE"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }

            Text {
                text: "max 500 characters"
                color: theme.txtDim
                font { family: theme.mono; pointSize: 8 }
            }

            Rectangle {
                width: parent.width; height: 54
                color: "#060c07"; border.color: theme.border; border.width: 1

                TextEdit {
                    id: hubMsgInput
                    anchors { fill: parent; margins: 8 }
                    color: theme.txtBright
                    font { family: theme.mono; pointSize: 9 }
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    Keys.onEscapePressed: hubMsgDialog.close()
                }
            }

            RowLayout {
                width: parent.width; spacing: 8
                Text {
                    text: hubMsgInput.text.length + " / 500"
                    color: hubMsgInput.text.length > 480 ? theme.txtAmber : theme.txtDim
                    font { family: theme.mono; pointSize: 8 }
                }
                Item { Layout.fillWidth: true }
                ActionBtn {
                    label: "[ SET ]"; width: 80; height: 28
                    enabled: hubMsgInput.text.trim().length > 0
                             && hubMsgInput.text.length <= 500
                    onActivated: {
                        backend.setHubWelcomeMessage(hubMsgDialog.hubCode, hubMsgInput.text.trim())
                        hubMsgDialog.close()
                    }
                }
                ActionBtn {
                    label: "[ CANCEL ]"; width: 90; height: 28
                    onActivated: hubMsgDialog.close()
                }
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

    // AMI — adopt a device into a controller's fleet
    InputDialog {
        id: amiAdoptDlg
        property string controllerCode: ""
        heading: "ADOPT DEVICE INTO FLEET"
        placeholder: "device code (e.g. 2AC61214)"
        onConfirmed: (val) => {
            if (val.trim()) backend.amiAdopt(controllerCode, val.trim().toUpperCase())
        }
    }

    // AMI — release a device from a controller's fleet
    InputDialog {
        id: amiReleaseDlg
        property string controllerCode: ""
        heading: "RELEASE DEVICE FROM FLEET"
        placeholder: "device code (e.g. 2AC61214)"
        onConfirmed: (val) => {
            if (val.trim()) backend.amiRelease(controllerCode, val.trim().toUpperCase())
        }
    }

    // AMI — survey system directive config
    Rectangle {
        id: amiSurveyDlg
        property string controllerCode: ""
        property string moonsMode: "all"
        property bool recallEnabled: true

        visible: false
        anchors.centerIn: parent
        width: 320
        height: amiSurveyBody.implicitHeight + 32
        color: "#0b160c"
        border.color: theme.txtMid
        border.width: 1
        z: 50
        radius: 2

        Column {
            id: amiSurveyBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 10

            Text {
                text: "SURVEY SYSTEM DIRECTIVE"
                color: theme.txtAccent
                font { family: theme.mono; pointSize: 10; bold: true }
            }

            Text { text: "MOONS:"; color: theme.txtDim; font { family: theme.mono; pointSize: 8 } }
            RowLayout {
                width: parent.width
                spacing: 4
                ActionBtn {
                    label: amiSurveyDlg.moonsMode === "all" ? "[ ALL ]" : "  ALL  "
                    Layout.fillWidth: true; height: 26
                    onActivated: amiSurveyDlg.moonsMode = "all"
                }
                ActionBtn {
                    label: amiSurveyDlg.moonsMode === "none" ? "[ NONE ]" : "  NONE  "
                    Layout.fillWidth: true; height: 26
                    onActivated: amiSurveyDlg.moonsMode = "none"
                }
            }

            Text { text: "RECALL WHEN DONE:"; color: theme.txtDim; font { family: theme.mono; pointSize: 8 } }
            RowLayout {
                width: parent.width
                spacing: 4
                ActionBtn {
                    label: amiSurveyDlg.recallEnabled ? "[ YES ]" : "  YES  "
                    Layout.fillWidth: true; height: 26
                    onActivated: amiSurveyDlg.recallEnabled = true
                }
                ActionBtn {
                    label: !amiSurveyDlg.recallEnabled ? "[ NO ]" : "  NO  "
                    Layout.fillWidth: true; height: 26
                    onActivated: amiSurveyDlg.recallEnabled = false
                }
            }

            RowLayout {
                width: parent.width
                spacing: 6
                ActionBtn {
                    label: "[ SET DIRECTIVE ]"
                    Layout.fillWidth: true; height: 28
                    onActivated: {
                        backend.amiSurveySystem(amiSurveyDlg.controllerCode,
                                                amiSurveyDlg.moonsMode,
                                                amiSurveyDlg.recallEnabled)
                        amiSurveyDlg.visible = false
                    }
                }
                ActionBtn {
                    label: "[ CANCEL ]"
                    width: 90; height: 28
                    onActivated: amiSurveyDlg.visible = false
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
