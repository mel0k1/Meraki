import QtQuick
import "../glass"

// Control Center (порт ccStyle "tiles" из MacBar): стеклянная панель
// справа под лентой. Тайлы Wi-Fi/Bluetooth/ночной свет открывают страницы
// Параметров, «Не беспокоить» — настоящий тумблер, ниже громкость,
// медиа и батарея.
Rectangle {
    id: root

    readonly property bool shown: bridge.open
    readonly property var st: bridge.status
    readonly property bool netUp: st.net !== undefined && st.net.up
    readonly property bool wireless: netUp && st.net.wireless
    readonly property bool hasVol: st.volume !== undefined
    readonly property int vol: hasVol ? st.volume : 0
    readonly property bool muted: hasVol && st.muted
    readonly property bool hasBat: st.battery !== undefined
    readonly property int batCap: hasBat ? st.battery.capacity : 0
    readonly property bool charging: hasBat && st.battery.charging
    readonly property bool hasMedia: typeof media !== "undefined"
        && media !== null && media.hasSession

    // Тайл Control Center: иконка-круг, заголовок и подпись.
    component CCTile: Item {
        id: tile

        property string iconKind: ""
        property string title: ""
        property string sub: ""
        signal activate()

        height: 64

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: tMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16)
                                     : Qt.rgba(1, 1, 1, 0.10)
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Rectangle {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 13
            color: Qt.rgba(1, 1, 1, 0.16)

            Canvas {
                anchors.centerIn: parent
                width: 16
                height: 16
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "rgba(255,255,255,0.92)"
                    ctx.fillStyle = ctx.strokeStyle
                    ctx.lineWidth = 1.5
                    ctx.lineCap = "round"
                    if (tile.iconKind === "wifi") {
                        for (var i = 0; i < 2; i++) {
                            ctx.beginPath()
                            ctx.arc(8, 12, 3.2 + i * 3.4,
                                Math.PI * 1.25, Math.PI * 1.75)
                            ctx.stroke()
                        }
                        ctx.beginPath()
                        ctx.arc(8, 11, 1.4, 0, 2 * Math.PI)
                        ctx.fill()
                    } else if (tile.iconKind === "bt") {
                        ctx.beginPath()
                        ctx.moveTo(8, 1.5)
                        ctx.lineTo(8, 14.5)
                        ctx.moveTo(4.5, 4.5)
                        ctx.lineTo(11.5, 11.5)
                        ctx.lineTo(8, 14.5)
                        ctx.moveTo(4.5, 11.5)
                        ctx.lineTo(11.5, 4.5)
                        ctx.lineTo(8, 1.5)
                        ctx.stroke()
                    } else {
                        // Ночной свет: диск-луна с вырезом-перекрытием.
                        ctx.beginPath()
                        ctx.arc(8, 8, 5.6, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                }
            }

            Canvas {
                visible: tile.iconKind === "night"
                anchors.centerIn: parent
                width: 16
                height: 16
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "rgba(70,70,74,1.0)"
                    ctx.beginPath()
                    ctx.arc(10.6, 6, 5.4, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: tile.title
                color: "#F2FFFFFF"
                font.family: "SF Pro Display"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.sub
                color: "#99FFFFFF"
                font.family: "SF Pro Display"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.activate()
        }
    }

    color: shown ? Qt.rgba(0, 0, 0, 0.12) : "transparent"

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: bridge.close()
    }

    Item {
        id: backdrop
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: bridge.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Repeater {
            model: bridge.windows
            Rectangle {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: Math.max(2, modelData.w)
                height: Math.max(2, modelData.h)
                radius: 4
                color: modelData.focused ? Qt.rgba(0.72, 0.78, 0.88, 0.30)
                                         : Qt.rgba(0.60, 0.65, 0.75, 0.18)
            }
        }
    }

    DockGlassPanel {
        id: panel

        property real appear: root.shown ? 1 : 0

        x: parent.width - width - 10
        y: 32
        width: 356
        height: ccCol.height + 28
        cornerRadius: 20
        backdrop: backdrop
        opacity: appear
        scale: 0.94 + 0.06 * appear

        Behavior on appear {
            NumberAnimation { duration: 170 }
        }

        Component.onCompleted: {
            bridge.panelX = panel.x
            bridge.panelY = panel.y
            bridge.panelW = panel.width
            bridge.panelH = panel.height
        }

        onXChanged: bridge.panelX = panel.x
        onYChanged: bridge.panelY = panel.y
        onHeightChanged: bridge.panelH = panel.height

        Column {
            id: ccCol

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10

            Row {
                width: parent.width
                spacing: 10

                // Wi-Fi
                CCTile {
                    width: (parent.width - 10) / 2
                    iconKind: "wifi"
                    title: root.netUp
                        ? (root.wireless && root.st.net.essid
                            ? root.st.net.essid : "Wi-Fi")
                        : "Wi-Fi"
                    sub: root.netUp ? "Подключено" : "Выключено"
                    onActivate: bridge.openSettings("network")
                }

                // Bluetooth
                CCTile {
                    width: (parent.width - 10) / 2
                    iconKind: "bt"
                    title: "Bluetooth"
                    sub: "Открыть настройки"
                    onActivate: bridge.openSettings("bluetooth")
                }
            }

            Row {
                width: parent.width
                spacing: 10

                // Не беспокоить — настоящий тумблер (центр уведомлений).
                Item {
                    width: (parent.width - 10) / 2
                    height: 64

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: bridge.dnd ? "#5E5CE6"
                            : (dndMa.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.16)
                                : Qt.rgba(1, 1, 1, 0.10))
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Canvas {
                        id: moonCv

                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        antialiasing: true
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = "rgba(255,255,255,0.95)"
                            ctx.beginPath()
                            ctx.arc(9, 9, 7, 0, 2 * Math.PI)
                            ctx.fill()
                            // Вырез «месяца» цветом тайла.
                            ctx.fillStyle = bridge.dnd ? "#5E5CE6"
                                : "rgba(28,28,30,0.55)"
                            ctx.beginPath()
                            ctx.arc(13, 6.4, 5.6, 0, 2 * Math.PI)
                            ctx.fill()
                        }
                    }

                    Column {
                        anchors.left: moonCv.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Не беспокоить"
                            color: "#F2FFFFFF"
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Text {
                            text: bridge.dnd ? "Включено" : "Выключено"
                            color: "#99FFFFFF"
                            font.family: "SF Pro Display"
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: dndMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bridge.toggleDnd()
                    }
                }

                // Ночной свет
                CCTile {
                    width: (parent.width - 10) / 2
                    iconKind: "night"
                    title: "Ночной свет"
                    sub: "Открыть настройки"
                    onActivate: bridge.openSettings("nightlight")
                }
            }

            Connections {
                target: bridge
                function onStatusChanged() {
                    volIco.requestPaint()
                    batIco.requestPaint()
                }
                function onDndChanged() {
                    moonCv.requestPaint()
                }
            }

            // Громкость: дорожка с заполнением, клик и перетаскивание.
            Item {
                width: parent.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.10)
                }

                Canvas {
                    id: volIco

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 13
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = "rgba(255,255,255,0.92)"
                        ctx.beginPath()
                        ctx.moveTo(1.5, 4.5)
                        ctx.lineTo(4.4, 4.5)
                        ctx.lineTo(7.2, 1.5)
                        ctx.lineTo(7.2, 11.5)
                        ctx.lineTo(4.4, 8.5)
                        ctx.lineTo(1.5, 8.5)
                        ctx.closePath()
                        ctx.fill()
                        if (root.muted) {
                            ctx.strokeStyle = ctx.fillStyle
                            ctx.lineWidth = 1.4
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(9.2, 4)
                            ctx.lineTo(13.4, 9)
                            ctx.moveTo(13.4, 4)
                            ctx.lineTo(9.2, 9)
                            ctx.stroke()
                            return
                        }
                        ctx.strokeStyle = ctx.fillStyle
                        ctx.lineWidth = 1.3
                        ctx.lineCap = "round"
                        if (root.vol > 8) {
                            ctx.beginPath()
                            ctx.arc(7.2, 6.5, 2.8, -Math.PI * 0.42,
                                Math.PI * 0.42)
                            ctx.stroke()
                        }
                        if (root.vol > 55) {
                            ctx.beginPath()
                            ctx.arc(7.2, 6.5, 4.8, -Math.PI * 0.4,
                                Math.PI * 0.4)
                            ctx.stroke()
                        }
                    }
                }

                Rectangle {
                    x: 38
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.18)

                    Rectangle {
                        width: parent.width
                            * (root.muted ? 0 : root.vol / 100.0)
                        height: parent.height
                        radius: 3
                        color: "#F2FFFFFF"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.hasVol
                    onClicked: function(mouse) {
                        bridge.setVolume(Math.round(
                            Math.max(0, Math.min(1,
                                (mouse.x - 38) / (parent.width - 50)))
                            * 100))
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed) {
                            return
                        }
                        bridge.setVolume(Math.round(
                            Math.max(0, Math.min(1,
                                (mouse.x - 38) / (parent.width - 50)))
                            * 100))
                    }
                    onWheel: function(w) {
                        bridge.setVolume(root.vol
                            + (w.angleDelta.y > 0 ? 5 : -5))
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasVol
                    text: root.muted ? "— " : root.vol + "%"
                    color: "#CCFFFFFF"
                    font.family: "SF Pro Display"
                    font.pixelSize: 10
                }
            }

            // Медиа: трек и кнопки из SMTC-сессии.
            Item {
                width: parent.width
                height: 52
                visible: root.hasMedia

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.10)
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: btns.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.hasMedia && media.title ? media.title : ""
                        color: "#F2FFFFFF"
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.hasMedia && media.artist ? media.artist : ""
                        color: "#99FFFFFF"
                        font.family: "SF Pro Display"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: btns

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: [
                            { glyph: "prev", act: "previous" },
                            { glyph: root.hasMedia && media.playing
                                ? "pause" : "play", act: "togglePlay" },
                            { glyph: "next", act: "next" }
                        ]

                        delegate: Item {
                            width: 26
                            height: 26

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: mMa.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.18)
                                    : "transparent"
                            }

                            Canvas {
                                anchors.centerIn: parent
                                width: 14
                                height: 12
                                antialiasing: true
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.fillStyle = "rgba(255,255,255,0.92)"
                                    var g = modelData.glyph
                                    if (g === "play") {
                                        ctx.beginPath()
                                        ctx.moveTo(3, 1)
                                        ctx.lineTo(12, 6)
                                        ctx.lineTo(3, 11)
                                        ctx.closePath()
                                        ctx.fill()
                                    } else if (g === "pause") {
                                        ctx.fillRect(2.5, 1, 3, 10)
                                        ctx.fillRect(8.5, 1, 3, 10)
                                    } else if (g === "next") {
                                        ctx.beginPath()
                                        ctx.moveTo(1, 1)
                                        ctx.lineTo(6.5, 6)
                                        ctx.lineTo(1, 11)
                                        ctx.closePath()
                                        ctx.fill()
                                        ctx.beginPath()
                                        ctx.moveTo(6.5, 1)
                                        ctx.lineTo(12, 6)
                                        ctx.lineTo(6.5, 11)
                                        ctx.closePath()
                                        ctx.fill()
                                    } else {
                                        ctx.beginPath()
                                        ctx.moveTo(13, 1)
                                        ctx.lineTo(7.5, 6)
                                        ctx.lineTo(13, 11)
                                        ctx.closePath()
                                        ctx.fill()
                                        ctx.beginPath()
                                        ctx.moveTo(7.5, 1)
                                        ctx.lineTo(2, 6)
                                        ctx.lineTo(7.5, 11)
                                        ctx.closePath()
                                        ctx.fill()
                                    }
                                }
                            }

                            MouseArea {
                                id: mMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.hasMedia) {
                                        media[modelData.act]()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Батарея.
            Item {
                width: parent.width
                height: 34
                visible: root.hasBat

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.10)
                }

                Canvas {
                    id: batIco

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 13
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = "rgba(255,255,255,0.8)"
                        ctx.lineWidth = 1.3
                        ctx.beginPath()
                        ctx.roundedRect(0.7, 1.2, 18, 10, 2.4, 2.4)
                        ctx.stroke()
                        ctx.fillStyle = "rgba(255,255,255,0.8)"
                        ctx.fillRect(19.4, 4.2, 1.7, 4)
                        var cap = Math.max(0, Math.min(100, root.batCap))
                        ctx.fillStyle = cap <= 15 ? "#FF453A" : "#30D158"
                        ctx.fillRect(2.6, 3, (cap / 100.0) * 14.2, 6.4)
                        if (root.charging) {
                            ctx.fillStyle = "rgba(255,255,255,0.95)"
                            ctx.beginPath()
                            ctx.moveTo(10, 0.6)
                            ctx.lineTo(6.6, 6)
                            ctx.lineTo(9, 6)
                            ctx.lineTo(8, 12.2)
                            ctx.lineTo(11.8, 5.2)
                            ctx.lineTo(9.4, 5.2)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.charging
                        ? "Зарядка · " + root.batCap + "%"
                        : "Батарея · " + root.batCap + "%"
                    color: "#F2FFFFFF"
                    font.family: "SF Pro Display"
                    font.pixelSize: 12
                }
            }
        }
    }
}
